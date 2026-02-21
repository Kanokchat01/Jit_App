import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import 'verify_email_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final email = TextEditingController();
  final pass = TextEditingController();
  final name = TextEditingController();
  final phone = TextEditingController();
  final birthDate = TextEditingController();
  final faculty = TextEditingController();
  final major = TextEditingController();
  final studentId = TextEditingController();
  final year = TextEditingController();

  String? gender;

  bool loading = false;
  bool acceptedPolicy = false;
  String? error;

  final Uri privacyUrl = Uri.parse("https://privacy-policy-9db43.web.app");

  @override
  void dispose() {
    email.dispose();
    pass.dispose();
    name.dispose();
    phone.dispose();
    birthDate.dispose();
    faculty.dispose();
    major.dispose();
    studentId.dispose();
    year.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2005),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      birthDate.text = DateFormat('dd/MM/yyyy').format(picked);
    }
  }

  Future<void> _openPrivacyPolicy() async {
    if (!await launchUrl(privacyUrl, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('ไม่สามารถเปิดลิงก์ได้')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Colors.blue.shade700;

    return Scaffold(
      appBar: AppBar(
        title: const Text('สมัครสมาชิก'),
        backgroundColor: primaryColor,
      ),
      backgroundColor: Colors.blue.shade50,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            TextField(
              controller: name,
              decoration: _input('ชื่อผู้ใช้', Icons.person),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: email,
              keyboardType: TextInputType.emailAddress,
              decoration: _input('Email', Icons.email),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: pass,
              obscureText: true,
              decoration: _input('Password (min 6 characters)', Icons.lock),
            ),
            const SizedBox(height: 12),

            // 🔥 เบอร์ 10 หลัก
            TextField(
              controller: phone,
              keyboardType: TextInputType.number,
              maxLength: 10,
              decoration: _input('เบอร์โทรศัพท์ (10 หลัก)', Icons.phone),
            ),
            const SizedBox(height: 12),

            // 🔥 วันเกิดเลือกจากปฏิทิน
            TextField(
              controller: birthDate,
              readOnly: true,
              onTap: _pickDate,
              decoration: _input('วันเกิด (เลือกจากปฏิทิน)', Icons.cake),
            ),
            const SizedBox(height: 12),

            // 🔥 เพศ
            DropdownButtonFormField<String>(
              value: gender,
              decoration: const InputDecoration(
                labelText: 'เพศ',
                prefixIcon: Icon(Icons.wc),
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'male', child: Text('ชาย')),
                DropdownMenuItem(value: 'female', child: Text('หญิง')),
                DropdownMenuItem(value: 'other', child: Text('อื่นๆ')),
              ],
              onChanged: (v) => setState(() => gender = v),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: faculty,
              decoration: _input('คณะ', Icons.school),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: major,
              decoration: _input('สาขา', Icons.menu_book),
            ),
            const SizedBox(height: 12),

            // 🔥 รหัสนักศึกษา 13 หลัก
            TextField(
              controller: studentId,
              keyboardType: TextInputType.number,
              maxLength: 13,
              decoration: _input('รหัสนักศึกษาไม่มี- (13 หลัก)', Icons.badge),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: year,
              keyboardType: TextInputType.number,
              decoration: _input('ชั้นปี', Icons.calendar_today),
            ),
            const SizedBox(height: 16),

            if (error != null)
              Text(error!, style: const TextStyle(color: Colors.red)),

            const SizedBox(height: 12),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  value: acceptedPolicy,
                  onChanged: (value) {
                    setState(() {
                      acceptedPolicy = value ?? false;
                    });
                  },
                ),
                Expanded(
                  child: Wrap(
                    children: [
                      const Text(
                        'ฉันยินยอมให้แอปบันทึกและประมวลผลข้อมูลส่วนบุคคลตาม ',
                      ),
                      GestureDetector(
                        onTap: _openPrivacyPolicy,
                        child: const Text(
                          'นโยบายคุ้มครองข้อมูลส่วนบุคคล',
                          style: TextStyle(
                            decoration: TextDecoration.underline,
                            color: Colors.blue,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: (loading || !acceptedPolicy) ? null : _register,
                style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
                child: loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('สมัครสมาชิก'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _input(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  Future<void> _register() async {
    if (email.text.isEmpty ||
        pass.text.isEmpty ||
        name.text.isEmpty ||
        phone.text.length != 10 ||
        studentId.text.length != 13 ||
        gender == null ||
        birthDate.text.isEmpty) {
      setState(() => error = "กรุณากรอกข้อมูลให้ครบและถูกต้อง");
      return;
    }

    if (pass.text.length < 6) {
      setState(() => error = "รหัสผ่านต้องอย่างน้อย 6 ตัว");
      return;
    }

    setState(() {
      loading = true;
      error = null;
    });

    try {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email.text.trim(),
        password: pass.text,
      );

      await cred.user!.sendEmailVerification();

      await FirebaseFirestore.instance
          .collection('users')
          .doc(cred.user!.uid)
          .set({
            'uid': cred.user!.uid,
            'name': name.text.trim(),
            'email': email.text.trim(),
            'role': 'patient',
            'consentCamera': false,
            'phone': phone.text.trim(),
            'birthDate': birthDate.text.trim(),
            'gender': gender,
            'faculty': faculty.text.trim(),
            'major': major.text.trim(),
            'studentId': studentId.text.trim(),
            'year': year.text.trim(),
            'hasCompletedPhq9': false,
            'hasCompletedDeepAssessment': false,
            'createdAt': FieldValue.serverTimestamp(),
          });

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => VerifyEmailScreen(
            name: name.text,
            phone: phone.text,
            birthDate: birthDate.text,
            faculty: faculty.text,
            major: major.text,
            studentId: studentId.text,
            year: year.text,
          ),
        ),
      );
    } on FirebaseAuthException catch (e) {
      setState(() => error = e.message);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }
}
