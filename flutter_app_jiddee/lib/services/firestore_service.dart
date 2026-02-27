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

      'hasCompletedPhq9': false,
      'phq9RiskLevel': null,

      'hasCompletedDeepAssessment': false,
      'deepRiskLevel': null,
      'deepScore': null,

      // ✅ เพิ่มช่องเก็บ emotion ล่าสุดของ deep
      'deepEmotion': null,

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
    String? birthDate,
    String? faculty,
    String? major,
    String? studentId,
    String? year,
  }) async {
    await _db.collection('users').doc(uid).set({
      'name': name.trim(),
      'phone': phone?.trim(),
      'age': age?.trim(),
      'gender': gender,
      'birthDate': birthDate?.trim(),
      'faculty': faculty?.trim(),
      'major': major?.trim(),
      'studentId': studentId?.trim(),
      'year': year?.trim(),
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
    required String riskLevel,
  }) async {
    await _db.collection('users').doc(uid).set({
      'hasCompletedPhq9': true,
      'phq9RiskLevel': riskLevel,

      // PHQ ใหม่ -> deep reset
      'hasCompletedDeepAssessment': false,
      'deepRiskLevel': null,
      'deepScore': null,
      'deepEmotion': null,

      'lastPhq9At': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // =========================
  // Deep Assessment (TMHI-55) RESULT
  // =========================

  /// ✅ เพิ่ม emotion optional:
  /// emotionSummaryPercent: {angry:12.0, fear:3.0, ...}
  Future<void> updateDeepAssessmentStatus({
    required String uid,
    required String deepRiskLevel,
    required int deepScore,

    // ✅ emotion (optional)
    int? emotionSamples,
    double? emotionAvgConf,
    String? dominantEmotion,
    double? dominantScore,
    Map<String, double>? emotionSummaryPercent,
  }) async {
    final data = <String, dynamic>{
      'hasCompletedDeepAssessment': true,
      'deepRiskLevel': deepRiskLevel,
      'deepScore': deepScore,
      'lastDeepAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    // แนบ emotion ถ้ามี
    final hasEmotion = (emotionSamples != null ||
        emotionAvgConf != null ||
        dominantEmotion != null ||
        dominantScore != null ||
        emotionSummaryPercent != null);

    if (hasEmotion) {
      data['deepEmotion'] = {
        'samples': emotionSamples ?? 0,
        'avgConf': emotionAvgConf ?? 0.0,
        'dominant': (dominantEmotion ?? '').toString(),
        'dominantScore': dominantScore ?? 0.0,
        'summaryPercent': emotionSummaryPercent ?? <String, double>{},
        'capturedAt': FieldValue.serverTimestamp(),
      };
    }

    await _db.collection('users').doc(uid).set(data, SetOptions(merge: true));
  }

  // =========================
  // Deep Draft
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

  Future<void> saveDeepDraft({
    required String uid,
    required List<int> answers,
    required int currentIndex,
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
  // APPOINTMENT
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

    final docRef = await _db.collection('appointments').add({
      'patientUid': user.uid,
      'patientName': user.name,
      'appointmentAt': Timestamp.fromDate(appointmentAt),
      'note': note,
      'status': 'pending',
      'createdAt': now,
      'updatedAt': now,
      'createdAtServer': FieldValue.serverTimestamp(),
      'updatedAtServer': FieldValue.serverTimestamp(),
      'adminNote': null,
    });

    final formattedDate =
        "${appointmentAt.day}/${appointmentAt.month}/${appointmentAt.year} "
        "${appointmentAt.hour.toString().padLeft(2, '0')}:"
        "${appointmentAt.minute.toString().padLeft(2, '0')}";

    await _db.collection('admin_notifications').add({
      'title': 'มีคำขอนัดหมายใหม่',
      'body': 'คุณ ${user.name} ส่งคำขอนัดวันที่ $formattedDate',
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
      'type': 'appointment',
      'appointmentId': docRef.id,
      'patientUid': user.uid,
    });
  }

  Stream<Map<String, dynamic>?> watchLatestAppointment(String patientUid) {
    return _db
        .collection('appointments')
        .where('patientUid', isEqualTo: patientUid)
        .snapshots()
        .map((qs) {
      if (qs.docs.isEmpty) return null;

      final items = qs.docs.map((d) => {'id': d.id, ...d.data()}).toList();
      items.sort((a, b) => _apptSortDate(b).compareTo(_apptSortDate(a)));
      return items.first;
    });
  }

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
      active.sort((a, b) => _apptSortDate(b).compareTo(_apptSortDate(a)));
      return active.first;
    });
  }

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
      list.sort((a, b) => _apptSortDate(b).compareTo(_apptSortDate(a)));
      return list;
    });
  }

  Stream<List<Map<String, dynamic>>> watchPendingAppointments() {
    return watchAppointmentsByStatus(status: 'pending');
  }

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