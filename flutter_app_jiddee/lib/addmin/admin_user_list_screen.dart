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
    final cs = Theme.of(context).colorScheme;

    // ✅ ดึง users แบบ realtime (ไม่ orderBy เพื่อลดปัญหา index)
    final stream = FirebaseFirestore.instance.collection('users').snapshots();

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              cs.primary.withOpacity(0.08),
              cs.secondary.withOpacity(0.10),
              Colors.white,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _headerCard(context),
              ),
              const SizedBox(height: 12),

              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: stream,
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return Center(
                        child: CircularProgressIndicator(color: cs.primary),
                      );
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
                    filtered.sort(
                      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
                    );

                    if (filtered.isEmpty) {
                      return const Center(child: Text('ไม่พบผู้ป่วยตามเงื่อนไข'));
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        final u = filtered[i];
                        final phqRisk = riskFromString(u.phq9RiskLevel);
                        final deepRisk = riskFromString(u.deepRiskLevel);

                        final leadingColor = phqRisk?.color ?? Colors.blueGrey;
                        final leadingIcon = phqRisk?.icon ?? Icons.person;

                        return InkWell(
                          borderRadius: BorderRadius.circular(22),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AdminUserDetailScreen(user: u),
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.94),
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(color: Colors.black.withOpacity(0.05)),
                              boxShadow: [
                                BoxShadow(
                                  blurRadius: 18,
                                  offset: const Offset(0, 10),
                                  color: Colors.black.withOpacity(0.06),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 22,
                                  backgroundColor: leadingColor.withOpacity(0.16),
                                  child: Icon(leadingIcon, color: leadingColor),
                                ),
                                const SizedBox(width: 12),

                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        u.name.isEmpty ? '(ไม่มีชื่อ)' : u.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 15,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 8),

                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: [
                                          _pillRisk(
                                            label: 'PHQ-9',
                                            risk: phqRisk,
                                            fallbackText: '-',
                                            cs: cs,
                                          ),
                                          _pillRisk(
                                            label: 'Deep',
                                            risk: deepRisk,
                                            fallbackText: u.hasCompletedDeepAssessment ? '-' : 'ยังไม่ทำ',
                                            cs: cs,
                                          ),
                                          if ((u.phone ?? '').trim().isNotEmpty)
                                            _pill(
                                              text: u.phone!.trim(),
                                              bg: Colors.black.withOpacity(0.06),
                                              fg: Colors.black.withOpacity(0.70),
                                              icon: Icons.phone_outlined,
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(width: 8),
                                Icon(Icons.chevron_right, color: Colors.black.withOpacity(0.35)),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------- UI parts ----------

  Widget _headerCard(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            blurRadius: 20,
            offset: const Offset(0, 10),
            color: Colors.black.withOpacity(0.06),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // title
          Row(
            children: const [
              Icon(Icons.people_alt_outlined),
              SizedBox(width: 8),
              Text(
                'รายชื่อผู้ป่วย',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // search
          TextField(
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
              filled: true,
              fillColor: Colors.black.withOpacity(0.03),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.black.withOpacity(0.06)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.black.withOpacity(0.06)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: cs.primary.withOpacity(0.55)),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
          const SizedBox(height: 14),

          // filters
          _filters(context),
        ],
      ),
    );
  }

  Widget _filters(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Filter PHQ-9',
          style: TextStyle(fontWeight: FontWeight.w900, color: Colors.black.withOpacity(0.75)),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _chip('ทั้งหมด', 'all', phqFilter, (v) => setState(() => phqFilter = v)),
            _chip('เขียว', 'green', phqFilter, (v) => setState(() => phqFilter = v), color: Colors.green),
            _chip('เหลือง', 'yellow', phqFilter, (v) => setState(() => phqFilter = v), color: Colors.orange),
            _chip('แดง', 'red', phqFilter, (v) => setState(() => phqFilter = v), color: Colors.red),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Filter Deep',
          style: TextStyle(fontWeight: FontWeight.w900, color: Colors.black.withOpacity(0.75)),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _chip('ทั้งหมด', 'all', deepFilter, (v) => setState(() => deepFilter = v)),
            _chip('เขียว', 'green', deepFilter, (v) => setState(() => deepFilter = v), color: Colors.green),
            _chip('เหลือง', 'yellow', deepFilter, (v) => setState(() => deepFilter = v), color: Colors.orange),
            _chip('แดง', 'red', deepFilter, (v) => setState(() => deepFilter = v), color: Colors.red),
          ],
        ),
      ],
    );
  }

  Widget _chip(
    String label,
    String value,
    String current,
    void Function(String) onPick, {
    Color? color,
  }) {
    final cs = Theme.of(context).colorScheme;
    final selected = current == value;
    final c = color ?? cs.primary;

    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onPick(value),
      labelStyle: TextStyle(
        fontWeight: FontWeight.w800,
        color: selected ? c : Colors.black.withOpacity(0.70),
      ),
      selectedColor: c.withOpacity(0.14),
      backgroundColor: Colors.white,
      side: BorderSide(
        color: selected ? c.withOpacity(0.40) : Colors.black.withOpacity(0.12),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    );
  }

  Widget _pillRisk({
    required String label,
    required RiskLevel? risk,
    required String fallbackText,
    required ColorScheme cs,
  }) {
    if (risk == null) {
      return _pill(
        text: '$label: $fallbackText',
        bg: Colors.black.withOpacity(0.06),
        fg: Colors.black.withOpacity(0.70),
        icon: Icons.remove_circle_outline,
      );
    }
    return _pill(
      text: '$label: ${risk.label}',
      bg: risk.color.withOpacity(0.14),
      fg: risk.color,
      icon: risk.icon,
    );
  }

  Widget _pill({
    required String text,
    required Color bg,
    required Color fg,
    IconData? icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: fg.withOpacity(0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: 6),
          ],
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}