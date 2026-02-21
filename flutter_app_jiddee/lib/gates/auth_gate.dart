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

        // 🔹 ยังไม่ login
        if (user == null) {
          return const LoginScreen();
        }

        // 🔹 login แล้ว แต่ยังไม่ verify → ไปหน้า VerifyEmailScreen
        //    (ส่งค่าว่าง เพราะข้อมูลจะถูกดึงจาก Firestore ตอน verify สำเร็จ
        //     หรือผู้ใช้อาจเป็นคนที่กลับมา login ใหม่หลัง register ไม่สำเร็จ)
        if (!user.emailVerified) {
          return const VerifyEmailScreen(
            name: '',
            phone: '',
            birthDate: '',
            faculty: '',
            major: '',
            studentId: '',
            year: '',
          );
        }

        // 🔹 verify แล้ว → เข้า RoleGate
        return RoleGate(firebaseUser: user);
      },
    );
  }
}
