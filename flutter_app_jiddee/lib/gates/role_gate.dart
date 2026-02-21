import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/app_user.dart';
import '../services/firestore_service.dart';

import '../shells/dashboard_shell.dart';
import '../shells/patient_shell.dart';

import '../services/notification_service.dart';

class RoleGate extends StatefulWidget {
  final User firebaseUser;

  const RoleGate({super.key, required this.firebaseUser});

  @override
  State<RoleGate> createState() => _RoleGateState();
}

class _RoleGateState extends State<RoleGate> {
  final _fs = FirestoreService();
  String? _initedUid;

  StreamSubscription<String?>? _tapSub;

  void _maybeInitNoti(AppUser appUser) {
    // init เฉพาะ patient (ถ้าจะให้ admin ได้ด้วยก็เอาเงื่อนไขออก)
    if (appUser.role == UserRole.admin) return;

    if (_initedUid == appUser.uid) return;
    _initedUid = appUser.uid;

    Future.microtask(() async {
      try {
        await NotificationService.instance.initForUser(appUser.uid);

        // ✅ listen tap ครั้งเดียว
        _tapSub ??= NotificationService.instance.onTapStream.listen((payload) {
          if (payload == null) return;

          if (payload.startsWith('appointment:')) {
            final apptId = payload.split(':').last;
            debugPrint('Tapped appointment=$apptId');

            // TODO: นำทางไปหน้า appointment detail / home
            // ตัวอย่าง (ถ้าคุณมี route):
            // Navigator.of(context).push(MaterialPageRoute(
            //   builder: (_) => AppointmentDetailScreen(apptId: apptId),
            // ));
          }
        });
      } catch (e) {
        debugPrint('Notification init failed: $e');
      }
    });
  }

  @override
  void dispose() {
    _tapSub?.cancel();
    NotificationService.instance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppUser>(
      stream: _fs.watchUser(widget.firebaseUser.uid),
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
          return const Scaffold(body: Center(child: Text('ไม่พบข้อมูลผู้ใช้')));
        }

        final appUser = snap.data!;
        _maybeInitNoti(appUser);

        if (appUser.role == UserRole.admin) {
          return DashboardShell(user: appUser);
        }

        return PatientShell(user: appUser);
      },
    );
  }
}
