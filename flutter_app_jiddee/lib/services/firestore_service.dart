import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_user.dart';
import '../models/phq9_result.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // =========================
  // USER
  // =========================

  Stream<AppUser> watchUser(String uid) {
    return _db.collection('users').doc(uid).snapshots().map((doc) {
      return AppUser.fromMap(doc.id, doc.data() ?? {});
    });
  }

  /// สำหรับ Dashboard/รายชื่อผู้ป่วย (Admin)
  Stream<List<AppUser>> watchPatientsForDashboard() {
    return _db
        .collection('users')
        .where('role', isEqualTo: 'patient')
        .snapshots()
        .map((qs) {
      return qs.docs.map((d) => AppUser.fromMap(d.id, d.data())).toList();
    });
  }

  Future<void> ensureUserDoc({
    required String uid,
    required String name,
    String role = 'patient',
  }) async {
    final ref = _db.collection('users').doc(uid);
    final snap = await ref.get();
    if (snap.exists) return;

    await ref.set({
      'name': name,
      'role': role,
      'consentCamera': false,

      // PHQ-9
      'hasCompletedPhq9': false,
      'phq9RiskLevel': null,

      // Deep Assessment
      'hasCompletedDeepAssessment': false,
      'deepRiskLevel': null,
      'deepScore': null,

      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateUserProfile({
    required String uid,
    required String name,
    String? phone,
    String? age,
    String? gender,
  }) async {
    await _db.collection('users').doc(uid).set({
      'name': name.trim(),
      'phone': phone?.trim(),
      'age': age?.trim(),
      'gender': gender?.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // =========================
  // PHQ-9
  // =========================

  Future<void> savePhq9Result(Phq9Result r) async {
    await _db.collection('phq9_results').add(r.toMap());
  }

  Future<void> updatePhq9Status({
    required String uid,
    required String riskLevel, // green/yellow/red
  }) async {
    await _db.collection('users').doc(uid).set({
      'hasCompletedPhq9': true,
      'phq9RiskLevel': riskLevel,

      // PHQ ใหม่ -> deep reset
      'hasCompletedDeepAssessment': false,
      'deepRiskLevel': null,
      'deepScore': null,

      'lastPhq9At': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // =========================
  // Deep Assessment (TMHI-55) RESULT
  // =========================

  Future<void> updateDeepAssessmentStatus({
    required String uid,
    required String deepRiskLevel, // green/yellow/red
    required int deepScore, // 0..220
  }) async {
    await _db.collection('users').doc(uid).set({
      'hasCompletedDeepAssessment': true,
      'deepRiskLevel': deepRiskLevel,
      'deepScore': deepScore,
      'lastDeepAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // =========================
  // Deep Assessment DRAFT (ทำค้างไว้แล้วกลับมาทำต่อ)
  // path: users/{uid}/deep_draft/current
  // =========================

  Stream<Map<String, dynamic>?> watchDeepDraft(String uid) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('deep_draft')
        .doc('current')
        .snapshots()
        .map((doc) => doc.exists ? (doc.data() ?? {}) : null);
  }

  /// บันทึก draft แบบ safe (ไม่ทับ startedAt ถ้ามีอยู่แล้ว)
  Future<void> saveDeepDraft({
    required String uid,
    required List<int> answers, // แนะนำ length 55 (0..4)
    required int currentIndex, // 0..54
  }) async {
    final ref = _db
        .collection('users')
        .doc(uid)
        .collection('deep_draft')
        .doc('current');

    final snap = await ref.get();

    final data = <String, dynamic>{
      'answers': answers,
      'currentIndex': currentIndex,
      'version': 1,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (!snap.exists) {
      data['startedAt'] = FieldValue.serverTimestamp();
    }

    await ref.set(data, SetOptions(merge: true));
  }

  Future<void> clearDeepDraft(String uid) async {
    final ref = _db
        .collection('users')
        .doc(uid)
        .collection('deep_draft')
        .doc('current');
    await ref.delete();
  }

  // =========================
  // APPOINTMENT (collection: appointments)
  // =========================

  Future<void> createAppointment({
    required AppUser user,
    required DateTime appointmentAt,
    String? note,
  }) async {
    final deep = (user.deepRiskLevel ?? '').toLowerCase();

    if (!(user.hasCompletedDeepAssessment && deep == 'red')) {
      throw Exception(
        'FORBIDDEN: Appointment allowed only when Deep Assessment = red',
      );
    }

    final now = Timestamp.now();

    await _db.collection('appointments').add({
      'patientUid': user.uid,
      'patientName': user.name,
      'appointmentAt': Timestamp.fromDate(appointmentAt),
      'note': note,
      'status': 'pending',

      // ใช้ createdAt (client) + createdAtServer (server) เผื่อออฟไลน์
      'createdAt': now,
      'updatedAt': now,
      'createdAtServer': FieldValue.serverTimestamp(),
      'updatedAtServer': FieldValue.serverTimestamp(),

      // หมายเหตุจากแอดมิน/แพทย์
      'adminNote': null,
    });
  }

  /// ✅ แสดงสถานะนัดหมายล่าสุดแบบ realtime (ไม่ต้องสร้าง Composite Index)
  /// แก้โดย: query แค่ where(patientUid) แล้ว sort ฝั่ง client
  Stream<Map<String, dynamic>?> watchLatestAppointment(String patientUid) {
    return _db
        .collection('appointments')
        .where('patientUid', isEqualTo: patientUid)
        .snapshots()
        .map((qs) {
      if (qs.docs.isEmpty) return null;

      final items = qs.docs.map((d) => {'id': d.id, ...d.data()}).toList();

      items.sort((a, b) {
        final ad = _apptSortDate(a);
        final bd = _apptSortDate(b);
        return bd.compareTo(ad); // ล่าสุดก่อน
      });

      return items.first;
    });
  }

  /// ✅ active = pending / approved / confirmed (realtime)
  /// ทำแบบไม่ใช้ whereIn เพื่อเลี่ยง index
  Stream<Map<String, dynamic>?> watchActiveAppointment(String patientUid) {
    return _db
        .collection('appointments')
        .where('patientUid', isEqualTo: patientUid)
        .snapshots()
        .map((qs) {
      if (qs.docs.isEmpty) return null;

      final items = qs.docs.map((d) => {'id': d.id, ...d.data()}).toList();

      final active = items.where((m) {
        final s = (m['status'] ?? '').toString().toLowerCase();
        return s == 'pending' || s == 'approved' || s == 'confirmed';
      }).toList();

      if (active.isEmpty) return null;

      active.sort((a, b) {
        final ad = _apptSortDate(a);
        final bd = _apptSortDate(b);
        return bd.compareTo(ad);
      });

      return active.first;
    });
  }

  /// Admin: ฟิลเตอร์นัดหมายตามสถานะ (ไม่ใช้ orderBy เพื่อลดปัญหา index)
  /// status: pending | approved | rejected | canceled | completed | all
  Stream<List<Map<String, dynamic>>> watchAppointmentsByStatus({
    required String status,
  }) {
    Query<Map<String, dynamic>> q = _db.collection('appointments');

    final s = status.toLowerCase();
    if (s != 'all') {
      q = q.where('status', isEqualTo: s);
    }

    return q.snapshots().map((qs) {
      final list = qs.docs.map((d) => {'id': d.id, ...d.data()}).toList();

      list.sort((a, b) {
        final ad = _apptSortDate(a);
        final bd = _apptSortDate(b);
        return bd.compareTo(ad);
      });

      return list;
    });
  }

  Stream<List<Map<String, dynamic>>> watchPendingAppointments() {
    return watchAppointmentsByStatus(status: 'pending');
  }

  /// Admin: อัปเดตสถานะนัดหมาย (+ ใส่หมายเหตุได้)
  /// - appendNote=true: ต่อข้อความ adminNote เดิม
  Future<void> updateAppointmentStatus({
    required String appointmentId,
    required String status,
    String? adminNote,
    bool appendNote = false,
  }) async {
    final ref = _db.collection('appointments').doc(appointmentId);

    String? noteToSave = adminNote?.trim();
    if (noteToSave != null && noteToSave.isEmpty) noteToSave = null;

    if (appendNote && noteToSave != null) {
      final snap = await ref.get();
      final old = (snap.data()?['adminNote'] ?? '').toString().trim();
      if (old.isNotEmpty) {
        noteToSave = '$old\n• $noteToSave';
      }
    }

    await ref.set({
      'status': status.toLowerCase(),
      if (noteToSave != null) 'adminNote': noteToSave,
      'updatedAtServer': FieldValue.serverTimestamp(),
      'updatedAt': Timestamp.now(),
    }, SetOptions(merge: true));
  }

  // =========================
  // Helpers
  // =========================

  /// เลือก “วันที่ใช้จัดเรียง” ของนัดหมาย
  /// priority: appointmentAt > createdAtServer > createdAt > updatedAtServer > updatedAt > epoch
  DateTime _apptSortDate(Map<String, dynamic> a) {
    DateTime? dt;

    final apptAt = a['appointmentAt'];
    if (apptAt is Timestamp) dt = apptAt.toDate();
    if (apptAt is DateTime) dt = apptAt;

    final createdAtServer = a['createdAtServer'];
    if (dt == null && createdAtServer is Timestamp) dt = createdAtServer.toDate();

    final createdAt = a['createdAt'];
    if (dt == null && createdAt is Timestamp) dt = createdAt.toDate();

    final updatedAtServer = a['updatedAtServer'];
    if (dt == null && updatedAtServer is Timestamp) dt = updatedAtServer.toDate();

    final updatedAt = a['updatedAt'];
    if (dt == null && updatedAt is Timestamp) dt = updatedAt.toDate();

    return dt ?? DateTime.fromMillisecondsSinceEpoch(0);
  }
}
