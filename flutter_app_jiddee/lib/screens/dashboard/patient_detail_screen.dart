import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/app_user.dart';
import '../../models/risk_level.dart';
import '../../services/firestore_service.dart';

class PatientDetailScreen extends StatelessWidget {
  final AppUser user;

  const PatientDetailScreen({
    super.key,
    required this.user,
  });

  @override
  Widget build(BuildContext context) {
    final fs = FirestoreService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('รายละเอียดผู้ป่วย'),
      ),
      body: StreamBuilder<AppUser>(
        stream: fs.watchUser(user.uid),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snap.hasError || !snap.hasData) {
            return const Center(
              child: Text('ไม่สามารถโหลดข้อมูลผู้ป่วยได้'),
            );
          }

          final u = snap.data!;
          final phqRisk = riskFromString(u.phq9RiskLevel);
          final deepRisk = riskFromString(u.deepRiskLevel);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _sectionTitle('ข้อมูลพื้นฐาน'),
              _infoTile('ชื่อ', u.name),
              _infoTile('บทบาท', u.role.name),
              if (u.phone != null) _infoTile('เบอร์โทร', u.phone!),
              if (u.age != null) _infoTile('อายุ', u.age!),
              if (u.gender != null) _infoTile('เพศ', u.gender!),

              const SizedBox(height: 16),
              _sectionTitle('ผลการประเมิน'),

              _riskTile(
                title: 'PHQ-9',
                completed: u.hasCompletedPhq9,
                risk: phqRisk,
              ),

              _riskTile(
                title: 'แบบสอบถามเชิงลึก (TMHI-55)',
                completed: u.hasCompletedDeepAssessment,
                risk: deepRisk,
                score: u.deepScore,
              ),

              const SizedBox(height: 16),
              _sectionTitle('การนัดหมาย'),

              StreamBuilder<Map<String, dynamic>?>(
                stream: fs.watchLatestAppointment(u.uid),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const ListTile(
                      title: Text('กำลังโหลดข้อมูลการนัดหมาย...'),
                    );
                  }

                  final appt = snap.data;
                  if (appt == null) {
                    return const ListTile(
                      title: Text('ยังไม่มีการนัดหมาย'),
                    );
                  }

                  final status = appt['status'] ?? '-';
                  final apptAt = appt['appointmentAt'];
                  DateTime? dt;

                  if (apptAt is Timestamp) {
                    dt = apptAt.toDate();
                  }

                  final dateText = dt == null
                      ? '-'
                      : '${dt.day.toString().padLeft(2, '0')}/'
                          '${dt.month.toString().padLeft(2, '0')}/'
                          '${dt.year} '
                          '${dt.hour.toString().padLeft(2, '0')}:'
                          '${dt.minute.toString().padLeft(2, '0')}';

                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.calendar_month),
                      title: Text('สถานะ: $status'),
                      subtitle: Text('วันนัด: $dateText'),
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  // ================= UI helpers =================

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _infoTile(String title, String value) {
    return ListTile(
      dense: true,
      title: Text(title),
      subtitle: Text(value),
    );
  }

  Widget _riskTile({
    required String title,
    required bool completed,
    RiskLevel? risk,
    int? score,
  }) {
    if (!completed) {
      return ListTile(
        leading: const Icon(Icons.warning, color: Colors.orange),
        title: Text(title),
        subtitle: const Text('ยังไม่ได้ทำ'),
      );
    }

    return ListTile(
      leading: Icon(
        risk?.icon ?? Icons.info,
        color: risk?.color ?? Colors.blueGrey,
      ),
      title: Text(title),
      subtitle: Text(
        risk == null
            ? 'ไม่มีระดับความเสี่ยง'
            : '${risk.label}${score != null ? ' • คะแนน $score' : ''}',
      ),
    );
  }
}
