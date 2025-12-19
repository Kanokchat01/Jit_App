import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../services/firestore_service.dart';

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
    return Scaffold(
      appBar: AppBar(title: const Text('Login / Register')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: email,
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: pass,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            const SizedBox(height: 16),
            if (error != null) ...[
              Text(error!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 8),
            ],
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: loading ? null : _loginOrRegister,
                child: loading
                    ? const SizedBox(
                        height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Continue'),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'หมายเหตุ: สมัครใหม่ระบบจะตั้ง role เป็น patient อัตโนมัติ (ปรับเป็น clinician/admin ได้ใน Firestore)',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loginOrRegister() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final e = email.text.trim();
      final p = pass.text;

      UserCredential cred;
      try {
        cred = await FirebaseAuth.instance.signInWithEmailAndPassword(email: e, password: p);
      } on FirebaseAuthException {
        cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(email: e, password: p);
      }

      await FirestoreService().ensureUserDoc(
        uid: cred.user!.uid,
        name: e,
        role: 'patient',
      );
    } catch (e) {
      setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }
}
