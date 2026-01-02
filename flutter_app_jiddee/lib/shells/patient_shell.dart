import 'package:flutter/material.dart';
import '../models/app_user.dart';
import '../services/firestore_service.dart';
import '../screens/dashboard/dashboard_home.dart';

class PatientShell extends StatelessWidget {
  final AppUser user;
  const PatientShell({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppUser>(
      stream: FirestoreService().watchUser(user.uid),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (!snap.hasData) {
          return const Scaffold(
            body: Center(child: Text('ไม่พบข้อมูลผู้ใช้')),
          );
        }

        final liveUser = snap.data!;

        return Scaffold(
          body: DashboardHome(user: liveUser),
        );
      },
    );
  }
}
