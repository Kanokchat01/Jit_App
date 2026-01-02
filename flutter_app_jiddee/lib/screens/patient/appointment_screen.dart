import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/app_user.dart';
import '../../services/firestore_service.dart';

class AppointmentScreen extends StatefulWidget {
  final AppUser user;
  const AppointmentScreen({super.key, required this.user});

  @override
  State<AppointmentScreen> createState() => _AppointmentScreenState();
}

class _AppointmentScreenState extends State<AppointmentScreen> {
  final _noteController = TextEditingController();
  final _fs = FirestoreService();

  DateTime? selectedDate;
  TimeOfDay? selectedTime;
  bool saving = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ✅ นัดได้เฉพาะ Deep Assessment = red
    final deepIsRed = widget.user.hasCompletedDeepAssessment &&
        (widget.user.deepRiskLevel ?? '').toLowerCase() == 'red';

    // =========================
    // ❌ NOT ALLOWED UI (สวยขึ้น + ปุ่มกลับ Home)
    // =========================
    if (!deepIsRed) {
      final theme = Theme.of(context);

      return Scaffold(
        appBar: AppBar(
          title: const Text('นัดแพทย์'),
          backgroundColor: Colors.red,
        ),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(18),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 520),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.red.withOpacity(0.18)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 14,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Icon badge
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.10),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.lock_outline,
                      size: 32,
                      color: Colors.red,
                    ),
                  ),
                  const SizedBox(height: 14),

                  Text(
                    'กลับไปยังหน้า Home เพื่อทำการนัดหมายแพทย์',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),

                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.red.withOpacity(0.14)),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'การส่งคำขอนัดพบแพทย์',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'อนุญาตเฉพาะผู้ที่ทำแบบสอบถามเชิงลึกแล้ว และได้ผล “สีแดง” เท่านั้น',
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Hint / steps
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'แนะนำ',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  _tipRow(
                    icon: Icons.assignment_turned_in,
                    text: 'ทำแบบสอบถามเชิงลึก (TMHI-55) ให้ครบถ้วน',
                  ),
                  const SizedBox(height: 6),
                  _tipRow(
                    icon: Icons.monitor_heart,
                    text: 'หากผลเป็น “สีแดง” ระบบจะเปิดให้ส่งคำขอนัดแพทย์',
                  ),

                  const SizedBox(height: 18),

                  // ✅ Center button under text
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () {
                        // ถ้ามี stack ก่อนหน้า -> กลับไปได้เลย (โดยมากคือ Home)
                        if (Navigator.of(context).canPop()) {
                          Navigator.pop(context);
                        } else {
                          // fallback
                          Navigator.of(context).pushNamedAndRemoveUntil(
                            '/',
                            (route) => false,
                          );
                        }
                      },
                      icon: const Icon(Icons.home),
                      label: const Text(
                        'กลับหน้า Home',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // =========================
    // ✅ ALLOWED UI (เดิมของคุณ)
    // =========================
    final dateText = selectedDate == null
        ? 'เลือกวันที่'
        : '${selectedDate!.day.toString().padLeft(2, '0')}/'
            '${selectedDate!.month.toString().padLeft(2, '0')}/'
            '${selectedDate!.year}';

    final timeText =
        selectedTime == null ? 'เลือกเวลา' : selectedTime!.format(context);

    final canSubmit = selectedDate != null && selectedTime != null && !saving;

    return Scaffold(
      appBar: AppBar(
        title: const Text('นัดแพทย์'),
        backgroundColor: Colors.red,
      ),
      body: StreamBuilder<Map<String, dynamic>?>(
        stream: _fs.watchActiveAppointment(widget.user.uid),
        builder: (context, snapshot) {
          final activeAppt = snapshot.data;
          final hasActive = activeAppt != null;

          String? activeText;
          if (hasActive) {
            final status = (activeAppt['status'] ?? '').toString();
            final apptAt = activeAppt['appointmentAt'];

            DateTime? dt;
            if (apptAt is Timestamp) dt = apptAt.toDate();
            if (apptAt is DateTime) dt = apptAt;

            final dtText = dt == null
                ? ''
                : ' • ${dt.day.toString().padLeft(2, '0')}/'
                    '${dt.month.toString().padLeft(2, '0')}/'
                    '${dt.year} '
                    '${dt.hour.toString().padLeft(2, '0')}:'
                    '${dt.minute.toString().padLeft(2, '0')}';

            if (status == 'pending') {
              activeText = 'คุณมีคำขอนัดที่กำลังรออนุมัติอยู่แล้ว$dtText';
            } else if (status == 'approved' || status == 'confirmed') {
              activeText = 'คุณมีนัดที่อนุมัติแล้ว$dtText';
            } else {
              activeText = 'คุณมีนัดที่กำลังดำเนินการอยู่$dtText';
            }
          }

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hasActive) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange.withOpacity(0.4)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.hourglass_top, color: Colors.orange),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            activeText ?? '',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                const Text(
                  'กรุณาเลือกวันและเวลาที่ต้องการเข้ารับการปรึกษาแพทย์',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 20),

                ListTile(
                  leading: const Icon(Icons.calendar_today),
                  title: const Text('วันที่'),
                  subtitle: Text(dateText),
                  onTap: hasActive ? null : _pickDate,
                ),
                const Divider(),

                ListTile(
                  leading: const Icon(Icons.access_time),
                  title: const Text('เวลา'),
                  subtitle: Text(timeText),
                  onTap: (selectedDate == null || hasActive) ? null : _pickTime,
                ),

                const SizedBox(height: 20),

                const Text(
                  'หมายเหตุ (ไม่บังคับ)',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _noteController,
                  maxLines: 3,
                  enabled: !hasActive,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'เช่น อาการที่อยากปรึกษา หรือช่วงเวลาที่สะดวก',
                  ),
                ),

                const Spacer(),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: (!hasActive && canSubmit) ? _submit : null,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    child: saving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : Text(hasActive ? 'มีคำขอนัด/นัดอยู่แล้ว' : 'ส่งคำขอนัด'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _tipRow({required IconData icon, required String text}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.blueGrey),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: Colors.black.withOpacity(0.75)),
          ),
        ),
      ],
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 90)),
    );

    if (picked != null) {
      setState(() {
        selectedDate = picked;
        selectedTime = null;
      });
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 9, minute: 0),
    );

    if (picked != null) {
      final minutes = picked.hour * 60 + picked.minute;
      if (minutes < 9 * 60 || minutes > 17 * 60) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('กรุณาเลือกเวลาในช่วง 09:00 - 17:00')),
        );
        return;
      }
      setState(() => selectedTime = picked);
    }
  }

  Future<void> _submit() async {
    if (selectedDate == null || selectedTime == null) return;

    setState(() => saving = true);

    try {
      final dateTime = DateTime(
        selectedDate!.year,
        selectedDate!.month,
        selectedDate!.day,
        selectedTime!.hour,
        selectedTime!.minute,
      );

      if (dateTime.isBefore(DateTime.now())) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('กรุณาเลือกวัน/เวลาที่อยู่ในอนาคต')),
        );
        return;
      }

      await _fs.createAppointment(
        user: widget.user,
        appointmentAt: dateTime,
        note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ส่งคำขอนัดแล้ว • รอแพทย์อนุมัติ')),
      );

      // ✅ กลับ Home เดิม → Stream จะอัปเดตเอง
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ส่งคำขอไม่สำเร็จ: $e')),
      );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }
}
