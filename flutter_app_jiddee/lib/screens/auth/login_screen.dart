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
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: Stack(
        children: [
          // ✅ Background (ละมุน + มีวงกลมเบาๆ)
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
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 6),

                      // ✅ Header (Logo + Title)
                      Column(
                        children: [
                          Container(
                            width: 110,
                            height: 110,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.85),
                              borderRadius: BorderRadius.circular(28),
                              boxShadow: [
                                BoxShadow(
                                  blurRadius: 24,
                                  color: Colors.black.withOpacity(0.06),
                                  offset: const Offset(0, 12),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.all(10),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(22),
                              child: Image.asset(
                                'assets/images/logo.png',
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'JitDee',
                            style: TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w800,
                              color: cs.primary,
                              letterSpacing: 0.2,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Clinic Login',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: Colors.black.withOpacity(0.78),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'ยินดีต้อนรับ\nเข้าสู่ระบบเพื่อประเมินและติดตามสุขภาพใจ',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.35,
                              color: Colors.black.withOpacity(0.55),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 18),

                      // ✅ Card Form
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'เข้าสู่ระบบ',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.black.withOpacity(0.78),
                                ),
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
                                decoration: _input('Password', Icons.lock_outline),
                              ),

                              const SizedBox(height: 12),

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

                              SizedBox(
                                height: 48,
                                child: ElevatedButton(
                                  onPressed: loading ? null : _loginOrRegister,
                                  child: loading
                                      ? const SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.4,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Text('Continue'),
                                ),
                              ),

                              const SizedBox(height: 10),

                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  TextButton(
                                    onPressed: loading ? null : _forgotPassword,
                                    child: const Text('ลืมรหัสผ่าน?'),
                                  ),
                                  const SizedBox(width: 6),
                                  const Text('•'),
                                  const SizedBox(width: 6),
                                  TextButton(
                                    onPressed: loading
                                        ? null
                                        : () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) => const RegisterScreen(),
                                              ),
                                            );
                                          },
                                    child: const Text('สมัครสมาชิก'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 14),

                      // ✅ Note
                      Text(
                        'หมายเหตุ: สมัครใหม่ระบบจะตั้ง role เป็น patient อัตโนมัติ\n(ปรับเป็น clinician/admin ได้ใน Firestore)',
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
          ),
        ],
      ),
    );
  }

  Widget _softBlob(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }

  InputDecoration _input(String label, IconData icon) {
    // ✅ ใช้ theme เป็นหลัก → ไม่ต้อง hardcode สี/กรอบเยอะ
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      // ปล่อย filled/fillColor/border ให้ Theme คุม
    );
  }

  // ------------------ logic เดิม (ไม่แตะ) ------------------

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
      debugPrint(
        'LOGIN OK uid=${cred.user?.uid} verified=${cred.user?.emailVerified}',
      );

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