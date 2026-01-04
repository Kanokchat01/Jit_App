import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_user.dart';
import '../models/risk_level.dart';
import 'admin_user_detail_screen.dart';

class AdminUserListScreen extends StatefulWidget {
  const AdminUserListScreen({super.key});

  @override
  State<AdminUserListScreen> createState() => _AdminUserListScreenState();
}

class _AdminUserListScreenState extends State<AdminUserListScreen> {
  final _searchCtrl = TextEditingController();

  /// all | green | yellow | red
  String phqFilter = 'all';
  String deepFilter = 'all';

  String get _q => _searchCtrl.text.trim().toLowerCase();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ✅ ดึง users แบบ realtime (ไม่ orderBy เพื่อลดปัญหา index)
    final stream = FirebaseFirestore.instance.collection('users').snapshots();

    return SafeArea(
      child: Column(
        children: [
          _header(),
          _searchBar(),
          _filters(),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: stream,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snap.hasError) {
                  return Center(
                    child: Text(
                      'โหลดรายชื่อผู้ป่วยไม่สำเร็จ\n${snap.error}',
                      textAlign: TextAlign.center,
                    ),
                  );
                }

                final docs = snap.data?.docs ?? [];
                if (docs.isEmpty) {
                  return const Center(child: Text('ยังไม่มีผู้ใช้ในระบบ'));
                }

                // ✅ map -> AppUser
                final allUsers = docs.map((d) {
                  final data = (d.data() as Map<String, dynamic>?) ?? {};
                  return AppUser.fromMap(d.id, data);
                }).toList();

                // ✅ เอาเฉพาะ role patient (กัน admin ปน)
                final patients = allUsers.where((u) {
                  final roleName = u.role.name.toLowerCase();
                  return roleName == 'patient';
                }).toList();

                // ✅ Search (ชื่อ/เบอร์ ถ้ามี) + filter risk
                final filtered = patients.where((u) {
                  final name = (u.name).toLowerCase();
                  final phone = (u.phone ?? '').toLowerCase();

                  final phq = (u.phq9RiskLevel ?? '').toLowerCase();
                  final deep = (u.deepRiskLevel ?? '').toLowerCase();

                  final matchSearch = _q.isEmpty ||
                      name.contains(_q) ||
                      phone.contains(_q) ||
                      u.uid.toLowerCase().contains(_q);

                  final matchPhq = (phqFilter == 'all') || phq == phqFilter;
                  final matchDeep = (deepFilter == 'all') || deep == deepFilter;

                  return matchSearch && matchPhq && matchDeep;
                }).toList();

                // ✅ sort ให้ดูง่าย (ชื่อ)
                filtered.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

                if (filtered.isEmpty) {
                  return const Center(child: Text('ไม่พบผู้ป่วยตามเงื่อนไข'));
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                  itemCount: filtered.length,
                  itemBuilder: (context, i) {
                    final u = filtered[i];
                    final phqRisk = riskFromString(u.phq9RiskLevel);
                    final deepRisk = riskFromString(u.deepRiskLevel);

                    final leadingColor = phqRisk?.color ?? Colors.blueGrey;
                    final leadingIcon = phqRisk?.icon ?? Icons.person;

                    final subtitle = _buildSubtitle(u, phqRisk, deepRisk);

                    return Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: leadingColor.withOpacity(0.16),
                          child: Icon(leadingIcon, color: leadingColor),
                        ),
                        title: Text(
                          u.name,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: subtitle,
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AdminUserDetailScreen(user: u),
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

  // ---------- UI parts ----------

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Row(
        children: const [
          Icon(Icons.people, size: 22),
          SizedBox(width: 8),
          Text(
            'รายชื่อผู้ป่วย',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }

  Widget _searchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
      child: TextField(
        controller: _searchCtrl,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          hintText: 'ค้นหา: ชื่อ / เบอร์ / UID',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _q.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchCtrl.clear();
                    setState(() {});
                  },
                ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }

  Widget _filters() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Filter PHQ-9', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _chip('ทั้งหมด', 'all', phqFilter, (v) => setState(() => phqFilter = v)),
              _chip('เขียว', 'green', phqFilter, (v) => setState(() => phqFilter = v)),
              _chip('เหลือง', 'yellow', phqFilter, (v) => setState(() => phqFilter = v)),
              _chip('แดง', 'red', phqFilter, (v) => setState(() => phqFilter = v)),
            ],
          ),
          const SizedBox(height: 10),
          const Text('Filter Deep', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _chip('ทั้งหมด', 'all', deepFilter, (v) => setState(() => deepFilter = v)),
              _chip('เขียว', 'green', deepFilter, (v) => setState(() => deepFilter = v)),
              _chip('เหลือง', 'yellow', deepFilter, (v) => setState(() => deepFilter = v)),
              _chip('แดง', 'red', deepFilter, (v) => setState(() => deepFilter = v)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, String value, String current, void Function(String) onPick) {
    final selected = current == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onPick(value),
    );
  }

  Widget _buildSubtitle(AppUser u, RiskLevel? phqRisk, RiskLevel? deepRisk) {
    final phqText = phqRisk == null ? 'PHQ-9: -' : 'PHQ-9: ${phqRisk.label}';
    final deepText = (u.hasCompletedDeepAssessment)
        ? (deepRisk == null ? 'Deep: -' : 'Deep: ${deepRisk.label}')
        : 'Deep: ยังไม่ทำ';

    final phone = (u.phone ?? '').trim();
    final phoneText = phone.isEmpty ? '' : ' • $phone';

    return Text('$phqText  |  $deepText$phoneText');
  }
}
