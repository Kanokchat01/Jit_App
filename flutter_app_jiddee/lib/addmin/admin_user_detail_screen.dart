import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../../models/app_user.dart';

class AdminUserDetailScreen extends StatelessWidget {
  final AppUser user;
  const AdminUserDetailScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

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
              _topBar(context),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                  children: [
                    _buildPatientCard(context),

                    const SizedBox(height: 14),
                    _sectionHeader(
                      context: context,
                      title: 'การนัดแพทย์',
                      icon: Icons.calendar_month_outlined,
                    ),
                    const SizedBox(height: 10),
                    _buildAppointments(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =========================
  // Top Bar (UI only)
  // =========================
  Widget _topBar(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: Row(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.92),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.black.withOpacity(0.06)),
                boxShadow: [
                  BoxShadow(
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                    color: Colors.black.withOpacity(0.06),
                  ),
                ],
              ),
              child: Icon(Icons.arrow_back, color: Colors.black.withOpacity(0.75)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'รายละเอียดผู้ป่วย',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: Colors.black.withOpacity(0.82),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: cs.primary.withOpacity(0.10),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: cs.primary.withOpacity(0.18)),
            ),
            child: Row(
              children: [
                Icon(Icons.shield_outlined, size: 16, color: cs.primary),
                const SizedBox(width: 6),
                Text(
                  'Admin',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: cs.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =========================
  // 🎨 Dynamic Card Color (เดิม)
  // =========================

  Color _cardColor() {
    final risk = user.deepRiskLevel?.toLowerCase();

    switch (risk) {
      case 'red':
        return Colors.red.shade50;
      case 'yellow':
        return Colors.orange.shade50;
      case 'green':
        return Colors.green.shade50;
      default:
        return Colors.blue.shade50; // ยังไม่ประเมิน
    }
  }

  Color _topStripColor() {
    final risk = user.deepRiskLevel?.toLowerCase();

    switch (risk) {
      case 'red':
        return Colors.red;
      case 'yellow':
        return Colors.orange;
      case 'green':
        return Colors.green;
      default:
        return Colors.blue;
    }
  }

  // =========================
  // 🏥 Patient Card (ตกแต่งใหม่ แต่ logic เดิม)
  // =========================

  Widget _buildPatientCard(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final age = _calculateAge(user.birthDate);

    final strip = _topStripColor();
    final soft = _cardColor();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.94),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            blurRadius: 22,
            offset: const Offset(0, 12),
            color: Colors.black.withOpacity(0.06),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          children: [
            // top strip + soft background gradient inside
            Container(
              height: 10,
              color: strip,
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    soft.withOpacity(0.95),
                    Colors.white.withOpacity(0.92),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // avatar + name
                  Row(
                    children: [
                      Container(
                        width: 62,
                        height: 62,
                        decoration: BoxDecoration(
                          color: strip.withOpacity(0.14),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: strip.withOpacity(0.20)),
                        ),
                        child: Icon(Icons.person, color: strip, size: 34),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.name.isEmpty ? '(ไม่มีชื่อ)' : user.name,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              (user.email ?? '-'),
                              style: TextStyle(
                                color: Colors.black.withOpacity(0.55),
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      _riskChip(
                        label: 'Deep',
                        value: user.hasCompletedDeepAssessment ? (user.deepRiskLevel ?? '-') : 'ยังไม่ทำ',
                        color: strip,
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // quick pills
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _pill(
                        icon: Icons.phone_outlined,
                        text: (user.phone ?? '-'),
                        cs: cs,
                      ),
                      _pill(
                        icon: Icons.cake_outlined,
                        text: (user.birthDate ?? '-'),
                        cs: cs,
                      ),
                      _pill(
                        icon: Icons.badge_outlined,
                        text: age ?? '-',
                        cs: cs,
                      ),
                      _pill(
                        icon: Icons.wc_outlined,
                        text: (user.gender ?? '-'),
                        cs: cs,
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),
                  Container(
                    height: 1,
                    color: Colors.black.withOpacity(0.06),
                  ),
                  const SizedBox(height: 14),

                  // info grid (เดิมคือ Wrap infoItem)
                  _subTitle('ข้อมูลการศึกษา / โปรไฟล์'),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 14,
                    runSpacing: 10,
                    children: [
                      _infoItem('คณะ', user.faculty ?? '-'),
                      _infoItem('สาขา', user.major ?? '-'),
                      _infoItem('รหัสนักศึกษา', user.studentId ?? '-'),
                      _infoItem('ชั้นปี', user.year ?? '-'),
                    ],
                  ),

                  const SizedBox(height: 14),
                  Container(
                    height: 1,
                    color: Colors.black.withOpacity(0.06),
                  ),
                  const SizedBox(height: 14),

                  _subTitle('ผลการประเมิน'),
                  const SizedBox(height: 10),

                  _statusRow(
                    context: context,
                    label: 'PHQ-9',
                    value: user.hasCompletedPhq9 ? (user.phq9RiskLevel ?? '-') : 'ยังไม่ได้ประเมิน',
                    color: _riskColorFromValue(user.phq9RiskLevel),
                  ),
                  const SizedBox(height: 8),
                  _statusRow(
                    context: context,
                    label: 'Deep Assessment',
                    value: user.hasCompletedDeepAssessment ? (user.deepRiskLevel ?? '-') : 'ยังไม่ได้ประเมิน',
                    color: _riskColorFromValue(user.deepRiskLevel),
                  ),

                  // ✅ Emotion Detection Section
                  if (user.dominantEmotion != null && user.emotionSummaryPercent != null) ...[
                    const SizedBox(height: 14),
                    Container(
                      height: 1,
                      color: Colors.black.withOpacity(0.06),
                    ),
                    const SizedBox(height: 14),

                    _subTitle('การวิเคราะห์อารมณ์ (AI On-device)'),
                    const SizedBox(height: 10),

                    // dominant emotion card
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _emotionColor(user.dominantEmotion).withOpacity(0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _emotionColor(user.dominantEmotion).withOpacity(0.20),
                        ),
                      ),
                      child: Row(
                        children: [
                          Text(
                            _emotionEmoji(user.dominantEmotion),
                            style: const TextStyle(fontSize: 32),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'อารมณ์หลัก: ${_emotionLabel(user.dominantEmotion)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'ตรวจจับ ${user.emotionSamples ?? 0} ครั้ง • ความมั่นใจ ${((user.emotionAvgConf ?? 0) * 100).toStringAsFixed(0)}%',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.black.withOpacity(0.55),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                            decoration: BoxDecoration(
                              color: _emotionColor(user.dominantEmotion).withOpacity(0.14),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: _emotionColor(user.dominantEmotion).withOpacity(0.25),
                              ),
                            ),
                            child: Text(
                              '${((user.dominantScore ?? 0) * 100).toStringAsFixed(0)}%',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                color: _emotionColor(user.dominantEmotion),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 10),

                    // bar chart for all classes
                    ...user.emotionSummaryPercent!.entries.map((e) {
                      final pct = e.value.clamp(0.0, 100.0);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 60,
                              child: Text(
                                _emotionLabel(e.key),
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                  color: Colors.black.withOpacity(0.65),
                                ),
                              ),
                            ),
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(999),
                                child: LinearProgressIndicator(
                                  value: pct / 100,
                                  minHeight: 10,
                                  backgroundColor: Colors.black.withOpacity(0.05),
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    _emotionColor(e.key),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 40,
                              child: Text(
                                '${pct.toStringAsFixed(0)}%',
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 12,
                                  color: Colors.black.withOpacity(0.70),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _riskColorFromValue(String? v) {
    final s = (v ?? '').toLowerCase();
    switch (s) {
      case 'red':
        return Colors.red;
      case 'yellow':
        return Colors.orange;
      case 'green':
        return Colors.green;
      default:
        return Colors.blueGrey;
    }
  }

  // ✅ Emotion helpers
  Color _emotionColor(String? emotion) {
    switch (emotion?.toLowerCase()) {
      case 'happy':
        return Colors.amber.shade700;
      case 'sad':
        return Colors.blue.shade600;
      case 'angry':
        return Colors.red.shade600;
      case 'fear':
        return Colors.deepOrange.shade400;
      case 'neutral':
        return Colors.teal.shade500;
      default:
        return Colors.blueGrey;
    }
  }

  String _emotionEmoji(String? emotion) {
    switch (emotion?.toLowerCase()) {
      case 'happy':
        return '😊';
      case 'sad':
        return '😢';
      case 'angry':
        return '😠';
      case 'fear':
        return '😨';
      case 'neutral':
        return '😐';
      default:
        return '🤔';
    }
  }

  String _emotionLabel(String? emotion) {
    switch (emotion?.toLowerCase()) {
      case 'happy':
        return 'สุข';
      case 'sad':
        return 'เศร้า';
      case 'angry':
        return 'โกรธ';
      case 'fear':
        return 'กลัว';
      case 'neutral':
        return 'ปกติ';
      default:
        return emotion ?? '-';
    }
  }

  Widget _subTitle(String text) {
    return Text(
      text,
      style: TextStyle(
        fontWeight: FontWeight.w900,
        color: Colors.black.withOpacity(0.72),
      ),
    );
  }

  Widget _pill({
    required IconData icon,
    required String text,
    required ColorScheme cs,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: cs.primary.withOpacity(0.07),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cs.primary.withOpacity(0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: cs.primary),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: Colors.black.withOpacity(0.70),
            ),
          ),
        ],
      ),
    );
  }

  Widget _riskChip({
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.22)),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          fontWeight: FontWeight.w900,
          color: color,
        ),
      ),
    );
  }

  Widget _infoItem(String label, String value) {
    return SizedBox(
      width: 160,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.78),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black.withOpacity(0.05)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.black.withOpacity(0.55),
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: Colors.black.withOpacity(0.82),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusRow({
    required BuildContext context,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.78),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: color.withOpacity(0.22)),
            ),
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================
  // 📅 Appointments (ตกแต่งใหม่ แต่ logic เดิม)
  // =========================

  Widget _buildAppointments() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('appointments')
          .where('patientUid', isEqualTo: user.uid)
          .snapshots(),
      builder: (context, snap) {
        final cs = Theme.of(context).colorScheme;

        if (snap.connectionState == ConnectionState.waiting) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: CircularProgressIndicator(color: cs.primary),
            ),
          );
        }

        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.92),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.black.withOpacity(0.05)),
            ),
            child: Row(
              children: [
                Icon(Icons.event_busy, color: Colors.black.withOpacity(0.45)),
                const SizedBox(width: 10),
                Text(
                  'ยังไม่มีการนัดแพทย์',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Colors.black.withOpacity(0.65),
                  ),
                ),
              ],
            ),
          );
        }

        final items = docs.map((d) => {'id': d.id, ...d.data()}).toList();
        items.sort((a, b) => _sortDate(b).compareTo(_sortDate(a)));

        return Column(
          children: items.map((data) {
            final status = (data['status'] ?? '-').toString();
            final badge = _statusBadge(status.toLowerCase());

            DateTime? dt;
            final apptAt = data['appointmentAt'];
            if (apptAt is Timestamp) dt = apptAt.toDate();

            final dateText = dt == null ? '-' : DateFormat('dd/MM/yyyy HH:mm').format(dt);

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.94),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.black.withOpacity(0.05)),
                boxShadow: [
                  BoxShadow(
                    blurRadius: 18,
                    offset: const Offset(0, 10),
                    color: Colors.black.withOpacity(0.05),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: badge.color.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: badge.color.withOpacity(0.20)),
                    ),
                    child: Icon(badge.icon, color: badge.color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          dateText,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'สถานะ: ${badge.text}',
                          style: TextStyle(
                            color: Colors.black.withOpacity(0.60),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: badge.color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: badge.color.withOpacity(0.22)),
                    ),
                    child: Text(
                      badge.text,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: badge.color,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _sectionHeader({
    required BuildContext context,
    required String title,
    required IconData icon,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: cs.primary, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Icon(icon, size: 18, color: Colors.black.withOpacity(0.70)),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
        ),
      ],
    );
  }

  DateTime _sortDate(Map<String, dynamic> a) {
    final apptAt = a['appointmentAt'];
    if (apptAt is Timestamp) return apptAt.toDate();
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  _Badge _statusBadge(String s) {
    switch (s) {
      case 'pending':
        return _Badge('รออนุมัติ', Icons.hourglass_top, Colors.orange);
      case 'approved':
        return _Badge('อนุมัติแล้ว', Icons.check_circle, Colors.green);
      case 'rejected':
        return _Badge('ปฏิเสธ', Icons.cancel, Colors.red);
      default:
        return _Badge(s, Icons.info, Colors.blueGrey);
    }
  }

  String? _calculateAge(String? birthDate) {
    if (birthDate == null || birthDate.isEmpty) return null;
    try {
      final parsed = DateFormat('dd/MM/yyyy').parse(birthDate);
      final now = DateTime.now();
      int age = now.year - parsed.year;
      if (now.month < parsed.month || (now.month == parsed.month && now.day < parsed.day)) {
        age--;
      }
      return '$age ปี';
    } catch (_) {
      return null;
    }
  }
}

class _Badge {
  final String text;
  final IconData icon;
  final Color color;
  _Badge(this.text, this.icon, this.color);
}