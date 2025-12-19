import 'package:flutter/material.dart';
import '../../models/phq9_result.dart';

class ResultScreen extends StatelessWidget {
  final Phq9Result result;
  const ResultScreen({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final risk = result.riskLevel.toUpperCase();

    return Scaffold(
      appBar: AppBar(title: const Text('Result')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('PHQ-9 Score: ${result.scoreTotal}', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text('Severity: ${result.severity}'),
            const SizedBox(height: 8),
            Text('Risk: $risk', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            Text(_advice(result.riskLevel)),
          ],
        ),
      ),
    );
  }

  String _advice(String riskLevel) {
    switch (riskLevel) {
      case 'red':
        return 'ควรติดต่อผู้เชี่ยวชาญ/หน่วยงานทันที หรือขอนัดหมายด่วน';
      case 'yellow':
        return 'แนะนำติดตามอาการ ทำแบบประเมินซ้ำ และพิจารณาปรึกษาผู้เชี่ยวชาญ';
      default:
        return 'ระดับทั่วไป แนะนำดูแลสุขภาพจิตและติดตามเป็นระยะ';
    }
  }
}
