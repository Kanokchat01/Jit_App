import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../models/app_user.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  StreamSubscription? _adminSub;
  final Set<String> _shownIds = {};

  static const String _channelId = 'admin_channel';
  static const String _channelName = 'Admin Notifications';

  @override
  void initState() {
    super.initState();
    _initLocalNotification();
    _listenAdminNotifications();
  }

  @override
  void dispose() {
    _adminSub?.cancel();
    super.dispose();
  }

  // ===============================
  // 🔔 LOCAL NOTIFICATION INIT
  // ===============================
  Future<void> _initLocalNotification() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: androidInit);

    await _local.initialize(settings);

    const channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      importance: Importance.max,
    );

    final androidPlugin = _local
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    await androidPlugin?.createNotificationChannel(channel);
  }

  // ===============================
  // 🔥 LISTEN FIRESTORE → เด้งนอกแอพ
  // ===============================
  void _listenAdminNotifications() {
    _adminSub = FirebaseFirestore.instance
        .collection('admin_notifications')
        .snapshots()
        .listen((snapshot) {
      for (final doc in snapshot.docs) {
        if (!_shownIds.contains(doc.id)) {
          _shownIds.add(doc.id);

          final data = doc.data();

          _local.show(
            DateTime.now().millisecondsSinceEpoch.remainder(100000),
            data['title'] ?? 'แจ้งเตือน',
            data['body'] ?? '',
            const NotificationDetails(
              android: AndroidNotificationDetails(
                _channelId,
                _channelName,
                importance: Importance.max,
                priority: Priority.high,
              ),
            ),
          );
        }
      }
    });
  }

  // ===============================
  // BUILD (UI ปรับใหม่: ไม่แตะ logic)
  // ===============================
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final usersStream = FirebaseFirestore.instance.collection('users').snapshots();

    final pendingApptStream = FirebaseFirestore.instance
        .collection('appointments')
        .where('status', isEqualTo: 'pending')
        .snapshots();

    return Scaffold(
      extendBodyBehindAppBar: true,

      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              cs.secondary.withOpacity(0.22),
              cs.primary.withOpacity(0.10),
              Colors.white,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: StreamBuilder<QuerySnapshot>(
              stream: usersStream,
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snap.data!.docs;

                final patients = docs
                    .map((d) =>
                        AppUser.fromMap(d.id, d.data() as Map<String, dynamic>))
                    .where((u) => u.role.name.toLowerCase() == 'patient')
                    .toList();

                final phqRed = patients
                    .where(
                      (u) => (u.phq9RiskLevel ?? '').toLowerCase() == 'red',
                    )
                    .length;

                final deepRed = patients
                    .where(
                      (u) => (u.deepRiskLevel ?? '').toLowerCase() == 'red',
                    )
                    .length;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),

                    Text(
                      "ภาพรวมระบบ",
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Colors.black.withOpacity(0.65),
                      ),
                    ),
                    const SizedBox(height: 14),

                    Expanded(
                      child: GridView.count(
                        crossAxisCount: 2,
                        mainAxisSpacing: 14,
                        crossAxisSpacing: 14,
                        childAspectRatio: 1.10,
                        children: [
                          _StatCard(
                            title: 'ผู้ป่วยทั้งหมด',
                            value: '${patients.length}',
                            icon: Icons.people_rounded,
                            color: const Color(0xFF4DA3FF),
                          ),
                          _StatCard(
                            title: 'PHQ-9 แดง',
                            value: '$phqRed',
                            icon: Icons.warning_rounded,
                            color: const Color(0xFFFF5E5E),
                          ),
                          _StatCard(
                            title: 'Deep แดง',
                            value: '$deepRed',
                            icon: Icons.local_hospital_rounded,
                            color: const Color(0xFFFF8A65),
                          ),
                          StreamBuilder<QuerySnapshot>(
                            stream: pendingApptStream,
                            builder: (context, apptSnap) {
                              final pending = apptSnap.data?.docs.length ?? 0;
                              return _StatCard(
                                title: 'คิวนัด Pending',
                                value: '$pending',
                                icon: Icons.event_note_rounded,
                                color: const Color(0xFFFFB74D),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),

      // ✅ ปุ่มลอยแทนกระดิ่ง (ยังเรียกฟังก์ชันเดิม)
      floatingActionButton: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            colors: [cs.primary, cs.secondary],
          ),
          boxShadow: [
            BoxShadow(
              blurRadius: 18,
              offset: const Offset(0, 10),
              color: cs.primary.withOpacity(0.30),
            ),
          ],
        ),
        child: FloatingActionButton(
          elevation: 0,
          backgroundColor: Colors.transparent,
          onPressed: _openNotificationSheet,
          child: const Icon(Icons.notifications, color: Colors.white),
        ),
      ),
    );
  }

  // ===============================
  // 🔔 BottomSheet (เดิม)
  // ===============================
  void _openNotificationSheet() async {
    final unread = await FirebaseFirestore.instance
        .collection('admin_notifications')
        .where('read', isEqualTo: false)
        .get();

    for (final doc in unread.docs) {
      await doc.reference.update({'read': true});
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) {
        final cs = Theme.of(context).colorScheme;

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 6),
              const Text(
                "การแจ้งเตือน (Admin)",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('admin_notifications')
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return Center(
                        child: CircularProgressIndicator(color: cs.primary),
                      );
                    }

                    final docs = snapshot.data!.docs;

                    if (docs.isEmpty) {
                      return const Center(child: Text("ยังไม่มีแจ้งเตือน"));
                    }

                    return ListView.builder(
                      itemCount: docs.length,
                      itemBuilder: (_, i) {
                        final data = docs[i].data() as Map<String, dynamic>;
                        final isRead = (data['read'] ?? false) == true;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.96),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: Colors.black.withOpacity(0.05),
                            ),
                            boxShadow: [
                              BoxShadow(
                                blurRadius: 16,
                                offset: const Offset(0, 8),
                                color: Colors.black.withOpacity(0.05),
                              ),
                            ],
                          ),
                          child: ListTile(
                            leading: Icon(
                              Icons.notifications_rounded,
                              color: isRead ? Colors.black38 : cs.primary,
                            ),
                            title: Text(
                              data['title'] ?? '',
                              style: TextStyle(
                                fontWeight:
                                    isRead ? FontWeight.w600 : FontWeight.w900,
                              ),
                            ),
                            subtitle: Text(data['body'] ?? ''),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ===============================
// ✅ Stat Card (UI ใหม่: ไม่แตะ logic)
// ===============================
class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    this.color = Colors.blueGrey,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        color: Colors.white.withOpacity(0.92),
        border: Border.all(color: Colors.black.withOpacity(0.04)),
        boxShadow: [
          BoxShadow(
            blurRadius: 20,
            offset: const Offset(0, 12),
            color: Colors.black.withOpacity(0.06),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color),
          ),
          const Spacer(),
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Colors.black.withOpacity(0.65),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}