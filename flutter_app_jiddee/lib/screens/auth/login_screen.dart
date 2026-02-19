import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/firestore_service.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final email = TextEditingController();
  final pass = TextEditingController();
  bool loading = false;
  String? error;

  @override
  void dispose() {
    email.dispose();
    pass.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Colors.blue.shade700;

    return Scaffold(
      backgroundColor: Colors.blue.shade50,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 48,
                backgroundColor: primaryColor,
                child: const Icon(
                  Icons.local_hospital,
                  size: 48,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 24),

              Text(
                'Clinic Login',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
              ),
              const SizedBox(height: 16),

              // Email
              TextField(
                controller: email,
                keyboardType: TextInputType.emailAddress,
                decoration: _input('Email', Icons.email),
              ),
              const SizedBox(height: 12),

              // Password
              TextField(
                controller: pass,
                obscureText: true,
                decoration: _input('Password', Icons.lock),
              ),
              const SizedBox(height: 16),

              if (error != null) ...[
                Text(error!, style: const TextStyle(color: Colors.red)),
                const SizedBox(height: 8),
              ],

              // Continue
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: loading ? null : _loginOrRegister,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: loading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Continue', style: TextStyle(fontSize: 18)),
                ),
              ),

              // ✅ Forgot Password
              const SizedBox(height: 6),
              TextButton(
                onPressed: loading ? null : _forgotPassword,
                child: const Text('ลืมรหัสผ่าน?'),
              ),

              // สมัครสมาชิก
              const SizedBox(height: 6),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const RegisterScreen()),
                  );
                },
                child: const Text('สมัครสมาชิก'),
              ),

              const SizedBox(height: 16),
              const Text(
                'หมายเหตุ: สมัครใหม่ระบบจะตั้ง role เป็น patient อัตโนมัติ\n(ปรับเป็น clinician/admin ได้ใน Firestore)',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
          ),
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

  Future<void> _loginOrRegister() async {
  setState(() {
    loading = true;
    error = null;
  });

  try {
    final em = email.text.trim();
    final pw = pass.text;

    final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: em,
      password: pw,
    );

    // ✅ debug log
    debugPrint('LOGIN OK uid=${cred.user?.uid} verified=${cred.user?.emailVerified}');

    await FirestoreService().ensureUserDoc(
      uid: cred.user!.uid,
      name: em,
      role: 'patient',
    );
  } on FirebaseAuthException catch (e) {
    debugPrint('LOGIN ERROR code=${e.code} msg=${e.message}');
    setState(() => error = '${e.code}: ${e.message}');
  } catch (e) {
    debugPrint('LOGIN ERROR other=$e');
    setState(() => error = e.toString());
  } finally {
    setState(() => loading = false);
  }
}


  Future<void> _forgotPassword() async {
    setState(() => error = null);

    final em = email.text.trim();
    if (em.isEmpty) {
      setState(() => error = 'กรุณากรอกอีเมลก่อน แล้วค่อยกด "ลืมรหัสผ่าน"');
      return;
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: em);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ส่งลิงก์รีเซ็ตรหัสผ่านไปที่อีเมลแล้ว')),
      );
    } on FirebaseAuthException catch (e) {
      setState(() => error = e.message);
    }
  }
}
