import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../../models/risk_level.dart';
import '../../services/firestore_service.dart';
import 'patient_detail_screen.dart';

class PatientListScreen extends StatefulWidget {
  const PatientListScreen({super.key});

  @override
  State<PatientListScreen> createState() => _PatientListScreenState();
}

class _PatientListScreenState extends State<PatientListScreen> {
  /// all | green | yellow | red
  String filter = 'all';

  final _fs = FirestoreService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('รายชื่อผู้ป่วย'),
      ),
      body: Column(
        children: [
          _filterBar(),
          Expanded(
            child: StreamBuilder<List<AppUser>>(
              stream: _fs.watchPatientsForDashboard(),
              builder: (context, snap) {
                // ===== Loading =====
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                // ===== Error =====
                if (snap.hasError) {
                  return const Center(
                    child: Text(
                      'เกิดข้อผิดพลาดในการโหลดข้อมูลผู้ป่วย',
                      style: TextStyle(color: Colors.red),
                    ),
                  );
                }

                final patients = snap.data ?? [];

                // ===== Filter by PHQ-9 risk =====
                final filtered = filter == 'all'
                    ? patients
                    : patients.where((p) {
                        final risk = riskFromString(p.phq9RiskLevel);
                        return risk != null &&
                            riskToString(risk) == filter;
                      }).toList();

                if (filtered.isEmpty) {
                  return const Center(
                    child: Text('ไม่พบผู้ป่วยในเงื่อนไขนี้'),
                  );
                }

                return ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final p = filtered[index];
                    final risk = riskFromString(p.phq9RiskLevel);

                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              risk?.color ?? Colors.blueGrey,
                          child: Icon(
                            risk?.icon ?? Icons.person,
                            color: Colors.white,
                          ),
                        ),
                        title: Text(
                          p.name,
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
                                  PatientDetailScreen(user: p),
                            ),
                          );
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // =========================
  // Filter Bar
  // =========================
  Widget _filterBar() {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 6,
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
      selectedColor: Colors.blueGrey.shade200,
      onSelected: (_) {
        setState(() => filter = value);
      },
    );
  }
}
