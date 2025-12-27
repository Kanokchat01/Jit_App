import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../../models/risk_level.dart';
import '../patient/phq9_screen.dart';

class DashboardHome extends StatelessWidget {
  final AppUser user;
  const DashboardHome({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    /// =========================
    /// PHQ-9
    /// =========================
    final bool hasPhq9 = user.hasCompletedPhq9;
    final RiskLevel? phq9Risk = riskFromString(user.phq9RiskLevel);

    /// =========================
    /// Deep Assessment
    /// =========================
    final bool needDeepAssessment =
        phq9Risk != null && phq9Risk != RiskLevel.green;

    final bool hasDeepAssessment =
        needDeepAssessment && user.hasCompletedDeepAssessment;

    /// =========================
    /// Deep Assessment UI
    /// =========================
    late final String deepText;
    late final Color deepColor;
    late final IconData deepIcon;

    if (!needDeepAssessment) {
      deepText = 'ไม่จำเป็นต้องทำ (PHQ-9 อยู่ในระดับสีเขียว)';
      deepColor = Colors.grey;
      deepIcon = Icons.remove_circle_outline;
    } else if (!hasDeepAssessment) {
      deepText = 'ยังไม่ได้ทำแบบสอบถามเชิงลึก';
      deepColor = Colors.orange;
      deepIcon = Icons.warning;
    } else {
      final deepRisk = riskFromString(user.deepRiskLevel)!;
      deepText = 'ผลเชิงลึก: ${deepRisk.label}';
      deepColor = deepRisk.color;
      deepIcon = deepRisk.icon;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// =========================
          /// Header
          /// =========================
          Text('Welcome, ${user.name}', style: theme.textTheme.titleLarge),
          const SizedBox(height: 4),
          Text('Role: ${user.role.name}'),

          const SizedBox(height: 24),

          /// =========================
          /// ปุ่มหลัก: ทำ PHQ-9
          /// =========================
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.assignment),
              label: const Text(
                'ทำแบบประเมิน PHQ-9',
                style: TextStyle(fontSize: 16),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => Phq9Screen(user: user, fromHome: true),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 32),

          /// =========================
          /// สถานะล่าสุด
          /// =========================
          Text('สถานะแบบประเมินล่าสุด', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),

          /// -------- PHQ-9 --------
          Card(
            child: ListTile(
              leading: const Icon(Icons.assignment),
              title: const Text('PHQ-9'),
              subtitle: Text(
                hasPhq9 && phq9Risk != null
                    ? 'ทำแล้ว (${phq9Risk.label})'
                    : 'ยังไม่ได้ทำแบบประเมิน',
              ),
              trailing: Icon(
                hasPhq9 && phq9Risk != null ? phq9Risk.icon : Icons.warning,
                color: hasPhq9 && phq9Risk != null
                    ? phq9Risk.color
                    : Colors.orange,
              ),
            ),
          ),

          /// -------- Deep Assessment --------
          Card(
            child: ListTile(
              leading: Icon(deepIcon, color: deepColor),
              title: const Text('แบบสอบถามเชิงลึก'),
              subtitle: Text(deepText, style: TextStyle(color: deepColor)),
            ),
          ),

          const SizedBox(height: 24),

          /// =========================
          /// Info
          /// =========================
          const Card(
            child: ListTile(
              leading: Icon(Icons.info),
              title: Text('Overview'),
              subtitle: Text(
                'ข้อมูลนี้ใช้เพื่อช่วยประเมินและติดตามสุขภาพจิตของคุณ',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
