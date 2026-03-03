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
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 6),
                      itemBuilder: (context, i) {
                        final u = filtered[i];
                        final phqRisk = riskFromString(u.phq9RiskLevel);
                        final deepRisk = riskFromString(u.deepRiskLevel);

                        final leadingColor = phqRisk?.color ?? Colors.blueGrey;
                        final leadingIcon = phqRisk?.icon ?? Icons.person;

                        return InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AdminUserDetailScreen(user: u),
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.94),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.black.withOpacity(0.05)),
                              boxShadow: [
                                BoxShadow(
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                  color: Colors.black.withOpacity(0.04),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                // compact avatar with risk color
                                CircleAvatar(
                                  radius: 18,
                                  backgroundColor: leadingColor.withOpacity(0.16),
                                  child: Icon(leadingIcon, color: leadingColor, size: 20),
                                ),
                                const SizedBox(width: 10),

                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        u.name.isEmpty ? '(ไม่มีชื่อ)' : u.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 14,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),

                                      Row(
                                        children: [
                                          Flexible(
                                            child: _pillRisk(
                                              label: 'PHQ-9',
                                              risk: phqRisk,
                                              fallbackText: '-',
                                              cs: cs,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          Flexible(
                                            child: _pillRisk(
                                              label: 'Deep',
                                              risk: deepRisk,
                                              fallbackText: '-',
                                              cs: cs,
                                            ),
                                          ),
                                        ],
                                      ),
                                      if ((u.phone ?? '').trim().isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        _pill(
                                          text: u.phone!.trim(),
                                          bg: Colors.black.withOpacity(0.04),
                                          fg: Colors.black.withOpacity(0.55),
                                          icon: Icons.phone_outlined,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),

                                const SizedBox(width: 4),
                                Icon(Icons.chevron_right, size: 20, color: Colors.black.withOpacity(0.30)),
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
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            blurRadius: 16,
            offset: const Offset(0, 8),
            color: Colors.black.withOpacity(0.05),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // search (compact)
          SizedBox(
            height: 42,
            child: TextField(
              controller: _searchCtrl,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'ค้นหา: ชื่อ / เบอร์ / UID',
                hintStyle: const TextStyle(fontSize: 13),
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _q.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() {});
                        },
                      ),
                filled: true,
                fillColor: Colors.black.withOpacity(0.03),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.black.withOpacity(0.06)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.black.withOpacity(0.06)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: cs.primary.withOpacity(0.55)),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // filters (compact — single row each)
          _filters(context),
        ],
      ),
    );
  }

  Widget _filters(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // PHQ-9 filter row
        Row(
          children: [
            Text(
              'PHQ-9',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 11,
                color: Colors.black.withOpacity(0.55),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _chip('ทั้งหมด', 'all', phqFilter, (v) => setState(() => phqFilter = v)),
                    const SizedBox(width: 4),
                    _chip('🟢', 'green', phqFilter, (v) => setState(() => phqFilter = v), color: Colors.green),
                    const SizedBox(width: 4),
                    _chip('🟡', 'yellow', phqFilter, (v) => setState(() => phqFilter = v), color: Colors.orange),
                    const SizedBox(width: 4),
                    _chip('🔴', 'red', phqFilter, (v) => setState(() => phqFilter = v), color: Colors.red),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        // Deep filter row
        Row(
          children: [
            Text(
              'Deep  ',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 11,
                color: Colors.black.withOpacity(0.55),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _chip('ทั้งหมด', 'all', deepFilter, (v) => setState(() => deepFilter = v)),
                    const SizedBox(width: 4),
                    _chip('🟢', 'green', deepFilter, (v) => setState(() => deepFilter = v), color: Colors.green),
                    const SizedBox(width: 4),
                    _chip('🟡', 'yellow', deepFilter, (v) => setState(() => deepFilter = v), color: Colors.orange),
                    const SizedBox(width: 4),
                    _chip('🔴', 'red', deepFilter, (v) => setState(() => deepFilter = v), color: Colors.red),
                  ],
                ),
              ),
            ),
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
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      labelStyle: TextStyle(
        fontWeight: FontWeight.w800,
        fontSize: 12,
        color: selected ? c : Colors.black.withOpacity(0.65),
      ),
      labelPadding: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
      selectedColor: c.withOpacity(0.14),
      backgroundColor: Colors.white,
      side: BorderSide(
        color: selected ? c.withOpacity(0.40) : Colors.black.withOpacity(0.10),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
    // ✅ ใช้ชื่อสั้นแทน risk.label ที่ยาวเกินไป
    final shortName = _shortRiskName(risk);
    return _pill(
      text: '$label: $shortName',
      bg: risk.color.withOpacity(0.14),
      fg: risk.color,
      icon: risk.icon,
    );
  }

  String _shortRiskName(RiskLevel risk) {
    switch (risk) {
      case RiskLevel.green:
        return 'ดี';
      case RiskLevel.yellow:
        return 'เสี่ยง';
      case RiskLevel.red:
        return 'สูง';
    }
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