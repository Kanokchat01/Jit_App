import 'package:flutter/material.dart';
import '../../models/app_user.dart';
import '../patient/phq9_screen.dart';

class DashboardHome extends StatelessWidget {
  final AppUser user;
  const DashboardHome({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    /// -------------------------
    /// สถานะ PHQ-9
    /// -------------------------
    final bool hasPhq9 = user.lastRiskLevel != null;

    /// -------------------------
    /// สถานะแบบสอบถามเชิงลึก
    /// -------------------------
    final bool needDeepAssessment =
        user.lastRiskLevel != null && user.lastRiskLevel != 'green';

    final bool hasDeepAssessment =
        needDeepAssessment && user.hasCompletedDeepAssessment;

    /// ข้อความ + สี ของผลเชิงลึก
    String deepText;
    Color deepColor;
    IconData deepIcon;

    if (!needDeepAssessment) {
      deepText = 'ไม่จำเป็นต้องทำ (PHQ-9 เป็นสีเขียว)';
      deepColor = Colors.grey;
      deepIcon = Icons.remove_circle_outline;
    } else if (!hasDeepAssessment) {
      deepText = 'ยังไม่ได้ทำแบบสอบถามนี้';
      deepColor = Colors.orange;
      deepIcon = Icons.warning;
    } else {
      switch (user.lastRiskLevel) {
        case 'green':
          deepText = 'ผลเชิงลึก: ความเสี่ยงต่ำ (เขียว)';
          deepColor = Colors.green;
          deepIcon = Icons.check_circle;
          break;
        case 'yellow':
          deepText = 'ผลเชิงลึก: ควรติดตาม (เหลือง)';
          deepColor = Colors.orange;
          deepIcon = Icons.warning;
          break;
        default:
          deepText = 'ผลเชิงลึก: ความเสี่ยงสูง (แดง)';
          deepColor = Colors.red;
          deepIcon = Icons.error;
      }
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
          /// ปุ่มหลัก: ทำ PHQ-9 (เริ่มใหม่แบบ clean)
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
                // 🔥 เคลียร์ stack ก่อน
                Navigator.popUntil(context, (route) => route.isFirst);

                // 🔥 เริ่มทำ PHQ-9 ใหม่
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => Phq9Screen(user: user)),
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
                hasPhq9
                    ? 'ทำแล้ว (ระดับความเสี่ยง: ${user.lastRiskLevel})'
                    : 'ยังไม่ได้ทำแบบประเมิน',
              ),
              trailing: Icon(
                hasPhq9 ? Icons.check_circle : Icons.warning,
                color: hasPhq9 ? Colors.green : Colors.orange,
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
