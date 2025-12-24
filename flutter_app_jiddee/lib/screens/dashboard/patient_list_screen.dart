import 'package:flutter/material.dart';

import '../../services/firestore_service.dart';
import '../../models/app_user.dart';
import 'patient_detail_screen.dart';

class PatientListScreen extends StatefulWidget {
  const PatientListScreen({super.key});

  @override
  State<PatientListScreen> createState() => _PatientListScreenState();
}

class _PatientListScreenState extends State<PatientListScreen> {
  String filter = 'all'; // all/green/yellow/red

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
              if (filter != 'all') {
                patients = patients
                    .where((p) => (p.lastRiskLevel ?? '') == filter)
                    .toList();
              }

              if (patients.isEmpty) {
                return const Center(child: Text('No patients'));
              }

              return ListView.separated(
                itemCount: patients.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final p = patients[i];
                  final risk = (p.lastRiskLevel ?? '-').toUpperCase();
                  return ListTile(
                    leading: CircleAvatar(
                      child: Text(
                        p.name.isEmpty ? '?' : p.name[0].toUpperCase(),
                      ),
                    ),
                    title: Text(p.name),
                    subtitle: Text('Risk: $risk'),
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
        children: [
          chip('all', 'All'),
          chip('red', 'Red'),
          chip('yellow', 'Yellow'),
          chip('green', 'Green'),
        ],
      ),
    );
  }
}
