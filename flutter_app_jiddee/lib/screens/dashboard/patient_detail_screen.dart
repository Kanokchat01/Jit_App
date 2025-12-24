import 'package:flutter/material.dart';
import '../../models/app_user.dart';

class PatientDetailScreen extends StatelessWidget {
  final AppUser patient;
  const PatientDetailScreen({super.key, required this.patient});

  @override
  Widget build(BuildContext context) {
    final risk = (patient.lastRiskLevel ?? '-').toUpperCase();

    return Scaffold(
      appBar: AppBar(title: const Text('Patient Detail')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              patient.name,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text('UID: ${patient.uid}'),
            const SizedBox(height: 8),
            Text('Last risk: $risk'),
            const SizedBox(height: 16),
            const Text(
              'MVP: หน้านี้ยังไม่ดึงประวัติผลประเมิน (จะทำต่อเป็น timeline ได้)',
            ),
          ],
        ),
      ),
    );
  }
}
