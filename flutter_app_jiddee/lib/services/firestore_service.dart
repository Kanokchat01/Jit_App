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

  /// สร้าง user doc เฉพาะครั้งแรกเท่านั้น
  /// ❗ สำคัญ: ห้าม overwrite role ของ admin/clinician
  Future<void> ensureUserDoc({
    required String uid,
    required String name,
    String role = 'patient',
  }) async {
    final ref = _db.collection('users').doc(uid);

    final snap = await ref.get();
    if (snap.exists) {
      // มี user อยู่แล้ว → ไม่แก้อะไร
      return;
    }

    await ref.set({
      'name': name,
      'role': role, // patient (default)
      'consentCamera': false,

      // ⭐ สำคัญ: ผู้ใช้ใหม่ต้องทำ PHQ-9
      'hasCompletedPhq9': false,

      'lastRiskLevel': null,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // =========================
  // PHQ-9
  // =========================

  Future<void> savePhq9Result(Phq9Result r) async {
    // เก็บผลแบบสอบถาม
    await _db.collection('phq9_results').add(r.toMap());

    // ⭐ อัปเดตสถานะผู้ใช้
    await _db.collection('users').doc(r.uid).set({
      'hasCompletedPhq9': true, // ทำ PHQ-9 แล้ว
      'lastRiskLevel': r.riskLevel,
      'lastAssessmentAt': FieldValue.serverTimestamp(),
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

      // เอาเฉพาะ patient
      final patients = users.where((u) => u.role == UserRole.patient).toList();

      // sort: red > yellow > green > null
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

      patients.sort(
        (a, b) => rank(a.lastRiskLevel).compareTo(rank(b.lastRiskLevel)),
      );
      return patients;
    });
  }
}
