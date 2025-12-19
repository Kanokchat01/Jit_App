import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_user.dart';
import '../models/phq9_result.dart';

class FirestoreService {
  final _db = FirebaseFirestore.instance;

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
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) {
        tx.set(ref, {
          'name': name,
          'role': role,
          'consentCamera': false,
          'lastRiskLevel': null,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  Future<void> savePhq9Result(Phq9Result r) async {
    await _db.collection('phq9_results').add(r.toMap());

    await _db.collection('users').doc(r.uid).set({
      'lastRiskLevel': r.riskLevel,
      'lastAssessmentAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Stream<List<AppUser>> watchPatientsForDashboard() {
    // clinician/admin ใช้ดูผู้ป่วยทั้งหมด (MVP)
    return _db.collection('users').snapshots().map((qs) {
      final users = qs.docs.map((d) => AppUser.fromMap(d.id, d.data())).toList();

      // เฉพาะ patient (กัน clinician/admin โผล่มาใน list)
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

      patients.sort((a, b) => rank(a.lastRiskLevel).compareTo(rank(b.lastRiskLevel)));
      return patients;
    });
  }
}
