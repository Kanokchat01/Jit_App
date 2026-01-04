import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/app_user.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final usersStream = FirebaseFirestore.instance.collection('users').snapshots();
    final pendingApptStream = FirebaseFirestore.instance
        .collection('appointments')
        .where('status', isEqualTo: 'pending')
        .snapshots();

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Dashboard', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),

            StreamBuilder<QuerySnapshot>(
              stream: usersStream,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const _LoadingCards();
                }
                if (snap.hasError) {
                  return _ErrorCard('โหลดสรุปผู้ใช้ไม่สำเร็จ\n${snap.error}');
                }

                final docs = snap.data?.docs ?? [];
                final users = docs.map((d) {
                  final data = (d.data() as Map<String, dynamic>?) ?? {};
                  return AppUser.fromMap(d.id, data);
                }).toList();

                // เฉพาะ patient
                final patients = users.where((u) => u.role.name.toLowerCase() == 'patient').toList();

                final phqRed = patients.where((u) => (u.phq9RiskLevel ?? '').toLowerCase() == 'red').length;
                final deepRed = patients.where((u) => (u.deepRiskLevel ?? '').toLowerCase() == 'red').length;

                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: _StatCard(title: 'ผู้ป่วยทั้งหมด', value: '${patients.length}', icon: Icons.people)),
                        const SizedBox(width: 12),
                        Expanded(child: _StatCard(title: 'PHQ-9 แดง', value: '$phqRed', icon: Icons.warning, tone: _Tone.red)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _StatCard(title: 'Deep แดง', value: '$deepRed', icon: Icons.local_hospital, tone: _Tone.red)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: StreamBuilder<QuerySnapshot>(
                            stream: pendingApptStream,
                            builder: (context, apptSnap) {
                              if (apptSnap.connectionState == ConnectionState.waiting) {
                                return const _StatCard(title: 'คิวนัด Pending', value: '...', icon: Icons.event_note, tone: _Tone.orange);
                              }
                              if (apptSnap.hasError) {
                                return const _StatCard(title: 'คิวนัด Pending', value: '-', icon: Icons.event_note, tone: _Tone.orange);
                              }
                              final pending = apptSnap.data?.docs.length ?? 0;
                              return _StatCard(
                                title: 'คิวนัด Pending',
                                value: '$pending',
                                icon: Icons.event_note,
                                tone: _Tone.orange,
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

            const SizedBox(height: 18),
            const Text('Tips', style: TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            const _TipBox(),
          ],
        ),
      ),
    );
  }
}

class _LoadingCards extends StatelessWidget {
  const _LoadingCards();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        Row(
          children: [
            Expanded(child: _StatCard(title: 'ผู้ป่วยทั้งหมด', value: '...', icon: Icons.people)),
            SizedBox(width: 12),
            Expanded(child: _StatCard(title: 'PHQ-9 แดง', value: '...', icon: Icons.warning, tone: _Tone.red)),
          ],
        ),
        SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _StatCard(title: 'Deep แดง', value: '...', icon: Icons.local_hospital, tone: _Tone.red)),
            SizedBox(width: 12),
            Expanded(child: _StatCard(title: 'คิวนัด Pending', value: '...', icon: Icons.event_note, tone: _Tone.orange)),
          ],
        ),
      ],
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String text;
  const _ErrorCard(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.red.withOpacity(0.08),
        border: Border.all(color: Colors.red.withOpacity(0.25)),
      ),
      child: Text(text, style: const TextStyle(color: Colors.red)),
    );
  }
}

enum _Tone { normal, orange, red }

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final _Tone tone;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    this.tone = _Tone.normal,
  });

  @override
  Widget build(BuildContext context) {
    Color c;
    switch (tone) {
      case _Tone.red:
        c = Colors.red;
        break;
      case _Tone.orange:
        c = Colors.orange;
        break;
      default:
        c = Colors.blueGrey;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: c.withOpacity(0.08),
        border: Border.all(color: c.withOpacity(0.22)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: c.withOpacity(0.14),
            child: Icon(icon, color: c),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: c)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TipBox extends StatelessWidget {
  const _TipBox();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.blueGrey.withOpacity(0.06),
        border: Border.all(color: Colors.blueGrey.withOpacity(0.15)),
      ),
      child: const Text(
        '• ไปที่แท็บ “คิวนัด” เพื่ออนุมัติ/ปฏิเสธการนัด\n'
        '• ไปที่แท็บ “ผู้ป่วย” เพื่อค้นหา/กรองตามความเสี่ยง\n'
        '• กดเข้ารายละเอียดผู้ป่วยเพื่อดูประวัติการนัดทั้งหมด',
      ),
    );
  }
}
