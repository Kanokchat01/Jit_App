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
    final phq = (user.phq9RiskLevel ?? '').toLowerCase();
    final deep = (user.deepRiskLevel ?? '').toLowerCase();

    final hasPhq9 = user.hasCompletedPhq9;
    final RiskLevel? phq9Risk = riskFromString(user.phq9RiskLevel);

    final needDeep = hasPhq9 && (phq == 'yellow' || phq == 'red');
    final deepDone = user.hasCompletedDeepAssessment;
    final deepNotDone = needDeep && !deepDone;

    final deepIsRed = deepDone && deep == 'red';
    final canRequestAppointment = deepIsRed;
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
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF5F3FF), Color(0xFFE0F2FE), Color(0xFFFFFFFF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _topBar(context),
                const SizedBox(height: 20),

                if (_profileIncomplete) _profileWarning(),

                const SizedBox(height: 16),
                _heroCard(),

                const SizedBox(height: 28),
                _sectionTitle("เมนูหลัก"),

                const SizedBox(height: 14),
                _newsHighlight(context),

                const SizedBox(height: 22),
                _quickActions(context, canRequestAppointment),

                if (deepNotDone || deepIsYellow) ...[
                  const SizedBox(height: 20),
                  _deepAlert(context),
                ],

                const SizedBox(height: 30),
                _sectionTitle("สถานะล่าสุด"),
                const SizedBox(height: 14),

                _statusCard(
                  title: "PHQ-9",
                  subtitle: hasPhq9 && phq9Risk != null
                      ? "ทำแล้ว • ${phq9Risk.label}"
                      : "ยังไม่ได้ทำแบบประเมิน",
                  icon: hasPhq9 && phq9Risk != null
                      ? phq9Risk.icon
                      : Icons.warning,
                  color: hasPhq9 && phq9Risk != null
                      ? phq9Risk.color
                      : Colors.orange,
                ),

                const SizedBox(height: 14),

                _statusCard(
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
    return Row(
      children: [
        const Text(
          "JitDee",
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
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
            final hasUnread =
                snapshot.hasData && snapshot.data!.docs.isNotEmpty;

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
                      decoration: const BoxDecoration(
                        color: Colors.red,
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

            /// 🔴 จุดแดงถ้ากรอกข้อมูลไม่ครบ
            if (_profileIncomplete)
              Positioned(
                right: 10,
                top: 10,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: Colors.red,
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

  Widget _profileWarning() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Text(
        "กรุณากรอกข้อมูลของท่านให้ครบ",
        style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _heroCard() {
    final risk = riskFromString(user.phq9RiskLevel);
    final badgeColor = risk?.color ?? Colors.blueGrey;
    final badgeText = risk == null
        ? "ยังไม่มีผลประเมิน"
        : "PHQ-9 : ${risk.label}";

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: const LinearGradient(
          colors: [Color(0xFFFFFFFF), Color(0xFFF1F5FF)],
        ),
        boxShadow: [
          BoxShadow(
            blurRadius: 18,
            color: Colors.black.withOpacity(.05),
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 30,
            backgroundColor: Color(0xFFEDE9FE),
            child: Icon(Icons.favorite, color: Colors.purple),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Welcome, ${user.name}",
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: badgeColor.withOpacity(.15),
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: Text(
                    badgeText,
                    style: TextStyle(
                      color: badgeColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _newsHighlight(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(26),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const UserNewsScreen()),
        );
      },
      child: Container(
        height: 140, // ความสูงคงที่
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              blurRadius: 18,
              color: Colors.black.withOpacity(.05),
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const CircleAvatar(
              backgroundColor: Color(0xFFEDE9FE),
              child: Icon(Icons.article, color: Colors.purple),
            ),
            const SizedBox(width: 16),

            /// 🔥 ดึงข่าวล่าสุด
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

                  final data =
                      snapshot.data!.docs.first.data() as Map<String, dynamic>;

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
                              fontWeight: FontWeight.w800,
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
                                color: Colors.black.withOpacity(.6),
                              ),
                            ),
                          ),
                        ],
                      ),

                      /// 🔥 Fade ด้านล่างให้จาง
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          height: 30,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.white.withOpacity(0),
                                Colors.white,
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
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }

  Widget _quickActions(BuildContext context, bool canRequestAppointment) {
    return Row(
      children: [
        Expanded(
          child: _actionCard(
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
            icon: Icons.calendar_month,
            title: "นัดแพทย์",
            subtitle: canRequestAppointment ? "ส่งคำขอ" : "ทำ Deep ก่อน",
            onTap: () {
              if (!canRequestAppointment) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("ต้องทำแบบสอบถามเชิงลึก และผลเป็นสีแดงก่อน"),
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
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              blurRadius: 18,
              color: Colors.black.withOpacity(.05),
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: const Color(0xFFEDE9FE),
              child: Icon(icon, color: Colors.purple),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: Colors.black.withOpacity(.6),
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
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: Colors.orange.withOpacity(.1),
        ),
        child: Row(
          children: const [
            Icon(Icons.psychology, color: Colors.orange),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                "ทำแบบประเมินเชิงลึก (TMHI-55)",
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }

  Widget _statusCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            blurRadius: 18,
            color: Colors.black.withOpacity(.05),
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withOpacity(.15),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: TextStyle(color: Colors.black.withOpacity(.6)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
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
        return Container(
          padding: const EdgeInsets.all(20),
          height: 400,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "การแจ้งเตือน",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
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
                      return const Center(child: CircularProgressIndicator());
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
                            color: isRead ? Colors.grey : Colors.red,
                          ),
                          title: Text(
                            data['title'] ?? '',
                            style: TextStyle(
                              fontWeight: isRead
                                  ? FontWeight.normal
                                  : FontWeight.bold,
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
