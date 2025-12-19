import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/app_user.dart';
import '../services/firestore_service.dart';
import '../shells/dashboard_shell.dart';
import '../shells/patient_shell.dart';

class RoleGate extends StatelessWidget {
  const RoleGate({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return StreamBuilder<AppUser>(
      stream: FirestoreService().watchUser(uid),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snap.data!;
        if (user.role == UserRole.patient) {
          return PatientShell(user: user);
        }
        return DashboardShell(user: user); // clinician/admin
      },
    );
  }
}
