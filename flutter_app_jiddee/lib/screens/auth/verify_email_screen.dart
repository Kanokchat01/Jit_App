import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../gates/auth_gate.dart';

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  bool loading = false;

  void _goAuthGate() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const AuthGate()),
      (route) => false,
    );
  }

  Future<void> _reloadAndCheck() async {
    if (loading) return;
    setState(() => loading = true);

    final auth = FirebaseAuth.instance;

    try {
      final current = auth.currentUser;

      // ถ้า session หลุด -> กลับ AuthGate (AuthGate จะแสดง Login ให้อัตโนมัติ)
      if (current == null) {
        setState(() => loading = false);
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('เซสชันหมดอายุ กรุณาเข้าสู่ระบบใหม่')),
        );
        _goAuthGate();
        return;
      }

      await current.reload();
      final user = auth.currentUser;

      setState(() => loading = false);
      if (!mounted) return;

      if (user != null && user.emailVerified) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ยืนยันอีเมลแล้ว ✅ กลับไปหน้าเข้าสู่ระบบ')),
        );

        // ทำให้ stream ยิง event แน่นอน
        await auth.signOut();

        if (!mounted) return;
        _goAuthGate();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ยังไม่พบการยืนยันอีเมล (ลองรอ 10 วิแล้วกดอีกครั้ง)')),
        );
      }
    } catch (e) {
      setState(() => loading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เกิดข้อผิดพลาด: $e')),
      );
    }
  }

  Future<void> _resendVerification() async {
    if (loading) return;
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ไม่พบผู้ใช้ กรุณาเข้าสู่ระบบใหม่')),
      );
      _goAuthGate();
      return;
    }

    try {
      await user.sendEmailVerification();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ส่งอีเมลยืนยันอีกครั้งแล้ว')),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ส่งไม่สำเร็จ: ${e.code}')),
      );
    }
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
              const SizedBox(height: 12),
              const Text(
                'ไปที่อีเมลแล้ว “กดลิงก์ยืนยัน” (อาจอยู่ใน Spam/Promotions)\n'
                'จากนั้นกลับมากด "ฉันยืนยันแล้ว"',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.black54),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: loading ? null : _reloadAndCheck,
                  child: loading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('ฉันยืนยันแล้ว'),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: loading ? null : _resendVerification,
                child: const Text('ส่งอีเมลอีกครั้ง'),
              ),
              TextButton(
                onPressed: loading
                    ? null
                    : () async {
                        await FirebaseAuth.instance.signOut();
                        if (!mounted) return;
                        _goAuthGate();
                      },
                child: const Text('ออกจากระบบ'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
