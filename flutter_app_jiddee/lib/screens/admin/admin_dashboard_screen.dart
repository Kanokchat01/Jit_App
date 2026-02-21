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
          AndroidFlutterLocalNotificationsPlugin
        >();

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
  // BUILD
  // ===============================
  @override
  Widget build(BuildContext context) {
    final usersStream = FirebaseFirestore.instance
        .collection('users')
        .snapshots();

    final pendingApptStream = FirebaseFirestore.instance
        .collection('appointments')
        .where('status', isEqualTo: 'pending')
        .snapshots();

    return Scaffold(
      // ❌ ไม่มี AppBar
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: StreamBuilder<QuerySnapshot>(
            stream: usersStream,
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = snap.data!.docs;

              final patients = docs
                  .map(
                    (d) =>
                        AppUser.fromMap(d.id, d.data() as Map<String, dynamic>),
                  )
                  .where((u) => u.role.name.toLowerCase() == 'patient')
                  .toList();

              final phqRed = patients
                  .where((u) => (u.phq9RiskLevel ?? '').toLowerCase() == 'red')
                  .length;

              final deepRed = patients
                  .where((u) => (u.deepRiskLevel ?? '').toLowerCase() == 'red')
                  .length;

              return Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          title: 'ผู้ป่วยทั้งหมด',
                          value: '${patients.length}',
                          icon: Icons.people,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatCard(
                          title: 'PHQ-9 แดง',
                          value: '$phqRed',
                          icon: Icons.warning,
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          title: 'Deep แดง',
                          value: '$deepRed',
                          icon: Icons.local_hospital,
                          color: Colors.red,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: StreamBuilder<QuerySnapshot>(
                          stream: pendingApptStream,
                          builder: (context, apptSnap) {
                            final pending = apptSnap.data?.docs.length ?? 0;
                            return _StatCard(
                              title: 'คิวนัด Pending',
                              value: '$pending',
                              icon: Icons.event_note,
                              color: Colors.orange,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),

      // ✅ ปุ่มลอยแทนกระดิ่ง
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFFE75480),
        onPressed: _openNotificationSheet,
        child: const Icon(Icons.notifications),
      ),
    );
  }

  // ===============================
  // 🔔 BottomSheet
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
      builder: (_) {
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('admin_notifications')
              .orderBy('createdAt', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final docs = snapshot.data!.docs;

            if (docs.isEmpty) {
              return const Center(child: Text("ยังไม่มีแจ้งเตือน"));
            }

            return ListView.builder(
              itemCount: docs.length,
              itemBuilder: (_, i) {
                final data = docs[i].data() as Map<String, dynamic>;
                return ListTile(
                  leading: const Icon(Icons.notifications),
                  title: Text(data['title'] ?? ''),
                  subtitle: Text(data['body'] ?? ''),
                );
              },
            );
          },
        );
      },
    );
  }
}

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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: color.withOpacity(0.08),
        border: Border.all(color: color.withOpacity(0.22)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withOpacity(0.14),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
