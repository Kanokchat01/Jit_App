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
      'phone': (phone != null && phone.trim().isNotEmpty) ? phone.trim() : null,
      'age': (age != null && age.trim().isNotEmpty) ? age.trim() : null,
      'gender': (gender != null && gender.trim().isNotEmpty) ? gender.trim() : null,
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
  // Deep Assessment (TMHI-55)
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
  // APPOINTMENT
  // =========================
  // status: pending | approved | confirmed | rejected | canceled | completed

  Future<void> createAppointment({
    required AppUser user,
    required DateTime appointmentAt,
    String? note,
    String? doctorUid,
  }) async {
    // นัดได้เฉพาะ deep = red และทำ deep แล้ว
    final deepIsRed = user.hasCompletedDeepAssessment &&
        (user.deepRiskLevel ?? '').toLowerCase() == 'red';

    if (!deepIsRed) {
      throw Exception('FORBIDDEN: Appointment allowed only when Deep Assessment = red');
    }

    final now = Timestamp.now();

    await _db.collection('appointments').add({
      'patientUid': user.uid,
      'patientName': user.name,
      'doctorUid': doctorUid,

      'appointmentAt': Timestamp.fromDate(appointmentAt),
      'note': (note != null && note.trim().isNotEmpty) ? note.trim() : null,

      'status': 'pending',

      // ✅ เก็บเวลาแบบ client (ใช้คัด latest ฝั่ง app ได้)
      'createdAt': now,
      'updatedAt': now,

      // ✅ เผื่อใช้ในอนาคต (ไม่พึ่ง index ตอนนี้)
      'createdAtServer': FieldValue.serverTimestamp(),
      'updatedAtServer': FieldValue.serverTimestamp(),
    });
  }

  /// ✅ IMPORTANT: เลิกใช้ orderBy เพื่อไม่ต้องสร้าง composite index
  /// เราดึงทั้งหมดของ patientUid แล้วหา "ล่าสุด" ในแอปเอง
  Stream<Map<String, dynamic>?> watchLatestAppointment(String patientUid) {
    return _db
        .collection('appointments')
        .where('patientUid', isEqualTo: patientUid)
        .snapshots()
        .map((qs) {
      if (qs.docs.isEmpty) return null;

      Map<String, dynamic>? best;
      Timestamp? bestCreated;

      for (final d in qs.docs) {
        final data = d.data();
        final created = data['createdAt'];
        Timestamp? createdTs;

        if (created is Timestamp) createdTs = created;
        // fallback: ถ้าไม่มี createdAt ให้ใช้ appointmentAt
        if (createdTs == null && data['appointmentAt'] is Timestamp) {
          createdTs = data['appointmentAt'] as Timestamp;
        }

        if (best == null) {
          best = {'id': d.id, ...data};
          bestCreated = createdTs;
          continue;
        }

        // เปรียบเทียบเวลา (ถ้า null ให้ถือว่าเก่ากว่า)
        final a = bestCreated?.millisecondsSinceEpoch ?? -1;
        final b = createdTs?.millisecondsSinceEpoch ?? -1;

        if (b > a) {
          best = {'id': d.id, ...data};
          bestCreated = createdTs;
        }
      }

      return best;
    });
  }

  /// ✅ active = pending / approved / confirmed
  Stream<Map<String, dynamic>?> watchActiveAppointment(String patientUid) {
    return watchLatestAppointment(patientUid).map((latest) {
      if (latest == null) return null;
      final status = (latest['status'] ?? '').toString();
      final isActive = status == 'pending' || status == 'approved' || status == 'confirmed';
      return isActive ? latest : null;
    });
  }

  Future<void> updateAppointmentStatus({
    required String appointmentId,
    required String status,
    String? adminNote,
  }) async {
    final now = Timestamp.now();
    await _db.collection('appointments').doc(appointmentId).set({
      'status': status,
      'adminNote': adminNote,
      'updatedAt': now,
      'updatedAtServer': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // =========================
  // DASHBOARD (ADMIN)
  // =========================
  Stream<List<AppUser>> watchPatientsForDashboard() {
    return _db.collection('users').snapshots().map((qs) {
      final users = qs.docs.map((d) => AppUser.fromMap(d.id, d.data())).toList();
      final patients = users.where((u) => u.role == UserRole.patient).toList();

      int rank(String? r) {
        switch ((r ?? '').toLowerCase()) {
          case 'red':
            return 0;
          case 'yellow':
            return 1;
          case 'green':
            return 2;
          default:
            return 3;
        }
      }

      patients.sort((a, b) => rank(a.phq9RiskLevel).compareTo(rank(b.phq9RiskLevel)));
      return patients;
    });
  }
}
