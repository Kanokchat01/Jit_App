import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../../models/risk_level.dart';

class PatientDetailScreen extends StatelessWidget {
  final AppUser patient;
  const PatientDetailScreen({super.key, required this.patient});

  @override
  Widget build(BuildContext context) {
    final RiskLevel? phq9Risk = riskFromString(patient.phq9RiskLevel);
    final RiskLevel? deepRisk = riskFromString(patient.deepRiskLevel);

    return Scaffold(
      appBar: AppBar(title: const Text('Patient Detail')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// =========================
            /// Basic Info
            /// =========================
            Text(
              patient.name,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text('UID: ${patient.uid}'),

            const SizedBox(height: 16),

            /// =========================
            /// PHQ-9
            /// =========================
            Row(
              children: [
                const Text(
                  'PHQ-9: ',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                if (phq9Risk != null) ...[
                  Icon(phq9Risk.icon, color: phq9Risk.color),
                  const SizedBox(width: 6),
                  Text(phq9Risk.label, style: TextStyle(color: phq9Risk.color)),
                ] else
                  const Text('ยังไม่ได้ทำ'),
              ],
            ),

            const SizedBox(height: 8),

            /// =========================
            /// Deep Assessment
            /// =========================
            Row(
              children: [
                const Text(
                  'Deep Assessment: ',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                if (deepRisk != null) ...[
                  Icon(deepRisk.icon, color: deepRisk.color),
                  const SizedBox(width: 6),
                  Text(deepRisk.label, style: TextStyle(color: deepRisk.color)),
                ] else
                  const Text('ยังไม่ได้ทำ'),
              ],
            ),

            const SizedBox(height: 24),

            const Text(
              'MVP: หน้านี้ยังไม่ดึงประวัติผลประเมิน\n'
              'สามารถต่อยอดเป็น timeline หรือ chart ได้',
            ),
          ],
        ),
      ),
    );
  }
}
