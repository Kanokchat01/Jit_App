import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_user.dart';
import '../services/firestore_service.dart';
import '../screens/dashboard/dashboard_home.dart';

class PatientShell extends StatefulWidget {
  final AppUser user;
  const PatientShell({super.key, required this.user});

  @override
  State<PatientShell> createState() => _PatientShellState();
}

class _PatientShellState extends State<PatientShell> {
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _notiSub;
  bool _dialogShowing = false;

  @override
  void initState() {
    super.initState();
    _startNotificationListener(widget.user.uid);
  }

  @override
  void didUpdateWidget(covariant PatientShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user.uid != widget.user.uid) {
      _startNotificationListener(widget.user.uid);
    }
  }

  @override
  void dispose() {
    _notiSub?.cancel();
    super.dispose();
  }

  void _startNotificationListener(String uid) {
    _notiSub?.cancel();

    _notiSub = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .where('read', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots()
        .listen((snap) async {
      if (snap.docs.isEmpty) return;
      if (!mounted) return;

      final doc = snap.docs.first;
      final data = doc.data();

      final title = (data['title'] ?? 'แจ้งเตือน').toString();
      final body = (data['body'] ?? '').toString();

      // กันเด้งซ้อน (กรณี snapshot มาซ้ำเร็ว ๆ)
      if (_dialogShowing) return;
      _dialogShowing = true;

      // โชว์ popup
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('ตกลง'),
            ),
          ],
        ),
      );

      _dialogShowing = false;

      // mark read กันเด้งซ้ำ
      try {
        await doc.reference.update({'read': true});
      } catch (_) {
        // เงียบไว้
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppUser>(
      stream: FirestoreService().watchUser(widget.user.uid),
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
