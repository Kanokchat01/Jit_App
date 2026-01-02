import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../../models/risk_level.dart';
import '../../services/firestore_service.dart';
import 'admin_user_detail_screen.dart';

class AdminUserListScreen extends StatefulWidget {
  const AdminUserListScreen({super.key});

  @override
  State<AdminUserListScreen> createState() => _AdminUserListScreenState();
}

class _AdminUserListScreenState extends State<AdminUserListScreen> {
  /// all | green | yellow | red
  String filter = 'all';

  final _fs = FirestoreService();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _filterBar(),
        Expanded(
          child: StreamBuilder<List<AppUser>>(
            stream: _fs.watchPatientsForDashboard(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snap.hasError) {
                return const Center(
                  child: Text('เกิดข้อผิดพลาดในการโหลดรายชื่อผู้ป่วย'),
                );
              }

              final users = snap.data ?? [];

              // =========================
              // Filter by PHQ-9 risk
              // =========================
              final filtered = filter == 'all'
                  ? users
                  : users.where((u) {
                      final risk = riskFromString(u.phq9RiskLevel);
                      return risk != null &&
                          riskToString(risk) == filter;
                    }).toList();

              if (filtered.isEmpty) {
                return const Center(
                  child: Text('ไม่พบผู้ป่วยในเงื่อนไขนี้'),
                );
              }

              return ListView.separated(
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const Divider(height: 0),
                itemBuilder: (context, i) {
                  final user = filtered[i];
                  final risk = riskFromString(user.phq9RiskLevel);

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor:
                          risk?.color ?? Colors.blueGrey,
                      child: Icon(
                        risk?.icon ?? Icons.person,
                        color: Colors.white,
                      ),
                    ),
                    title: Text(
                      user.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    subtitle: Text(
                      risk == null
                          ? 'ยังไม่มีผล PHQ-9'
                          : 'PHQ-9: ${risk.label}',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              AdminUserDetailScreen(user: user),
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // =========================
  // Filter Bar
  // =========================
  Widget _filterBar() {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Wrap(
        spacing: 8,
        alignment: WrapAlignment.center,
        children: [
          _chip('ทั้งหมด', 'all'),
          _chip('เขียว', 'green'),
          _chip('เหลือง', 'yellow'),
          _chip('แดง', 'red'),
        ],
      ),
    );
  }

  Widget _chip(String label, String value) {
    final selected = filter == value;

    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) {
        setState(() => filter = value);
      },
    );
  }
}
