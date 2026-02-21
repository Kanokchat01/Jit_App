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
    final deepIsRed =
        widget.user.hasCompletedDeepAssessment &&
        (widget.user.deepRiskLevel ?? '').toLowerCase() == 'red';

    if (!deepIsRed) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('นัดแพทย์'),
          backgroundColor: Colors.red,
        ),
        body: const Center(
          child: Text("สิทธิ์ไม่เพียงพอ ต้อง Deep Assessment = red"),
        ),
      );
    }

    final dateText = selectedDate == null
        ? 'เลือกวันที่'
        : '${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}';

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
          children: [
            ListTile(
              title: const Text("วันที่"),
              subtitle: Text(dateText),
              onTap: _pickDate,
            ),
            ListTile(
              title: const Text("เวลา"),
              subtitle: Text(timeText),
              onTap: selectedDate == null ? null : _pickTime,
            ),
            TextField(
              controller: _noteController,
              decoration: const InputDecoration(labelText: "หมายเหตุ"),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: canSubmit ? _submit : null,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: saving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("ส่งคำขอนัด"),
              ),
            ),
          ],
        ),
      ),
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

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('ส่งคำขอนัดแล้ว')));

      Navigator.pop(context);
    } catch (e) {
      print("❌ ERROR createAppointment: $e");

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }
}
