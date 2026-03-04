import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../models/app_user.dart';
import '../../models/risk_level.dart';
import '../../gates/auth_gate.dart';

import '../patient/phq9_screen.dart';
import '../patient/appointment_screen.dart';
import '../patient/edit_profile_screen.dart';
import '../deep_assessment/deep_assessment_screen.dart';
import '../patient/user_news_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DashboardHome extends StatelessWidget {
  final AppUser user;
  const DashboardHome({super.key, required this.user});

  // ✅ เปลี่ยนได้ตามตำแหน่งที่หนูใส่ asset
  static const String _mascotAsset = 'assets/images/jitdee_mascot.png';

  bool get _profileIncomplete {
    return user.name.trim().isEmpty ||
        (user.phone ?? '').trim().isEmpty ||
        (user.birthDate ?? '').trim().isEmpty ||
        (user.faculty ?? '').trim().isEmpty ||
        (user.major ?? '').trim().isEmpty ||
        (user.studentId ?? '').trim().isEmpty ||
        (user.year ?? '').trim().isEmpty ||
        (user.gender ?? '').trim().isEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final phq = (user.phq9RiskLevel ?? '').toLowerCase();
    final deep = (user.deepRiskLevel ?? '').toLowerCase();

    final hasPhq9 = user.hasCompletedPhq9;
    final RiskLevel? phq9Risk = riskFromString(user.phq9RiskLevel);

    final needDeep = hasPhq9 && (phq == 'yellow' || phq == 'red');
    final deepDone = user.hasCompletedDeepAssessment;
    final deepNotDone = needDeep && !deepDone;

    final deepIsRed = deepDone && deep == 'red';
    final emotionIsWarning = deepDone && user.happinessLevel == 'warning';
    final canRequestAppointment = deepIsRed || emotionIsWarning;
    final deepIsYellow = deepDone && deep == 'yellow';

    late final String deepText;
    late final Color deepColor;
    late final IconData deepIcon;

    if (!needDeep) {
      deepText = 'ไม่จำเป็นต้องทำ (PHQ-9 ระดับสีเขียว)';
      deepColor = Colors.grey;
      deepIcon = Icons.remove_circle_outline;
    } else if (!deepDone) {
      deepText = 'ยังไม่ได้ทำแบบสอบถามเชิงลึก (TMHI-55)';
      deepColor = Colors.orange;
      deepIcon = Icons.warning;
    } else {
      final deepRisk = riskFromString(user.deepRiskLevel);
      if (deepRisk == null) {
        deepText = 'ทำแล้ว';
        deepColor = Colors.blueGrey;
        deepIcon = Icons.info_outline;
      } else {
        deepText = 'ผลเชิงลึก: ${deepRisk.label}';
        deepColor = deepRisk.color;
        deepIcon = deepRisk.icon;
      }
    }

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              cs.primary.withOpacity(0.10),
              cs.secondary.withOpacity(0.12),
              const Color(0xFFFFFFFF),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _topBar(context),
                const SizedBox(height: 16),

                if (_profileIncomplete) _profileWarning(context),

                const SizedBox(height: 14),

                // ✅ เปลี่ยนจาก _heroCard เป็น hero header แบบมีน้อง
                _heroHeader(context),

                const SizedBox(height: 24),
                _sectionTitle(context, "เมนูหลัก"),
                const SizedBox(height: 12),

                _newsHighlight(context),

                const SizedBox(height: 18),
                _quickActions(context, canRequestAppointment, deepDone),

                if (deepNotDone || deepIsYellow) ...[
                  const SizedBox(height: 18),
                  _deepAlert(context),
                ],

                const SizedBox(height: 26),
                _sectionTitle(context, "สถานะล่าสุด"),
                const SizedBox(height: 12),

                _statusCard(
                  context: context,
                  title: "PHQ-9",
                  subtitle: hasPhq9 && phq9Risk != null
                      ? "ทำแล้ว • ${phq9Risk.label}"
                      : "ยังไม่ได้ทำแบบประเมิน",
                  icon: hasPhq9 && phq9Risk != null ? phq9Risk.icon : Icons.warning,
                  color: hasPhq9 && phq9Risk != null ? phq9Risk.color : Colors.orange,
                ),

                const SizedBox(height: 12),

                _statusCard(
                  context: context,
                  title: "TMHI-55",
                  subtitle: deepText,
                  icon: deepIcon,
                  color: deepColor,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _topBar(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Row(
      children: [
        Text(
          "JitDee",
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: Colors.black.withOpacity(0.82),
          ),
        ),
        const Spacer(),

        /// 🔔 Notification Bell
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('notifications')
              .where('uid', isEqualTo: user.uid)
              .where('read', isEqualTo: false)
              .snapshots(),
          builder: (context, snapshot) {
            final hasUnread = snapshot.hasData && snapshot.data!.docs.isNotEmpty;

            return Stack(
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications_outlined),
                  onPressed: () {
                    _showNotifications(context);
                  },
                ),
                if (hasUnread)
                  Positioned(
                    right: 10,
                    top: 10,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: cs.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),

        /// ⚙ Settings
        Stack(
          children: [
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EditProfileScreen(user: user),
                  ),
                );
              },
            ),
            if (_profileIncomplete)
              Positioned(
                right: 10,
                top: 10,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFF6B6B),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),

        IconButton(
          icon: const Icon(Icons.logout),
          onPressed: () async {
            await FirebaseAuth.instance.signOut();
            if (!context.mounted) return;
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const AuthGate()),
              (route) => false,
            );
          },
        ),
      ],
    );
  }

  Widget _profileWarning(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFF6B6B).withOpacity(0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFF6B6B).withOpacity(0.18)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: cs.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.info_outline, color: cs.primary),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              "กรุณากรอกข้อมูลของท่านให้ครบ",
              style: TextStyle(
                color: Color(0xFFE24A4A),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ✅ HERO HEADER ใส่น้อง + โทนคลื่น/ทะเล (ตกแต่งล้วน)
  Widget _heroHeader(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final risk = riskFromString(user.phq9RiskLevel);
    final badgeColor = risk?.color ?? cs.primary;
    final badgeText = risk == null ? "ยังไม่มีผลประเมิน" : "PHQ-9 : ${risk.label}";

    return Container(
      height: 220,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            cs.secondary.withOpacity(0.35),
            cs.primary.withOpacity(0.18),
            Colors.white.withOpacity(0.95),
          ],
        ),
        boxShadow: [
          BoxShadow(
            blurRadius: 22,
            color: Colors.black.withOpacity(.06),
            offset: const Offset(0, 12),
          ),
        ],
        border: Border.all(color: Colors.black.withOpacity(0.04)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          children: [
            // วงกลมตกแต่งมุมบนซ้าย (คล้ายตัวอย่าง)
            Positioned(
              left: -60,
              top: -60,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: cs.secondary.withOpacity(0.20),
                ),
              ),
            ),
                // 🌫 เงาวงรีลอยนุ่ม ๆ
              Positioned(
                right: 48,     // ขยับให้ตรงกลางท้องน้อง
                bottom: 48,    // ยกขึ้นนิดนึง
                child: Container(
                  width: 110,  // กว้างขึ้นหน่อย
                  height: 16,  // บางลง
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.20),
                        blurRadius: 30,
                        spreadRadius: 6,
                      ),
                    ],
                  ),
                ),
              ),

            // คลื่นแบบนิ่ม ๆ (เป็นแถบโค้ง)
            Positioned(
              left: -40,
              right: -40,
              top: 96,
              child: Container(
                height: 160,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      cs.primary.withOpacity(0.08),
                      cs.primary.withOpacity(0.02),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            // น้อง Jitdee
            Positioned(
              right: 10,
              top: 10,
              child: Opacity(
                opacity: 0.95,
                child: Image.asset(
                  _mascotAsset,
                  width: 150,
                  height: 150,
                  fit: BoxFit.contain,
                ),
              ),
            ),

            // ข้อความ + badge
            Positioned(
              left: 18,
              right: 140,
              bottom: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Welcome,",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Colors.black.withOpacity(0.80),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user.name.trim().isEmpty ? "เพื่อนของเรา" : user.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Colors.black.withOpacity(0.86),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: badgeColor.withOpacity(.14),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: badgeColor.withOpacity(0.18)),
                    ),
                    child: Text(
                      badgeText,
                      style: TextStyle(
                        color: badgeColor,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _newsHighlight(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(26),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const UserNewsScreen()),
        );
      },
      child: Container(
        height: 140,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          color: Colors.white.withOpacity(0.92),
          boxShadow: [
            BoxShadow(
              blurRadius: 22,
              color: Colors.black.withOpacity(.06),
              offset: const Offset(0, 12),
            ),
          ],
          border: Border.all(color: Colors.black.withOpacity(0.04)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: cs.secondary.withOpacity(0.35),
              child: Icon(Icons.article, color: cs.primary),
            ),
            const SizedBox(width: 14),

            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('news')
                    .orderBy('createdAt', descending: true)
                    .limit(1)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Text(
                      "กำลังโหลดข่าวล่าสุด...",
                      style: TextStyle(fontSize: 13),
                    );
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Text(
                      "ยังไม่มีข่าว",
                      style: TextStyle(fontSize: 13),
                    );
                  }

                  final data = snapshot.data!.docs.first.data() as Map<String, dynamic>;
                  final String title = data['title'] ?? "ไม่มีหัวข้อข่าว";
                  final String content = data['content'] ?? "";

                  return Stack(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Expanded(
                            child: Text(
                              content,
                              maxLines: 3,
                              overflow: TextOverflow.clip,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.black.withOpacity(.60),
                              ),
                            ),
                          ),
                        ],
                      ),
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          height: 28,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.white.withOpacity(0),
                                Colors.white.withOpacity(0.92),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),

            const SizedBox(width: 8),
            Icon(Icons.chevron_right, color: Colors.black.withOpacity(0.45)),
          ],
        ),
      ),
    );
  }

  Widget _quickActions(BuildContext context, bool canRequestAppointment, bool deepDone) {
    return Row(
      children: [
        Expanded(
          child: _actionCard(
            context: context,
            icon: Icons.assignment,
            title: "ทำแบบประเมิน",
            subtitle: "PHQ-9",
            onTap: () {
              if (_profileIncomplete) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("กรุณากรอกข้อมูลให้ครบก่อนทำแบบประเมิน"),
                  ),
                );
                return;
              }
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => Phq9Screen(user: user, fromHome: true),
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _actionCard(
            context: context,
            icon: Icons.calendar_month,
            title: "นัดแพทย์",
            subtitle: canRequestAppointment
                ? "ส่งคำขอ"
                : deepDone
                    ? "ผลยังไม่ถึงเกณฑ์นัดหมอ"
                    : "ทำ Deep ก่อน",
            onTap: () {
              if (!canRequestAppointment) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      deepDone
                          ? "ผลประเมินยังไม่ถึงเกณฑ์ (ต้องเป็นสีแดง หรือ คะแนนอารมณ์อยู่ในระดับเสี่ยง)"
                          : "ต้องทำแบบสอบถามเชิงลึก (TMHI-55) ก่อน",
                    ),
                  ),
                );
                return;
              }
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AppointmentScreen(user: user),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _actionCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final cs = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: Colors.white.withOpacity(0.92),
          boxShadow: [
            BoxShadow(
              blurRadius: 22,
              color: Colors.black.withOpacity(.06),
              offset: const Offset(0, 12),
            ),
          ],
          border: Border.all(color: Colors.black.withOpacity(0.04)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: cs.secondary.withOpacity(0.35),
              child: Icon(icon, color: cs.primary),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: Colors.black.withOpacity(.60),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _deepAlert(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => DeepAssessmentScreen(user: user)),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: Colors.orange.withOpacity(.10),
          border: Border.all(color: Colors.orange.withOpacity(0.18)),
        ),
        child: Row(
          children: const [
            Icon(Icons.psychology, color: Colors.orange),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                "ทำแบบประเมินเชิงลึก (TMHI-55)",
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
            Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }

  Widget _statusCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: Colors.white.withOpacity(0.92),
        boxShadow: [
          BoxShadow(
            blurRadius: 22,
            color: Colors.black.withOpacity(.06),
            offset: const Offset(0, 12),
          ),
        ],
        border: Border.all(color: Colors.black.withOpacity(0.04)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withOpacity(.15),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: TextStyle(color: Colors.black.withOpacity(.60)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String text) {
    final cs = Theme.of(context).colorScheme;

    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: cs.primary,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
        ),
      ],
    );
  }

  void _showNotifications(BuildContext context) async {
    // 🔴 1. mark ทุกอันที่ยังไม่อ่าน ให้เป็นอ่านแล้ว
    final unread = await FirebaseFirestore.instance
        .collection('notifications')
        .where('uid', isEqualTo: user.uid)
        .where('read', isEqualTo: false)
        .get();

    for (final doc in unread.docs) {
      await doc.reference.update({'read': true});
    }

    // 🔔 2. แสดง BottomSheet
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) {
        final cs = Theme.of(context).colorScheme;

        return Container(
          padding: const EdgeInsets.all(20),
          height: 400,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "การแจ้งเตือน",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('notifications')
                      .where('uid', isEqualTo: user.uid)
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(
                        child: CircularProgressIndicator(color: cs.primary),
                      );
                    }

                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Center(child: Text("ยังไม่มีการแจ้งเตือน"));
                    }

                    final docs = snapshot.data!.docs;

                    return ListView.builder(
                      itemCount: docs.length,
                      itemBuilder: (_, i) {
                        final data = docs[i].data() as Map<String, dynamic>;
                        final isRead = data['read'] ?? false;

                        return ListTile(
                          leading: Icon(
                            Icons.notifications,
                            color: isRead ? Colors.black38 : cs.primary,
                          ),
                          title: Text(
                            data['title'] ?? '',
                            style: TextStyle(
                              fontWeight: isRead ? FontWeight.w500 : FontWeight.w900,
                            ),
                          ),
                          subtitle: Text(data['body'] ?? ''),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}