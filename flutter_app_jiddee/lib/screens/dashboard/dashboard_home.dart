import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/app_user.dart';
import '../../models/risk_level.dart';
import '../../services/firestore_service.dart';

import '../../gates/auth_gate.dart';

import '../patient/phq9_screen.dart';
import '../patient/appointment_screen.dart';
import '../patient/edit_profile_screen.dart';
import '../deep_assessment/deep_assessment_screen.dart';

class DashboardHome extends StatelessWidget {
  final AppUser user;
  const DashboardHome({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fs = FirestoreService();

    final phq = (user.phq9RiskLevel ?? '').toLowerCase();
    final deep = (user.deepRiskLevel ?? '').toLowerCase();

    final hasPhq9 = user.hasCompletedPhq9;
    final RiskLevel? phq9Risk = riskFromString(user.phq9RiskLevel);

    final needDeep = hasPhq9 && (phq == 'yellow' || phq == 'red');
    final deepDone = user.hasCompletedDeepAssessment;
    final deepNotDone = needDeep && !deepDone;

    final deepIsRed = deepDone && deep == 'red';
    final canRequestAppointment = deepIsRed;

    // ✅ จะโชว์สถานะนัดหมาย ก็ต่อเมื่อผ่าน deep แล้ว
    final shouldShowAppointmentSection = deepDone;

    // =========================
    // Deep text
    // =========================
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
        deepText = 'ทำแล้ว (ไม่พบระดับความเสี่ยง)';
        deepColor = Colors.blueGrey;
        deepIcon = Icons.info_outline;
      } else {
        deepText = 'ผลเชิงลึก: ${deepRisk.label}';
        deepColor = deepRisk.color;
        deepIcon = deepRisk.icon;
      }
    }

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _topBar(context),
            const SizedBox(height: 12),

            _heroCard(context),
            const SizedBox(height: 14),

            // =========================
            // Quick Actions
            // =========================
            Row(
              children: [
                Expanded(
                  child: _actionButton(
                    icon: Icons.assignment,
                    title: 'ทำแบบประเมิน',
                    subtitle: 'PHQ-9',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => Phq9Screen(user: user, fromHome: true),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _actionButton(
                    icon: Icons.calendar_month,
                    title: 'นัดแพทย์',
                    subtitle: canRequestAppointment ? 'ส่งคำขอ' : 'ทำ Deep ก่อน',
                    onTap: () {
                      if (!canRequestAppointment) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('ต้องทำแบบสอบถามเชิงลึก และผลเป็น “สีแดง” ก่อน'),
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
            ),

            // =========================
            // Deep required
            // =========================
            if (deepNotDone) ...[
              const SizedBox(height: 14),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.assignment_turned_in, color: Colors.orange),
                  title: const Text(
                    'ต้องทำแบบสอบถามเชิงลึก (TMHI-55)',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: const Text('PHQ-9 ของคุณอยู่ระดับเหลือง/แดง กรุณาทำแบบสอบถามเชิงลึกต่อ'),
                  trailing: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DeepAssessmentScreen(user: user),
                        ),
                      );
                    },
                    child: const Text('ทำต่อ'),
                  ),
                ),
              ),
            ],

            if (deepIsRed) ...[
              const SizedBox(height: 14),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.local_hospital, color: Colors.red),
                  title: const Text(
                    'ความเสี่ยงสูง (สีแดง)',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: const Text('ระบบแนะนำให้ติดต่อแพทย์เพื่อรับการดูแล'),
                  trailing: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AppointmentScreen(user: user),
                        ),
                      );
                    },
                    child: const Text('นัดแพทย์'),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 18),
            Text('สถานะล่าสุด', style: theme.textTheme.titleMedium),
            const SizedBox(height: 10),

            _statusCard(
              title: 'PHQ-9',
              subtitle: hasPhq9 && phq9Risk != null
                  ? 'ทำแล้ว • ${phq9Risk.label}'
                  : 'ยังไม่ได้ทำแบบประเมิน',
              leadingIcon: Icons.assignment,
              trailingIcon: hasPhq9 && phq9Risk != null ? phq9Risk.icon : Icons.warning,
              trailingColor: hasPhq9 && phq9Risk != null ? phq9Risk.color : Colors.orange,
            ),

            _statusCard(
              title: 'แบบสอบถามเชิงลึก (TMHI-55)',
              subtitle: deepText,
              leadingIcon: deepIcon,
              leadingColor: deepColor,
              subtitleColor: deepColor,
            ),

            const SizedBox(height: 16),

            // =========================
            // ✅ Appointment Status (Realtime จริง)
            // - ดู active ก่อน (pending/approved/confirmed)
            // - ถ้าไม่มี active ค่อยดู latest
            // =========================
            Text('สถานะการนัดหมาย', style: theme.textTheme.titleMedium),
            const SizedBox(height: 10),

            if (!shouldShowAppointmentSection)
              _statusCard(
                title: 'การนัดหมาย',
                subtitle: 'ยังไม่แสดง (ทำแบบสอบถามเชิงลึกก่อน)',
                leadingIcon: Icons.calendar_month,
                leadingColor: Colors.grey,
              )
            else
              StreamBuilder<Map<String, dynamic>?>(
                stream: fs.watchActiveAppointment(user.uid),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return _statusCard(
                      title: 'การนัดหมาย',
                      subtitle: 'กำลังโหลด...',
                      leadingIcon: Icons.calendar_month,
                      leadingColor: Colors.blueGrey,
                    );
                  }

                  // ถ้ามี active -> แสดงเลย (pending ควรขึ้นทันที)
                  final active = snap.data;
                  if (active != null) return _appointmentStatusCard(active);

                  // ถ้า active ไม่มี -> ไปดู latest (เช่น rejected/completed ก็ยังอยากโชว์)
                  return StreamBuilder<Map<String, dynamic>?>(
                    stream: fs.watchLatestAppointment(user.uid),
                    builder: (context, snap2) {
                      if (snap2.connectionState == ConnectionState.waiting) {
                        return _statusCard(
                          title: 'การนัดหมาย',
                          subtitle: 'กำลังโหลด...',
                          leadingIcon: Icons.calendar_month,
                          leadingColor: Colors.blueGrey,
                        );
                      }

                      if (snap2.hasError) {
                        return _statusCard(
                          title: 'การนัดหมาย',
                          subtitle: 'ไม่สามารถโหลดสถานะนัดหมายได้',
                          leadingIcon: Icons.calendar_month,
                          leadingColor: Colors.grey,
                        );
                      }

                      final last = snap2.data;
                      if (last == null) {
                        return _statusCard(
                          title: 'การนัดหมาย',
                          subtitle: 'ยังไม่มีคำขอนัด',
                          leadingIcon: Icons.calendar_month,
                          leadingColor: Colors.grey,
                        );
                      }

                      return _appointmentStatusCard(last);
                    },
                  );
                },
              ),

            const SizedBox(height: 16),
            _infoCard(),
          ],
        ),
      ),
    );
  }

  // =========================
  // TOP BAR (Logout)
  // =========================
  Widget _topBar(BuildContext context) {
    return Row(
      children: [
        const Text(
          'JidDee',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
        const Spacer(),
        IconButton(
          tooltip: 'ตั้งค่า',
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
        IconButton(
          tooltip: 'ออกจากระบบ',
          icon: const Icon(Icons.logout),
          onPressed: () async {
            final ok = await showDialog<bool>(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text('ออกจากระบบ'),
                content: const Text('คุณต้องการออกจากระบบหรือไม่'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('ยกเลิก'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('ออกจากระบบ'),
                  ),
                ],
              ),
            );

            if (ok != true) return;

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

  // =========================
  // UI Helpers
  // =========================
  Widget _heroCard(BuildContext context) {
    final risk = riskFromString(user.phq9RiskLevel);
    final badgeColor = risk?.color ?? Colors.blueGrey;
    final badgeText = risk == null ? 'ยังไม่มีผล' : 'PHQ-9: ${risk.label}';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.pink.withOpacity(0.06),
      ),
      child: Row(
        children: [
          const CircleAvatar(child: Icon(Icons.favorite)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome, ${user.name}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  badgeText,
                  style: TextStyle(
                    color: badgeColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.white,
        ),
        child: Row(
          children: [
            Icon(icon),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
                  Text(
                    subtitle,
                    style: TextStyle(color: Colors.black.withOpacity(0.6)),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }

  Widget _statusCard({
    required String title,
    required String subtitle,
    required IconData leadingIcon,
    IconData? trailingIcon,
    Color? leadingColor,
    Color? trailingColor,
    Color? subtitleColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Icon(leadingIcon, color: leadingColor),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(subtitle, style: TextStyle(color: subtitleColor)),
        trailing: trailingIcon == null ? null : Icon(trailingIcon, color: trailingColor),
      ),
    );
  }

  Widget _appointmentStatusCard(Map<String, dynamic> data) {
    final status = (data['status'] ?? '').toString();

    DateTime? dt;
    final apptAt = data['appointmentAt'];
    if (apptAt is Timestamp) dt = apptAt.toDate();
    if (apptAt is DateTime) dt = apptAt;

    final dateText = (dt == null)
        ? ''
        : '${dt.day.toString().padLeft(2, '0')}/'
            '${dt.month.toString().padLeft(2, '0')}/'
            '${dt.year} '
            '${dt.hour.toString().padLeft(2, '0')}:'
            '${dt.minute.toString().padLeft(2, '0')}';

    switch (status) {
      case 'pending':
        return _statusCard(
          title: 'การนัดหมาย',
          subtitle: 'กำลังรออนุมัติ • $dateText',
          leadingIcon: Icons.calendar_month,
          leadingColor: Colors.orange,
          trailingIcon: Icons.hourglass_top,
          trailingColor: Colors.orange,
          subtitleColor: Colors.orange,
        );
      case 'approved':
      case 'confirmed':
        return _statusCard(
          title: 'การนัดหมาย',
          subtitle: 'แพทย์อนุมัติแล้ว • $dateText',
          leadingIcon: Icons.calendar_month,
          leadingColor: Colors.green,
          trailingIcon: Icons.check_circle,
          trailingColor: Colors.green,
          subtitleColor: Colors.green,
        );
      case 'rejected':
        return _statusCard(
          title: 'การนัดหมาย',
          subtitle: 'คำขอถูกปฏิเสธ • $dateText',
          leadingIcon: Icons.calendar_month,
          leadingColor: Colors.red,
          trailingIcon: Icons.cancel,
          trailingColor: Colors.red,
          subtitleColor: Colors.red,
        );
      case 'canceled':
        return _statusCard(
          title: 'การนัดหมาย',
          subtitle: 'การนัดถูกยกเลิก • $dateText',
          leadingIcon: Icons.calendar_month,
          leadingColor: Colors.grey,
          trailingIcon: Icons.block,
          trailingColor: Colors.grey,
          subtitleColor: Colors.grey,
        );
      case 'completed':
        return _statusCard(
          title: 'การนัดหมาย',
          subtitle: 'เสร็จสิ้นแล้ว • $dateText',
          leadingIcon: Icons.calendar_month,
          leadingColor: Colors.blueGrey,
          trailingIcon: Icons.verified,
          trailingColor: Colors.blueGrey,
          subtitleColor: Colors.blueGrey,
        );
      default:
        return _statusCard(
          title: 'การนัดหมาย',
          subtitle: 'สถานะ: $status ${dateText.isEmpty ? '' : '• $dateText'}',
          leadingIcon: Icons.calendar_month,
          leadingColor: Colors.blueGrey,
          trailingIcon: Icons.info,
          trailingColor: Colors.blueGrey,
        );
    }
  }

  Widget _infoCard() {
    return const ListTile(
      leading: Icon(Icons.info),
      title: Text('Overview', style: TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text('ข้อมูลนี้ใช้เพื่อช่วยประเมินและติดตามสุขภาพจิตของคุณ'),
    );
  }
}
