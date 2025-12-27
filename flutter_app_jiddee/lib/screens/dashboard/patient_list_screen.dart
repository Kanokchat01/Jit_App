import 'package:flutter/material.dart';

import '../../services/firestore_service.dart';
import '../../models/app_user.dart';
import '../../models/risk_level.dart';
import 'patient_detail_screen.dart';

class PatientListScreen extends StatefulWidget {
  const PatientListScreen({super.key});

  @override
  State<PatientListScreen> createState() => _PatientListScreenState();
}

class _PatientListScreenState extends State<PatientListScreen> {
  /// all | green | yellow | red
  String filter = 'all';

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _filterBar(),
        Expanded(
          child: StreamBuilder<List<AppUser>>(
            stream: FirestoreService().watchPatientsForDashboard(),
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              var patients = snap.data!;

              // =========================
              // Filter by PHQ-9 risk
              // =========================
              if (filter != 'all') {
                patients = patients.where((p) {
                  final risk = riskFromString(p.phq9RiskLevel);
                  return risk != null && riskToString(risk) == filter;
                }).toList();
              }

              if (patients.isEmpty) {
                return const Center(child: Text('No patients'));
              }

              return ListView.separated(
                itemCount: patients.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final p = patients[i];
                  final risk = riskFromString(p.phq9RiskLevel);

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor:
                          risk?.color.withOpacity(0.15) ?? Colors.grey.shade300,
                      child: Text(
                        p.name.isEmpty ? '?' : p.name[0].toUpperCase(),
                        style: TextStyle(
                          color: risk?.color ?? Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(p.name),
                    subtitle: Text(
                      risk != null
                          ? 'PHQ-9: ${risk.label}'
                          : 'PHQ-9: ยังไม่ได้ทำ',
                      style: TextStyle(color: risk?.color),
                    ),
                    trailing: risk != null
                        ? Icon(risk.icon, color: risk.color)
                        : const Icon(Icons.warning, color: Colors.orange),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PatientDetailScreen(patient: p),
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

  Widget _filterBar() {
    Widget chip(String key, String label) {
      return ChoiceChip(
        label: Text(label),
        selected: filter == key,
        onSelected: (_) => setState(() => filter = key),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Wrap(
        spacing: 8,
        children: const [
          // labels คงเดิม แต่ filter จะ map ไป phq9RiskLevel
        ],
      ),
    );
  }
}
