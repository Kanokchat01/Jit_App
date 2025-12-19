import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/app_user.dart';
import '../screens/patient/patient_home.dart';
import '../screens/patient/phq9_screen.dart';

class PatientShell extends StatefulWidget {
  final AppUser user;
  const PatientShell({super.key, required this.user});

  @override
  State<PatientShell> createState() => _PatientShellState();
}

class _PatientShellState extends State<PatientShell> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      PatientHome(user: widget.user),
      Phq9Screen(user: widget.user),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('JidDee (Patient)'),
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
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.assignment), label: 'PHQ-9'),
        ],
      ),
    );
  }
}
