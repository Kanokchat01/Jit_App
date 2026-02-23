import 'dart:io';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'firebase_options.dart';
import 'gates/auth_gate.dart';
import 'theme/jitdee_theme.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

/// ✅ ต้องเป็น top-level + ใส่ pragma ไม่งั้น background message อาจไม่ทำงานตอน release
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
}

/// ✅ Android Channel (ต้องตรงกับ manifest ที่เราใส่ไว้: jiddee_channel)
const AndroidNotificationChannel jiddeeChannel = AndroidNotificationChannel(
  'jiddee_channel',
  'JidDee Notifications',
  description: 'Notifications for JidDee app',
  importance: Importance.max,
);

Future<void> _initLocalNotifications() async {
  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  const initSettings = InitializationSettings(android: androidInit);

  await flutterLocalNotificationsPlugin.initialize(initSettings);

  // ✅ สร้าง channel สำหรับ Android 8+
  final androidPlugin = flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  await androidPlugin?.createNotificationChannel(jiddeeChannel);
}

Future<void> _initFCM() async {
  final fcm = FirebaseMessaging.instance;

  // ✅ ขอ permission (Android 13+ / iOS)
  await fcm.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  // ✅ ให้ iOS/foreground แสดง notification ได้ (Android ใช้ local notif อยู่แล้ว)
  await fcm.setForegroundNotificationPresentationOptions(
    alert: true,
    badge: true,
    sound: true,
  );

  // ✅ ตอนแอปเปิดอยู่ (Foreground) ให้โชว์ local notification เอง
  FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    final title = notification.title ?? 'JidDee';
    final body = notification.body ?? '';

    const androidDetails = AndroidNotificationDetails(
      'jiddee_channel',
      'JidDee Notifications',
      channelDescription: 'Notifications for JidDee app',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const details = NotificationDetails(android: androidDetails);

    await flutterLocalNotificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
      payload: message.data.isEmpty ? null : message.data.toString(),
    );
  });

  // ✅ ถ้ากด notification แล้วเปิดแอป (จาก background)
  FirebaseMessaging.onMessageOpenedApp.listen((message) {
    // ถ้าต้องการ navigate ไปหน้าเฉพาะ ค่อยทำทีหลังได้
  });

  // ✅ ถ้าเปิดแอปจากสถานะ terminated ด้วยการกด notification
  final initialMsg = await FirebaseMessaging.instance.getInitialMessage();
  if (initialMsg != null) {
    // ทำอะไรตอนเปิดครั้งแรกจากการกด notification ได้
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // ✅ ต้อง set ก่อน runApp
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  await _initLocalNotifications();
  await _initFCM();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // ❗ ห้ามใส่ const MaterialApp เพราะเราต้องส่ง theme/darkTheme ที่เป็น object
    return MaterialApp(
      debugShowCheckedModeBanner: false,

      // ✅ ใส่ธีมใหม่ของ Jitdee (UI เปลี่ยน แต่ logic ไม่เปลี่ยน)
      theme: JitdeeTheme.light(),
      darkTheme: JitdeeTheme.dark(),
      themeMode: ThemeMode.system, // หรือ ThemeMode.light ถ้ายังไม่ใช้ dark

      home: const AuthGate(),
    );
  }
}