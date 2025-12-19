import 'package:flutter/material.dart';
import '../../models/app_user.dart';

class PatientHome extends StatelessWidget {
  final AppUser user;
  const PatientHome({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('สวัสดี, ${user.name}', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text('สถานะล่าสุด: ${user.lastRiskLevel ?? "-"}'),
          const SizedBox(height: 16),
          const Text('เมนูแนะนำ'),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.assignment),
              title: const Text('ทำแบบประเมิน PHQ-9'),
              subtitle: const Text('ใช้เวลา ~2-3 นาที'),
              onTap: () {
                // ใน PatientShell มีแท็บ PHQ-9 อยู่แล้ว
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('ไปที่แท็บ PHQ-9 ด้านล่างได้เลย')),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
