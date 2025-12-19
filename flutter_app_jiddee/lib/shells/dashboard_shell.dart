import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/app_user.dart';
import '../screens/dashboard/dashboard_home.dart';
import '../screens/dashboard/patient_list_screen.dart';

class DashboardShell extends StatefulWidget {
  final AppUser user;
  const DashboardShell({super.key, required this.user});

  @override
  State<DashboardShell> createState() => _DashboardShellState();
}

class _DashboardShellState extends State<DashboardShell> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      DashboardHome(user: widget.user),
      const PatientListScreen(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text('Dashboard (${widget.user.role.name})'),
        actions: [
          IconButton(
            onPressed: () => FirebaseAuth.instance.signOut(),
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
          ),
        ],
      ),
      body: pages[index],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: index,
        onTap: (i) => setState(() => index = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Overview'),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Patients'),
        ],
      ),
    );
  }
}
