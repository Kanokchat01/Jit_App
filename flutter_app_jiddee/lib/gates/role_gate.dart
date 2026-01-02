import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/app_user.dart';
import '../services/firestore_service.dart';

import '../shells/dashboard_shell.dart';
import '../shells/patient_shell.dart';

class RoleGate extends StatelessWidget {
  /// ✅ รับ Firebase User จาก AuthGate
  final User firebaseUser;

  const RoleGate({
    super.key,
    required this.firebaseUser,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppUser>(
      stream: FirestoreService().watchUser(firebaseUser.uid),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snap.hasError) {
          return const Scaffold(
            body: Center(child: Text('เกิดข้อผิดพลาดในการโหลดข้อมูลผู้ใช้')),
          );
        }

        if (!snap.hasData) {
          return const Scaffold(
            body: Center(child: Text('ไม่พบข้อมูลผู้ใช้')),
          );
        }

        final appUser = snap.data!;

        // =========================
        // ADMIN
        // =========================
        if (appUser.role == UserRole.admin) {
          return DashboardShell(user: appUser);
        }

        // =========================
        // PATIENT / USER
        // =========================
        // ❗️สำคัญ:
        // RoleGate ต้องเลือก "Shell" เท่านั้น
        // ห้าม redirect ไป Appointment / Deep โดยตรง
        // ให้ Home เป็นคนแสดงสถานะเอง
        return PatientShell(user: appUser);
      },
    );
  }
}
