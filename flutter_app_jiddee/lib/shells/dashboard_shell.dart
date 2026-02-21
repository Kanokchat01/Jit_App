import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/app_user.dart';
import '../gates/auth_gate.dart';

import '../screens/admin/admin_dashboard_screen.dart';
import '../screens/admin/admin_appointment_queue_screen.dart';
import '../addmin/admin_user_list_screen.dart'; // ใช้ path เดิมของคุณ
import '../screens/admin/admin_news_screen.dart'; // ✅ เพิ่ม

class DashboardShell extends StatefulWidget {
  final AppUser user;
  const DashboardShell({super.key, required this.user});

  @override
  State<DashboardShell> createState() => _DashboardShellState();
}

class _DashboardShellState extends State<DashboardShell> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    // ❌ เอา const ออกเพื่อกัน error
    final pages = [
      const AdminDashboardScreen(),
      const AdminUserListScreen(),
      const AdminAppointmentQueueScreen(),
      const AdminNewsScreen(), // ✅ เพิ่มหน้า News
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin • JitDee'),
        actions: [
          IconButton(
            tooltip: 'ออกจากระบบ',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('ออกจากระบบ'),
                  content: const Text('คุณต้องการออกจากระบบหรือไม่'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('ยกเลิก'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('ออกจากระบบ'),
                    ),
                  ],
                ),
              );

              if (ok != true) return;

              await FirebaseAuth.instance.signOut();
              if (!context.mounted) return;

              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const AuthGate()),
                (route) => false,
              );
            },
          ),
        ],
      ),

      body: pages[index],

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: index,
        onTap: (i) => setState(() => index = i),
        type: BottomNavigationBarType.fixed, // กัน label หาย
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: 'ผู้ป่วย'),
          BottomNavigationBarItem(
            icon: Icon(Icons.event_note),
            label: 'คิวนัด',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.article),
            label: 'News', // ✅ เพิ่มปุ่ม
          ),
        ],
      ),
    );
  }
}
