import 'package:flutter/material.dart';
import '../../models/app_user.dart';

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
                // ❗ ไม่ต้อง push หน้า
                // RoleGate จะพาไป PHQ-9 เอง
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
              leading: const Icon(Icons.assignment_turned_in),
              title: const Text('แบบสอบถามเชิงลึก'),
              subtitle: Text(
                !needDeepAssessment
                    ? 'ไม่จำเป็นต้องทำ'
                    : hasDeepAssessment
                    ? 'ทำแบบสอบถามเชิงลึกแล้ว'
                    : 'ยังไม่ได้ทำแบบสอบถามนี้',
              ),
              trailing: Icon(
                !needDeepAssessment
                    ? Icons.remove_circle_outline
                    : hasDeepAssessment
                    ? Icons.check_circle
                    : Icons.warning,
                color: !needDeepAssessment
                    ? Colors.grey
                    : hasDeepAssessment
                    ? Colors.green
                    : Colors.orange,
              ),
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
              subtitle: Text('MVP: ไปที่แท็บ Patients เพื่อดูรายชื่อผู้ป่วย'),
            ),
          ),
        ],
      ),
    );
  }
}
