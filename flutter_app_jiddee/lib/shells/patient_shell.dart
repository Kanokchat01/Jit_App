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

      if (_dialogShowing) return;
      _dialogShowing = true;

      final cs = Theme.of(context).colorScheme;

      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: cs.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.notifications_none, color: cs.primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          content: Text(
            body,
            style: TextStyle(height: 1.35, color: Colors.black.withOpacity(0.70)),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          actions: [
            SizedBox(
              height: 44,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('ตกลง'),
              ),
            ),
          ],
        ),
      );

      _dialogShowing = false;

      try {
        await doc.reference.update({'read': true});
      } catch (_) {
        // เงียบไว้
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return StreamBuilder<AppUser>(
      stream: FirestoreService().watchUser(widget.user.uid),
      builder: (context, snap) {
        // ✅ Loading (UI นุ่มขึ้น แต่ logic เดิม)
        if (snap.connectionState == ConnectionState.waiting) {
          return Scaffold(
            body: _DecorBackground(
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        blurRadius: 22,
                        offset: const Offset(0, 12),
                        color: Colors.black.withOpacity(0.06),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: cs.primary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'กำลังโหลดข้อมูลผู้ใช้...',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Colors.black.withOpacity(0.70),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        // ✅ Not found (UI นุ่มขึ้น แต่ logic เดิม)
        if (!snap.hasData) {
          return Scaffold(
            body: _DecorBackground(
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(18),
                  margin: const EdgeInsets.symmetric(horizontal: 22),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        blurRadius: 22,
                        offset: const Offset(0, 12),
                        color: Colors.black.withOpacity(0.06),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.person_off_outlined, size: 42, color: cs.primary),
                      const SizedBox(height: 10),
                      Text(
                        'ไม่พบข้อมูลผู้ใช้',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Colors.black.withOpacity(0.75),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'กรุณาลองเข้าสู่ระบบใหม่ หรือแจ้งผู้ดูแลระบบ',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          height: 1.35,
                          color: Colors.black.withOpacity(0.55),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        final liveUser = snap.data!;

        // ✅ หน้าหลัก: ไม่เปลี่ยนฟังก์ชัน แค่ใส่ฉากหลัง + safe area
        return Scaffold(
          body: _DecorBackground(
            child: SafeArea(
              child: DashboardHome(user: liveUser),
            ),
          ),
        );
      },
    );
  }
}

/// ✅ Background ตกแต่ง (เหมือน Login/Register) — ไม่มีผลกับ logic
class _DecorBackground extends StatelessWidget {
  final Widget child;
  const _DecorBackground({required this.child});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                cs.primary.withOpacity(0.10),
                cs.secondary.withOpacity(0.12),
                Theme.of(context).scaffoldBackgroundColor,
              ],
            ),
          ),
        ),
        Positioned(
          top: -90,
          left: -70,
          child: _softBlob(cs.primary.withOpacity(0.18), 220),
        ),
        Positioned(
          bottom: -110,
          right: -90,
          child: _softBlob(cs.secondary.withOpacity(0.22), 260),
        ),
        child,
      ],
    );
  }

  Widget _softBlob(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}