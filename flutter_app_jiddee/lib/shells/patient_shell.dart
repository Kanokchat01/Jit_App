import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/app_user.dart';
import '../screens/dashboard/dashboard_home.dart';

class PatientShell extends StatelessWidget {
  final AppUser user;
  const PatientShell({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('JidDee'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              // ❗ ไม่ต้อง Navigator.push
              // AuthGate จะพากลับหน้า Login ให้อัตโนมัติ
            },
          ),
        ],
      ),
      body: DashboardHome(user: user),
    );
  }
}
