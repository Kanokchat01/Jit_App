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

          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            // ✅ แก้: เอา orderBy ออก เพื่อไม่ต้องใช้ composite index
            stream: FirebaseFirestore.instance
                .collection('appointments')
                .where('patientUid', isEqualTo: user.uid)
                .snapshots(),
            builder: (context, snap) {
              if (snap.hasError) {
                return Text(
                  'เกิดข้อผิดพลาด: ${snap.error}',
                  style: const TextStyle(color: Colors.red),
                );
              }

              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = snap.data?.docs ?? [];
              if (docs.isEmpty) {
                return const Text('ยังไม่มีการนัดแพทย์');
              }

              // ✅ sort เองในฝั่ง client (ล่าสุดก่อน)
              final items = docs.map((d) => {'id': d.id, ...d.data()}).toList();
              items.sort((a, b) {
                final ad = _sortDate(a);
                final bd = _sortDate(b);
                return bd.compareTo(ad);
              });

              return Column(
                children: items.map((data) {
                  final status = (data['status'] ?? '-').toString();

                  DateTime? dt;
                  final apptAt = data['appointmentAt'];
                  if (apptAt is Timestamp) dt = apptAt.toDate();
                  if (apptAt is DateTime) dt = apptAt;

                  final dateText = dt == null
                      ? '-'
                      : '${dt.day.toString().padLeft(2, '0')}/'
                          '${dt.month.toString().padLeft(2, '0')}/'
                          '${dt.year} '
                          '${dt.hour.toString().padLeft(2, '0')}:'
                          '${dt.minute.toString().padLeft(2, '0')}';

                  final adminNote =
                      (data['adminNote'] ?? '').toString().trim();
                  final note = (data['note'] ?? '').toString().trim();

                  final badge = _statusBadge(status.toLowerCase());

                  return Card(
                    child: ListTile(
                      leading: Icon(badge.icon, color: badge.color),
                      title: Text(dateText),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('สถานะ: ${badge.text}'),
                          if (note.isNotEmpty) Text('หมายเหตุผู้ป่วย: $note'),
                          if (adminNote.isNotEmpty)
                            Text('หมายเหตุแอดมิน: $adminNote'),
                        ],
                      ),
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

  // เลือกวันที่สำหรับ sort
  DateTime _sortDate(Map<String, dynamic> a) {
    DateTime? dt;

    final apptAt = a['appointmentAt'];
    if (apptAt is Timestamp) dt = apptAt.toDate();
    if (apptAt is DateTime) dt = apptAt;

    final createdAtServer = a['createdAtServer'];
    if (dt == null && createdAtServer is Timestamp) dt = createdAtServer.toDate();

    final createdAt = a['createdAt'];
    if (dt == null && createdAt is Timestamp) dt = createdAt.toDate();

    final updatedAtServer = a['updatedAtServer'];
    if (dt == null && updatedAtServer is Timestamp) dt = updatedAtServer.toDate();

    final updatedAt = a['updatedAt'];
    if (dt == null && updatedAt is Timestamp) dt = updatedAt.toDate();

    return dt ?? DateTime.fromMillisecondsSinceEpoch(0);
  }

  _Badge _statusBadge(String s) {
    switch (s) {
      case 'pending':
        return _Badge('รออนุมัติ', Icons.hourglass_top, Colors.orange);
      case 'approved':
      case 'confirmed':
        return _Badge('อนุมัติแล้ว', Icons.check_circle, Colors.green);
      case 'rejected':
        return _Badge('ปฏิเสธ', Icons.cancel, Colors.red);
      case 'canceled':
        return _Badge('ยกเลิก', Icons.block, Colors.grey);
      case 'completed':
        return _Badge('เสร็จสิ้น', Icons.verified, Colors.blueGrey);
      default:
        return _Badge('สถานะ: $s', Icons.info, Colors.blueGrey);
    }
  }
}

class _Badge {
  final String text;
  final IconData icon;
  final Color color;
  _Badge(this.text, this.icon, this.color);
}
