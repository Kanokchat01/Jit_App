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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ไม่สามารถเปิดลิงก์ได้')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: Stack(
        children: [
          // ✅ Background ละมุนๆ
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  cs.primary.withOpacity(0.10),
                  cs.secondary.withOpacity(0.12),
                  Theme.of(context).scaffoldBackgroundColor,
                ],
              ),
            ),
          ),
          Positioned(
            top: -90,
            left: -70,
            child: _softBlob(cs.primary.withOpacity(0.18), 220),
          ),
          Positioned(
            bottom: -110,
            right: -90,
            child: _softBlob(cs.secondary.withOpacity(0.22), 260),
          ),

          SafeArea(
            child: Column(
              children: [
                // ✅ AppBar แบบโปร: โปร่งใส ไม่แข็ง
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'สมัครสมาชิก',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Colors.black.withOpacity(0.78),
                          ),
                        ),
                      ),
                      const SizedBox(width: 48), // balance space for center title
                    ],
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(22, 10, 22, 22),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 6),

                          // ✅ Header
                          Row(
                            children: [
                              Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.85),
                                  borderRadius: BorderRadius.circular(18),
                                  boxShadow: [
                                    BoxShadow(
                                      blurRadius: 20,
                                      color: Colors.black.withOpacity(0.06),
                                      offset: const Offset(0, 10),
                                    ),
                                  ],
                                ),
                                padding: const EdgeInsets.all(8),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.asset(
                                    'assets/images/logo.png',
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'เริ่มต้นใช้งาน JitDee',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.black.withOpacity(0.78),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'กรอกข้อมูลพื้นฐานให้ครบ เพื่อสร้างโปรไฟล์ผู้ใช้งาน',
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        height: 1.35,
                                        color: Colors.black.withOpacity(0.55),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 14),

                          // ✅ Form Card (Premium)
Card(
  elevation: 0,
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(24),
  ),
  child: Container(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(24),
      boxShadow: [
        BoxShadow(
          blurRadius: 30,
          offset: const Offset(0, 18),
          color: Colors.black.withOpacity(0.06),
        ),
      ],
    ),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ===== Section: Account =====
          Text(
            'ข้อมูลบัญชี',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
              color: cs.primary,
            ),
          ),
          const SizedBox(height: 12),

          TextField(
            controller: name,
            decoration: _input('ชื่อผู้ใช้', Icons.person_outline),
          ),
          const SizedBox(height: 12),

          TextField(
            controller: email,
            keyboardType: TextInputType.emailAddress,
            decoration: _input('Email', Icons.email_outlined),
          ),
          const SizedBox(height: 12),

          TextField(
            controller: pass,
            obscureText: true,
            decoration: _input('Password (min 6 characters)', Icons.lock_outline),
          ),

          const SizedBox(height: 16),
          Divider(height: 1, color: Colors.black12),
          const SizedBox(height: 16),

          // ===== Section: Personal =====
          Text(
            'ข้อมูลส่วนตัว',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
              color: cs.primary,
            ),
          ),
          const SizedBox(height: 12),

          TextField(
            controller: phone,
            keyboardType: TextInputType.number,
            maxLength: 10,
            decoration: _input('เบอร์โทรศัพท์ (10 หลัก)', Icons.phone_outlined),
          ),
          const SizedBox(height: 12),

          TextField(
            controller: birthDate,
            readOnly: true,
            onTap: _pickDate,
            decoration: _input('วันเกิด (เลือกจากปฏิทิน)', Icons.cake_outlined),
          ),
          const SizedBox(height: 12),

          DropdownButtonFormField<String>(
            value: gender,
            decoration: _input('เพศ', Icons.wc).copyWith(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            items: const [
              DropdownMenuItem(value: 'male', child: Text('ชาย')),
              DropdownMenuItem(value: 'female', child: Text('หญิง')),
              DropdownMenuItem(value: 'other', child: Text('อื่นๆ')),
            ],
            onChanged: (v) => setState(() => gender = v),
          ),

          const SizedBox(height: 16),
          Divider(height: 1, color: Colors.black12),
          const SizedBox(height: 16),

          // ===== Section: Education =====
          Text(
            'ข้อมูลการศึกษา',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
              color: cs.primary,
            ),
          ),
          const SizedBox(height: 12),

          TextField(
            controller: faculty,
            decoration: _input('คณะ', Icons.school_outlined),
          ),
          const SizedBox(height: 12),

          TextField(
            controller: major,
            decoration: _input('สาขา', Icons.menu_book_outlined),
          ),
          const SizedBox(height: 12),

          TextField(
            controller: studentId,
            keyboardType: TextInputType.number,
            maxLength: 13,
            decoration: _input('รหัสนักศึกษาไม่มี- (13 หลัก)', Icons.badge_outlined),
          ),
          const SizedBox(height: 12),

          TextField(
            controller: year,
            keyboardType: TextInputType.number,
            decoration: _input('ชั้นปี', Icons.calendar_month_outlined),
          ),

          const SizedBox(height: 14),

          if (error != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFF6B6B).withOpacity(0.10),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                error!,
                style: TextStyle(
                  color: const Color(0xFFFF6B6B).withOpacity(0.95),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // ✅ Consent
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.65),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.black.withOpacity(0.06)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  value: acceptedPolicy,
                  onChanged: (value) {
                    setState(() => acceptedPolicy = value ?? false);
                  },
                ),
                Expanded(
                  child: Wrap(
                    children: [
                      Text(
                        'ฉันยินยอมให้แอปบันทึกและประมวลผลข้อมูลส่วนบุคคลตาม ',
                        style: TextStyle(
                          color: Colors.black.withOpacity(0.62),
                          height: 1.35,
                        ),
                      ),
                      GestureDetector(
                        onTap: _openPrivacyPolicy,
                        child: Text(
                          'นโยบายคุ้มครองข้อมูลส่วนบุคคล',
                          style: TextStyle(
                            decoration: TextDecoration.underline,
                            color: cs.primary,
                            fontWeight: FontWeight.w700,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: (loading || !acceptedPolicy) ? null : _register,
              child: loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.4,
                      ),
                    )
                  : const Text('สมัครสมาชิก'),
            ),
          ),
        ],
      ),
    ),
  ),
),

                          const SizedBox(height: 14),

                          Text(
                            'เมื่อสมัครสมาชิกแล้ว ระบบจะส่งลิงก์ยืนยันอีเมลให้\nกรุณายืนยันก่อนเข้าสู่ระบบ',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.35,
                              color: Colors.black.withOpacity(0.45),
                            ),
                          ),
                        ],
                      ),
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

  Widget _softBlob(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }

  InputDecoration _input(String label, IconData icon) {
    // ✅ ปล่อย filled/fillColor/border ให้ Theme คุมเป็นหลัก
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
    );
  }

  // ------------------ logic เดิม (ไม่แตะ) ------------------

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

      await FirebaseFirestore.instance.collection('users').doc(cred.user!.uid).set({
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