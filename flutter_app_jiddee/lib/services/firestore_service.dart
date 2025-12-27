import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_user.dart';
import '../models/phq9_result.dart';

class FirestoreService {
  final _db = FirebaseFirestore.instance;

  // =========================
  // USER
  // =========================

  Stream<AppUser> watchUser(String uid) {
    return _db.collection('users').doc(uid).snapshots().map((doc) {
      return AppUser.fromMap(doc.id, doc.data() ?? {});
    });
  }

  /// สร้าง user doc เฉพาะครั้งแรก
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

      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // =========================
  // PHQ-9
  // =========================

  /// เก็บผล PHQ-9 (history)
  Future<void> savePhq9Result(Phq9Result r) async {
    await _db.collection('phq9_results').add(r.toMap());
  }

  /// อัปเดตสถานะผู้ใช้หลังทำ PHQ-9
  Future<void> updatePhq9Status({
    required String uid,
    required String riskLevel,
  }) async {
    await _db.collection('users').doc(uid).set({
      // PHQ-9
      'hasCompletedPhq9': true,
      'phq9RiskLevel': riskLevel,

      // ⭐ สำคัญ: ทุกครั้งที่ทำ PHQ-9 ใหม่
      // ต้องบังคับให้ Deep Assessment เริ่มใหม่
      'hasCompletedDeepAssessment': false,
      'deepRiskLevel': null,

      'lastPhq9At': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // =========================
  // DASHBOARD
  // =========================

  Stream<List<AppUser>> watchPatientsForDashboard() {
    return _db.collection('users').snapshots().map((qs) {
      final users = qs.docs
          .map((d) => AppUser.fromMap(d.id, d.data()))
          .toList();

      final patients = users.where((u) => u.role == UserRole.patient).toList();

      int rank(String? r) {
        switch (r) {
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

      // ✅ เรียงตามความเสี่ยงจาก PHQ-9 เท่านั้น
      patients.sort(
        (a, b) => rank(a.phq9RiskLevel).compareTo(rank(b.phq9RiskLevel)),
      );

      return patients;
    });
  }

  // =========================
  // APPOINTMENT
  // =========================

  Future<void> createAppointment({
    required AppUser user,
    required DateTime appointmentAt,
    String? note,
  }) async {
    await _db.collection('appointments').add({
      'patientUid': user.uid,
      'patientName': user.name,
      'appointmentAt': appointmentAt,
      'note': note,
      'status': 'pending', // pending | confirmed | completed | canceled
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
