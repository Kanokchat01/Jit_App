import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../screens/auth/login_screen.dart';
import '../screens/auth/verify_email_screen.dart';
import 'role_gate.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snap.data;

        if (user == null) {
          return const LoginScreen();
        }

        // ✅ ถ้ายังไม่ยืนยันอีเมล -> ไปหน้า Verify
        if (!user.emailVerified) {
          return const VerifyEmailScreen();
        }

        // ✅ ส่ง Firebase User เข้า RoleGate
        return RoleGate(firebaseUser: user);
      },
    );
  }
}
