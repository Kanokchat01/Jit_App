import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/app_user.dart';
import '../services/firestore_service.dart';

// shells / screens
import '../shells/dashboard_shell.dart';
import '../shells/patient_shell.dart';
import '../screens/patient/phq9_screen.dart';
import '../screens/deep_assessment/deep_assessment_screen.dart';
import '../addmin/admin_home.dart';

class RoleGate extends StatelessWidget {
  final User user;
  const RoleGate({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppUser>(
      stream: FirestoreService().watchUser(user.uid),
      builder: (context, snap) {
        // ---------- error ----------
        if (snap.hasError) {
          return Scaffold(
            body: Center(
              child: Text(
                'Firestore Error:\n${snap.error}',
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        // ---------- loading ----------
        if (!snap.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final userData = snap.data!;

        // =========================
        // ADMIN
        // =========================
        if (userData.role == UserRole.admin) {
          return AdminHome(user: userData);
        }

        // =========================
        // CLINICIAN
        // =========================
        if (userData.role == UserRole.clinician) {
          return DashboardShell(user: userData);
        }

        // =========================
        // PATIENT FLOW (STRICT ORDER)
        // =========================

        final String? phq9Risk = userData.phq9RiskLevel;

        // 1) ยังไม่ทำ PHQ-9 → บังคับทำก่อนเสมอ
        if (!userData.hasCompletedPhq9) {
          return Phq9Screen(user: userData);
        }

        // 2) ทำ PHQ-9 แล้ว และผลไม่ใช่เขียว
        //    → ต้องทำ Deep Assessment (ถ้ายังไม่ทำ)
        if (phq9Risk != null &&
            phq9Risk != 'green' &&
            !userData.hasCompletedDeepAssessment) {
          return DeepAssessmentScreen(user: userData);
        }

        // 3) ผ่านทุกขั้น → เข้า Home
        return PatientShell(user: userData);
      },
    );
  }
}
