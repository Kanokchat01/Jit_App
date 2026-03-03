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
    final cs = Theme.of(context).colorScheme;

    final dateText = selectedDate == null
        ? 'เลือกวันที่'
        : '${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}';

    final timeText =
        selectedTime == null ? 'เลือกเวลา' : selectedTime!.format(context);

    final canSubmit = selectedDate != null && selectedTime != null && !saving;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('นัดแพทย์'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black.withOpacity(0.86),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              cs.secondary.withOpacity(0.22),
              cs.primary.withOpacity(0.12),
              Colors.white,
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
                _headerCard(context),
                const SizedBox(height: 18),

                // ✅ Form Card
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(26),
                    color: Colors.white.withOpacity(0.92),
                    border: Border.all(color: Colors.black.withOpacity(0.04)),
                    boxShadow: [
                      BoxShadow(
                        blurRadius: 22,
                        offset: const Offset(0, 12),
                        color: Colors.black.withOpacity(0.06),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      _pickerTile(
                        context: context,
                        icon: Icons.calendar_today_rounded,
                        title: 'วันที่',
                        value: dateText,
                        enabled: true,
                        onTap: _pickDate,
                      ),
                      const SizedBox(height: 12),
                      _pickerTile(
                        context: context,
                        icon: Icons.access_time_rounded,
                        title: 'เวลา',
                        value: timeText,
                        enabled: selectedDate != null,
                        onTap: selectedDate == null ? null : _pickTime,
                        helperText: selectedDate == null
                            ? 'กรุณาเลือกวันก่อน'
                            : null,
                      ),
                      const SizedBox(height: 14),

                      // ✅ Note Input
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "หมายเหตุ (ถ้ามี)",
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: Colors.black.withOpacity(0.78),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _noteController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: "เช่น อยากปรึกษาเรื่องการนอน/ความเครียด...",
                          filled: true,
                          fillColor: Colors.black.withOpacity(0.04),
                          contentPadding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                // ✅ Submit Button
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: canSubmit ? _submit : null,
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(22),
                      ),
                      padding: EdgeInsets.zero,
                    ),
                    child: Ink(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: canSubmit
                              ? [cs.primary, cs.secondary]
                              : [
                                  Colors.black.withOpacity(0.18),
                                  Colors.black.withOpacity(0.14),
                                ],
                        ),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Center(
                        child: saving
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.4,
                                ),
                              )
                            : const Text(
                                "ส่งคำขอนัด",
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                  color: Colors.white,
                                ),
                              ),
                      ),
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

  Widget _headerCard(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: Colors.white.withOpacity(0.90),
        border: Border.all(color: Colors.black.withOpacity(0.04)),
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
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: cs.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(Icons.medical_services_rounded, color: cs.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "ส่งคำขอนัดหมายแพทย์",
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15.5,
                    color: Colors.black.withOpacity(0.86),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "เลือกวัน/เวลา และใส่หมายเหตุเพิ่มเติมได้",
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.black.withOpacity(0.60),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _pickerTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String value,
    required bool enabled,
    required VoidCallback? onTap,
    String? helperText,
  }) {
    final cs = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: enabled
              ? Colors.black.withOpacity(0.035)
              : Colors.black.withOpacity(0.02),
          border: Border.all(
            color: enabled
                ? Colors.black.withOpacity(0.06)
                : Colors.black.withOpacity(0.04),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: cs.primary.withOpacity(0.10),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: cs.primary, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: Colors.black.withOpacity(0.78),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 13,
                      color: enabled
                          ? Colors.black.withOpacity(0.70)
                          : Colors.black.withOpacity(0.40),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (helperText != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      helperText,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Colors.black.withOpacity(0.45),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: Colors.black.withOpacity(enabled ? 0.45 : 0.22),
            ),
          ],
        ),
      ),
    );
  }

  // =============================
  // ✅ Functions (เดิมทั้งหมด)
  // =============================

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
      setState(() => selectedTime = picked);
    }
  }

  Future<void> _submit() async {
    if (selectedDate == null || selectedTime == null) return;

    print("🔥 กดส่งคำขอนัด");

    setState(() => saving = true);

    try {
      final dateTime = DateTime(
        selectedDate!.year,
        selectedDate!.month,
        selectedDate!.day,
        selectedTime!.hour,
        selectedTime!.minute,
      );

      print("📅 วันที่เลือก: $dateTime");
      print("👤 deepRiskLevel: ${widget.user.deepRiskLevel}");

      await _fs.createAppointment(
        user: widget.user,
        appointmentAt: dateTime,
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
      );

      print("✅ createAppointment สำเร็จ");

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ส่งคำขอนัดแล้ว')),
      );

      Navigator.pop(context);
    } catch (e) {
      print("❌ ERROR createAppointment: $e");

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }
}