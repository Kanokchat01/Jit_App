import 'package:flutter/material.dart';
import '../../models/app_user.dart';
import '../../services/firestore_service.dart';
import 'admin_user_detail_screen.dart';

class AdminUserListScreen extends StatelessWidget {
  const AdminUserListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ผู้ใช้ทั้งหมด')),
      body: StreamBuilder<List<AppUser>>(
        stream: FirestoreService().watchPatientsForDashboard(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final users = snap.data!;

          if (users.isEmpty) {
            return const Center(child: Text('ยังไม่มีผู้ใช้'));
          }

          return ListView.separated(
            itemCount: users.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final u = users[i];

              final risk = u.phq9RiskLevel ?? '-';

              return ListTile(
                leading: CircleAvatar(
                  child: Text(u.name.isEmpty ? '?' : u.name[0].toUpperCase()),
                ),
                title: Text(u.name),
                subtitle: Text('PHQ-9: $risk'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AdminUserDetailScreen(user: u),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
