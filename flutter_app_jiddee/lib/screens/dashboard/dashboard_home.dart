import 'package:flutter/material.dart';
import '../../models/app_user.dart';

class DashboardHome extends StatelessWidget {
  final AppUser user;
  const DashboardHome({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Welcome, ${user.name}', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text('Role: ${user.role.name}'),
          const SizedBox(height: 16),
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
