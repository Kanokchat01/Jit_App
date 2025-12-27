import 'package:flutter/material.dart';

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

  DateTime? selectedDate;
  TimeOfDay? selectedTime;

  bool saving = false;

  @override
  Widget build(BuildContext context) {
    final dateText = selectedDate == null
        ? 'เลือกวันที่'
        : '${selectedDate!.day.toString().padLeft(2, '0')}/'
              '${selectedDate!.month.toString().padLeft(2, '0')}/'
              '${selectedDate!.year}';

    final timeText = selectedTime == null
        ? 'เลือกเวลา'
        : selectedTime!.format(context);

    final canSubmit = selectedDate != null && selectedTime != null && !saving;

    return Scaffold(
      appBar: AppBar(
        title: const Text('นัดแพทย์'),
        backgroundColor: Colors.red,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// =========================
            /// Title
            /// =========================
            const Text(
              'กรุณาเลือกวันและเวลาที่ต้องการเข้ารับการปรึกษาแพทย์',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 20),

            /// =========================
            /// Select Date
            /// =========================
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: const Text('วันที่'),
              subtitle: Text(dateText),
              onTap: _pickDate,
            ),

            const Divider(),

            /// =========================
            /// Select Time
            /// =========================
            ListTile(
              leading: const Icon(Icons.access_time),
              title: const Text('เวลา'),
              subtitle: Text(timeText),
              onTap: selectedDate == null ? null : _pickTime,
            ),

            const SizedBox(height: 20),

            /// =========================
            /// Optional Note
            /// =========================
            const Text(
              'หมายเหตุ (ไม่บังคับ)',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _noteController,
              maxLines: 3,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'เช่น อาการที่อยากปรึกษา หรือช่วงเวลาที่สะดวก',
              ),
            ),

            const Spacer(),

            /// =========================
            /// Submit
            /// =========================
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: canSubmit ? _submit : null,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: saving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('ส่งคำขอนัด'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// =========================
  /// Pick Date
  /// =========================
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

  /// =========================
  /// Pick Time
  /// =========================
  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 9, minute: 0),
    );

    if (picked != null) {
      setState(() => selectedTime = picked);
    }
  }

  /// =========================
  /// Submit Appointment
  /// =========================
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

      await FirestoreService().createAppointment(
        user: widget.user,
        appointmentAt: dateTime,
        note: _noteController.text.trim(),
      );

      if (!mounted) return;

      Navigator.popUntil(context, (route) => route.isFirst);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }
}
