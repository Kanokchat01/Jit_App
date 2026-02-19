import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();

  static const String _channelId = 'jiddee_channel';
  static const String _channelName = 'JidDee Notifications';
  static const String _channelDesc = 'Notifications for JidDee app';

  bool _inited = false;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _apptSub;
  StreamSubscription<String>? _tokenSub;
  StreamSubscription<RemoteMessage>? _onMessageOpenedSub;

  // ===== กันยิงซ้ำ + จดจำ state =====
  final Map<String, String> _lastStatusByApptId = {};
  final Map<String, bool> _nearDueNotifiedByApptId = {};
  final Map<String, int> _lastApptAtMillisById = {};

  // ===== Tap stream (ให้ UI listen แล้วค่อย navigate) =====
  final StreamController<String?> _tapController = StreamController<String?>.broadcast();
  Stream<String?> get onTapStream => _tapController.stream;

  /// เรียกหลัง login สำเร็จ + มี uid แล้ว
  Future<void> initForUser(String uid) async {
    // init ครั้งเดียว
    if (!_inited) {
      await _initLocalNotifications();
      await _initFCMListeners();
      _inited = true;
    }

    // ขอ permission + เก็บ token ทุกครั้งเผื่อเปลี่ยน
    await _requestPermission();
    await _saveFcmToken(uid);

    // เริ่มฟังสถานะนัดหมายแบบ realtime แล้วเด้งแจ้งเตือน (local)
    _listenAppointmentStatus(uid);
  }

  Future<void> dispose() async {
    await _apptSub?.cancel();
    _apptSub = null;

    await _tokenSub?.cancel();
    _tokenSub = null;

    await _onMessageOpenedSub?.cancel();
    _onMessageOpenedSub = null;
  }

  // =========================
  // Local notifications
  // =========================
  Future<void> _initLocalNotifications() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);

    await _local.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse resp) {
        // payload ที่เราแนบตอน showLocal()
        _tapController.add(resp.payload);
      },
      // เผื่อบาง platform ต้องการ (ไม่ใส่ก็ได้ แต่ใส่ไว้ไม่เสียหาย)
      onDidReceiveBackgroundNotificationResponse: _onBackgroundLocalTap,
    );

    // Android channel (จำเป็นสำหรับ Android 8+)
    const androidChannel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDesc,
      importance: Importance.max,
    );

    final androidPlugin =
        _local.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    await androidPlugin?.createNotificationChannel(androidChannel);
  }

  // ต้องเป็น top-level หรือ static function
  static void _onBackgroundLocalTap(NotificationResponse resp) {
    // ใน background เราเข้าถึง instance/stream ไม่ได้ง่าย
    // ปล่อยไว้ก่อน ทาง A เน้น foreground + onMessageOpened/getInitialMessage
  }

  Future<void> showLocal({
    required String title,
    required String body,
    String? payload, // เช่น "appointment:xxxx"
  }) async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDesc,
        importance: Importance.max,
        priority: Priority.high,
      ),
    );

    final id = DateTime.now().millisecondsSinceEpoch.remainder(100000);
    await _local.show(id, title, body, details, payload: payload);
  }

  // =========================
  // FCM
  // =========================
  Future<void> _requestPermission() async {
    await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  Future<void> _saveFcmToken(String uid) async {
    final token = await _fcm.getToken();
    if (token == null) return;

    await _db.collection('users').doc(uid).set(
      {
        'fcmToken': token,
        'fcmUpdatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    // กัน listener ซ้อน
    await _tokenSub?.cancel();
    _tokenSub = _fcm.onTokenRefresh.listen((newToken) async {
      await _db.collection('users').doc(uid).set(
        {
          'fcmToken': newToken,
          'fcmUpdatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    });
  }

  Future<void> _initFCMListeners() async {
    // foreground message -> โชว์ local
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final n = message.notification;
      if (n == null) return;

      // payload จาก data (ถ้ามี) เพื่อให้กดแล้วไปหน้าที่ต้องการได้
      final payload = _payloadFromMessage(message);

      showLocal(
        title: n.title ?? 'JidDee',
        body: n.body ?? '',
        payload: payload,
      );
    });

    // ผู้ใช้กดแจ้งเตือนตอนแอปอยู่ background
    await _onMessageOpenedSub?.cancel();
    _onMessageOpenedSub = FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _tapController.add(_payloadFromMessage(message));
    });

    // ผู้ใช้กดแจ้งเตือนตอนแอปถูกปิด (terminated)
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) {
      _tapController.add(_payloadFromMessage(initial));
    }
  }

  String? _payloadFromMessage(RemoteMessage message) {
    // คุณจะกำหนด format เองได้
    // ตัวอย่าง: data = { "type":"appointment", "apptId":"xxx" }
    final data = message.data;
    final type = (data['type'] ?? '').toString();
    final apptId = (data['apptId'] ?? '').toString();

    if (type == 'appointment' && apptId.isNotEmpty) {
      return 'appointment:$apptId';
    }

    // fallback
    final route = (data['route'] ?? '').toString();
    if (route.isNotEmpty) return 'route:$route';

    return null;
  }

  // =========================
  // Appointment realtime -> local notify
  // =========================
  void _listenAppointmentStatus(String uid) {
    _apptSub?.cancel();

    _apptSub = _db
        .collection('appointments')
        .where('patientUid', isEqualTo: uid)
        .snapshots()
        .listen((qs) {
      for (final d in qs.docs) {
        final data = d.data();
        final apptId = d.id;
        final status = (data['status'] ?? '').toString().toLowerCase();

        // ==== เตรียมเวลา appointmentAt ====
        DateTime? dt;
        final apptAt = data['appointmentAt'];
        if (apptAt is Timestamp) dt = apptAt.toDate();

        // ถ้าเวลาเปลี่ยน ให้ reset nearDue เพื่อให้เตือนได้อีกครั้ง
        final millis = dt?.millisecondsSinceEpoch;
        if (millis != null) {
          final oldMillis = _lastApptAtMillisById[apptId];
          if (oldMillis != null && oldMillis != millis) {
            _nearDueNotifiedByApptId[apptId] = false;
          }
          _lastApptAtMillisById[apptId] = millis;
        }

        // ==== กันยิงซ้ำจาก status ไม่เปลี่ยน ====
        final oldStatus = _lastStatusByApptId[apptId];
        final statusChanged = oldStatus != status;

        if (statusChanged) {
          _lastStatusByApptId[apptId] = status;

          // ถ้าเพิ่งสร้างใหม่ (pending) ก็แจ้งครั้งนึงได้
          if (status == 'pending' && oldStatus == null) {
            showLocal(
              title: 'ส่งคำขอนัดแพทย์แล้ว',
              body: 'สถานะ: รออนุมัติ',
              payload: 'appointment:$apptId',
            );
          }

          if (status == 'approved' || status == 'confirmed') {
            showLocal(
              title: 'คำขอนัดได้รับการอนุมัติ',
              body: 'แพทย์อนุมัติแล้ว กรุณาตรวจสอบวันนัดในหน้า Home',
              payload: 'appointment:$apptId',
            );
          }

          if (status == 'rejected') {
            final note = (data['adminNote'] ?? '').toString().trim();
            showLocal(
              title: 'คำขอนัดถูกปฏิเสธ',
              body: note.isEmpty ? 'กรุณาตรวจสอบรายละเอียดในหน้า Home' : 'เหตุผล: $note',
              payload: 'appointment:$apptId',
            );
          }

          // ถ้า status เปลี่ยน ให้ reset nearDue ได้ (กันบางเคส approved/confirmed ใหม่)
          _nearDueNotifiedByApptId[apptId] = _nearDueNotifiedByApptId[apptId] ?? false;
        }

        // ==== แจ้ง “ใกล้ถึงวันนัด” ยิงครั้งเดียว ====
        if (dt != null && (status == 'approved' || status == 'confirmed')) {
          final diff = dt.difference(DateTime.now());
          final alreadyNotified = _nearDueNotifiedByApptId[apptId] ?? false;

          if (!alreadyNotified && diff.inHours <= 24 && diff.inMinutes > 0) {
            _nearDueNotifiedByApptId[apptId] = true;

            showLocal(
              title: 'ใกล้ถึงวันนัดแพทย์',
              body: 'อีกประมาณ ${diff.inHours} ชั่วโมง จะถึงเวลานัดแล้ว',
              payload: 'appointment:$apptId',
            );
          }
        }
      }
    });
  }
}
