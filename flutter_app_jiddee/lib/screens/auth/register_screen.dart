import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../services/firestore_service.dart';
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

  bool loading = false;
  String? error;

  @override
  void dispose() {
    email.dispose();
    pass.dispose();
    name.dispose();
    super.dispose();
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
              decoration: _input('Password', Icons.lock),
            ),
            const SizedBox(height: 16),

            if (error != null)
              Text(error!, style: const TextStyle(color: Colors.red)),

            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: loading ? null : _register,
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
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email.text.trim(),
        password: pass.text,
      );

      // สร้าง user doc ใน Firestore
      await FirestoreService().ensureUserDoc(
        uid: cred.user!.uid,
        name: name.text.trim(),
        role: 'patient',
      );

      // ✅ ส่งอีเมลยืนยัน
      await cred.user!.sendEmailVerification();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('สมัครสำเร็จ! กรุณายืนยันอีเมล')),
      );

      // ✅ ไปหน้า VerifyEmailScreen ทันที (แทนกลับหน้า login)
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const VerifyEmailScreen()),
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      setState(() => error = e.message);
    } finally {
      setState(() => loading = false);
    }
  }
}
