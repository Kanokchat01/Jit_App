import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/app_user.dart';

class AdminUserDetailScreen extends StatelessWidget {
  final AppUser user;
  const AdminUserDetailScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(user.name)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          /// =========================
          /// User Info
          /// =========================
          Text(user.name, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text('Role: ${user.role.name}'),
          Text('PHQ-9: ${user.phq9RiskLevel ?? '-'}'),
          Text('Deep Assessment: ${user.deepRiskLevel ?? '-'}'),

          const SizedBox(height: 24),
          const Divider(),

          /// =========================
          /// Appointments
          /// =========================
          const Text(
            'การนัดแพทย์',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('appointments')
                .where('patientUid', isEqualTo: user.uid)
                .orderBy('appointmentAt', descending: true)
                .snapshots(),
            builder: (context, snap) {
              // 🔴 สำคัญมาก
              if (snap.hasError) {
                return Text(
                  'เกิดข้อผิดพลาด: ${snap.error}',
                  style: const TextStyle(color: Colors.red),
                );
              }

              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snap.hasData || snap.data!.docs.isEmpty) {
                return const Text('ยังไม่มีการนัดแพทย์');
              }

              final docs = snap.data!.docs;

              return Column(
                children: docs.map((d) {
                  final data = d.data() as Map<String, dynamic>;
                  final ts = data['appointmentAt'] as Timestamp;
                  final dt = ts.toDate();

                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.calendar_today),
                      title: Text(
                        '${dt.day}/${dt.month}/${dt.year} '
                        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}',
                      ),
                      subtitle: Text('สถานะ: ${data['status']}'),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}
