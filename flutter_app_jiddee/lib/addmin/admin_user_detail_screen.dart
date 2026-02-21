import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../../models/app_user.dart';

class AdminUserDetailScreen extends StatelessWidget {
  final AppUser user;
  const AdminUserDetailScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      //ส่วนของฟังชั่นลบuser
      /*appBar: AppBar(
        title: Text(user.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: () => _confirmDelete(context),
          ),
        ],
      ),*/
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildPatientCard(context),

          const SizedBox(height: 24),
          const Divider(),

          const Text(
            'การนัดแพทย์',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          _buildAppointments(),
        ],
      ),
    );
  }

  // =========================
  // 🎨 Dynamic Card Color
  // =========================

  Color _cardColor() {
    final risk = user.deepRiskLevel?.toLowerCase();

    switch (risk) {
      case 'red':
        return Colors.red.shade50;
      case 'yellow':
        return Colors.orange.shade50;
      case 'green':
        return Colors.green.shade50;
      default:
        return Colors.blue.shade50; // ยังไม่ประเมิน
    }
  }

  Color _topStripColor() {
    final risk = user.deepRiskLevel?.toLowerCase();

    switch (risk) {
      case 'red':
        return Colors.red;
      case 'yellow':
        return Colors.orange;
      case 'green':
        return Colors.green;
      default:
        return Colors.blue;
    }
  }

  // =========================
  // 🏥 Patient Card
  // =========================

  Widget _buildPatientCard(BuildContext context) {
    final age = _calculateAge(user.birthDate);

    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Column(
        children: [
          Container(
            height: 8,
            decoration: BoxDecoration(
              color: _topStripColor(),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(18),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _cardColor(),
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(18),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 34,
                      backgroundColor: _topStripColor(),
                      child: const Icon(
                        Icons.person,
                        color: Colors.white,
                        size: 38,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.name,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            user.email ?? '-',
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),
                const Divider(),

                Wrap(
                  spacing: 20,
                  runSpacing: 10,
                  children: [
                    _infoItem('เบอร์โทร', user.phone ?? '-'),
                    _infoItem('วันเกิด', user.birthDate ?? '-'),
                    _infoItem('อายุ', age ?? '-'),
                    _infoItem('เพศ', user.gender ?? '-'),
                    _infoItem('คณะ', user.faculty ?? '-'),
                    _infoItem('สาขา', user.major ?? '-'),
                    _infoItem('รหัสนักศึกษา', user.studentId ?? '-'),
                    _infoItem('ชั้นปี', user.year ?? '-'),
                  ],
                ),

                const SizedBox(height: 16),

                _statusRow(
                  'PHQ-9',
                  user.hasCompletedPhq9
                      ? (user.phq9RiskLevel ?? '-')
                      : 'ยังไม่ได้ประเมิน',
                ),
                const SizedBox(height: 8),
                _statusRow(
                  'Deep Assessment',
                  user.hasCompletedDeepAssessment
                      ? (user.deepRiskLevel ?? '-')
                      : 'ยังไม่ได้ประเมิน',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoItem(String label, String value) {
    return SizedBox(
      width: 160,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.blueGrey),
          ),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _statusRow(String label, String value) {
    return Row(
      children: [
        SizedBox(
          width: 150,
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        Chip(label: Text(value)),
      ],
    );
  }

  // =========================
  // 📅 Appointments
  // =========================

  Widget _buildAppointments() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('appointments')
          .where('patientUid', isEqualTo: user.uid)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Text('ยังไม่มีการนัดแพทย์');
        }

        final items = docs.map((d) => {'id': d.id, ...d.data()}).toList();
        items.sort((a, b) => _sortDate(b).compareTo(_sortDate(a)));

        return Column(
          children: items.map((data) {
            final status = (data['status'] ?? '-').toString();
            final badge = _statusBadge(status.toLowerCase());

            DateTime? dt;
            final apptAt = data['appointmentAt'];
            if (apptAt is Timestamp) dt = apptAt.toDate();

            final dateText = dt == null
                ? '-'
                : DateFormat('dd/MM/yyyy HH:mm').format(dt);

            return Card(
              child: ListTile(
                leading: Icon(badge.icon, color: badge.color),
                title: Text(dateText),
                subtitle: Text('สถานะ: ${badge.text}'),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  DateTime _sortDate(Map<String, dynamic> a) {
    final apptAt = a['appointmentAt'];
    if (apptAt is Timestamp) return apptAt.toDate();
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  _Badge _statusBadge(String s) {
    switch (s) {
      case 'pending':
        return _Badge('รออนุมัติ', Icons.hourglass_top, Colors.orange);
      case 'approved':
        return _Badge('อนุมัติแล้ว', Icons.check_circle, Colors.green);
      case 'rejected':
        return _Badge('ปฏิเสธ', Icons.cancel, Colors.red);
      default:
        return _Badge(s, Icons.info, Colors.blueGrey);
    }
  }

  String? _calculateAge(String? birthDate) {
    if (birthDate == null || birthDate.isEmpty) return null;
    try {
      final parsed = DateFormat('dd/MM/yyyy').parse(birthDate);
      final now = DateTime.now();
      int age = now.year - parsed.year;
      if (now.month < parsed.month ||
          (now.month == parsed.month && now.day < parsed.day)) {
        age--;
      }
      return '$age ปี';
    } catch (_) {
      return null;
    }
  }

  // =========================
  // 🗑 Delete User
  // =========================
  //ส่วนของปุ่มฟังชั่นลบuser
  /*Future<void> _confirmDelete(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('ยืนยันการลบผู้ใช้'),
        content: const Text(
          'คุณแน่ใจหรือไม่ว่าต้องการลบผู้ใช้รายนี้?\nการกระทำนี้ไม่สามารถย้อนกลับได้',
        ),
        actions: [
          TextButton(
            child: const Text('ยกเลิก'),
            onPressed: () => Navigator.pop(context, false),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('ลบ'),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .delete();

      if (context.mounted) {
        Navigator.pop(context);
      }
    }
  }*/
}

class _Badge {
  final String text;
  final IconData icon;
  final Color color;
  _Badge(this.text, this.icon, this.color);
}
