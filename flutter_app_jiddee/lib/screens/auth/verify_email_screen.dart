import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../gates/auth_gate.dart';

class VerifyEmailScreen extends StatefulWidget {
  final String name;
  final String phone;
  final String birthDate;
  final String faculty;
  final String major;
  final String studentId;
  final String year;

  const VerifyEmailScreen({
    super.key,
    required this.name,
    required this.phone,
    required this.birthDate,
    required this.faculty,
    required this.major,
    required this.studentId,
    required this.year,
  });

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  bool loading = false;

  Future<void> _reloadAndCheck() async {
    if (loading) return;

    setState(() => loading = true);

    final auth = FirebaseAuth.instance;
    final user = auth.currentUser;

    if (user == null) {
      setState(() => loading = false);
      return;
    }

    await user.reload();
    final refreshedUser = auth.currentUser;

    // ❌ ยังไม่ verify
    if (refreshedUser == null || !refreshedUser.emailVerified) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('กรุณายืนยันอีเมลก่อน')));
      }
      setState(() => loading = false);
      return;
    }

    // ✅ ตรวจสอบว่ามี document แล้วหรือยัง
    final docRef = FirebaseFirestore.instance
        .collection('users')
        .doc(refreshedUser.uid);

    final doc = await docRef.get();

    // 🔥 ถ้ายังไม่มี document ค่อยสร้าง
    if (!doc.exists) {
      await docRef.set({
        'uid': refreshedUser.uid,
        'name': widget.name,
        'email': refreshedUser.email,
        'phone': widget.phone,
        'birthDate': widget.birthDate,
        'faculty': widget.faculty,
        'major': widget.major,
        'studentId': widget.studentId,
        'year': widget.year,
        'role': 'patient',
        'consentCamera': false,
        'hasCompletedPhq9': false,
        'hasCompletedDeepAssessment': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    // logout เพื่อ reset state
    await auth.signOut();

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const AuthGate()),
      (route) => false,
    );

    if (mounted) setState(() => loading = false);
  }

  Future<void> _resendEmail() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await user.sendEmailVerification();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('ส่งอีเมลอีกครั้งแล้ว')));
    }
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const AuthGate()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.email, size: 80, color: Colors.blue),
              const SizedBox(height: 20),
              Text(
                'กรุณายืนยันอีเมล\n${user?.email ?? ""}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: loading ? null : _reloadAndCheck,
                  child: loading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("ฉันยืนยันแล้ว"),
                ),
              ),

              TextButton(
                onPressed: _resendEmail,
                child: const Text("ส่งอีเมลอีกครั้ง"),
              ),

              TextButton(onPressed: _logout, child: const Text("ออกจากระบบ")),
            ],
          ),
        ),
      ),
    );
  }
}
