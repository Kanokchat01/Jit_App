import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  static const String _channelId = 'jiddee_channel';
  static const String _channelName = 'JidDee Notifications';
  static const String _channelDesc = 'Notifications for JidDee app';

  bool _inited = false;
  String? _currentUid;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _apptSub;
  StreamSubscription<String>? _tokenSub;
  StreamSubscription<RemoteMessage>? _onMessageOpenedSub;

  final Map<String, String> _lastStatusByApptId = {};
  final Map<String, int> _lastApptAtMillisById = {};

  /// เก็บว่าแจ้งเตือนจุดไหนไปแล้วบ้าง per apptId
  /// key = "apptId:hours", value = true (already notified)
  final Map<String, bool> _reminderFired = {};

  Timer? _reminderTimer;

  final StreamController<String?> _tapController =
      StreamController<String?>.broadcast();
  Stream<String?> get onTapStream => _tapController.stream;

  // =====================================================
  // ⏰ REMINDER CONFIG: 3 จุด (24h / 8h / 2h ก่อนนัด)
  // =====================================================
  static const List<int> _reminderHours = [24, 8, 2];

  // =====================================================
  // INIT
  // =====================================================
  Future<void> initForUser(String uid) async {
    _currentUid = uid;

    if (!_inited) {
      await _initTimeZone();
      await _initLocalNotifications();
      await _initFCMListeners();
      _inited = true;
    }

    await _requestPermission();
    await _saveFcmToken(uid);
    _listenAppointmentStatus(uid);
  }

  Future<void> dispose() async {
    await _apptSub?.cancel();
    await _tokenSub?.cancel();
    await _onMessageOpenedSub?.cancel();
    _reminderTimer?.cancel();
  }

  // =====================================================
  // TIMEZONE INIT
  // =====================================================
  Future<void> _initTimeZone() async {
    tz.initializeTimeZones();
    try {
      final tzName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(tzName));
      debugPrint('[NotifService] ⏰ Timezone: $tzName');
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('Asia/Bangkok'));
      debugPrint('[NotifService] ⏰ Timezone fallback: Asia/Bangkok');
    }
  }

  // =====================================================
  // LOCAL NOTIFICATION
  // =====================================================
  Future<void> _initLocalNotifications() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);

    await _local.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (resp) {
        _tapController.add(resp.payload);
      },
    );

    const androidChannel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDesc,
      importance: Importance.max,
    );

    final androidPlugin = _local
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    await androidPlugin?.createNotificationChannel(androidChannel);
  }

  Future<void> showLocal({
    required String title,
    required String body,
    String? payload,
    String? type,
    String? refId,
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

    if (_currentUid != null) {
      await _saveNotificationToFirestore(
        uid: _currentUid!,
        title: title,
        body: body,
        type: type,
        refId: refId,
      );
    }
  }

  // =====================================================
  // FCM
  // =====================================================
  Future<void> _requestPermission() async {
    await _fcm.requestPermission(alert: true, badge: true, sound: true);

    final androidPlugin = _local
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (androidPlugin != null) {
      await androidPlugin.requestExactAlarmsPermission();
      await androidPlugin.requestNotificationsPermission();
      debugPrint('[NotifService] ✅ Requested exact alarm + notification permissions');
    }
  }

  Future<void> _saveFcmToken(String uid) async {
    final token = await _fcm.getToken();
    if (token == null) return;

    await _db.collection('users').doc(uid).set({
      'fcmToken': token,
      'fcmUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await _tokenSub?.cancel();
    _tokenSub = _fcm.onTokenRefresh.listen((newToken) async {
      await _db.collection('users').doc(uid).set({
        'fcmToken': newToken,
        'fcmUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  Future<void> _initFCMListeners() async {
    FirebaseMessaging.onMessage.listen((message) {
      final n = message.notification;
      if (n == null) return;

      showLocal(
        title: n.title ?? 'JidDee',
        body: n.body ?? '',
        payload: _payloadFromMessage(message),
      );
    });

    await _onMessageOpenedSub?.cancel();
    _onMessageOpenedSub = FirebaseMessaging.onMessageOpenedApp.listen((
      message,
    ) {
      _tapController.add(_payloadFromMessage(message));
    });

    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) {
      _tapController.add(_payloadFromMessage(initial));
    }
  }

  String? _payloadFromMessage(RemoteMessage message) {
    final data = message.data;
    final type = (data['type'] ?? '').toString();
    final apptId = (data['apptId'] ?? '').toString();

    if (type == 'appointment' && apptId.isNotEmpty) {
      return 'appointment:$apptId';
    }

    final route = (data['route'] ?? '').toString();
    if (route.isNotEmpty) return 'route:$route';

    return null;
  }

  // =====================================================
  // ⏰ REMINDER ENGINE (Timer.periodic — ทำงานขณะเปิดแอป)
  // =====================================================

  /// เริ่ม Timer เช็คทุก 30 วินาที
  void _startReminderTimer() {
    _reminderTimer?.cancel();
    _reminderTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _checkAllReminders();
    });
    // เช็ครอบแรกทันที
    _checkAllReminders();
  }

  /// ตอนเจอนัดหมาย approved ครั้งแรก → mark จุดที่ "เวลาแจ้งเตือน" ผ่านไปแล้ว
  /// เช่น นัด 20:00, ตอนนี้ 17:00 (เหลือ 3 ชม.)
  ///   - จุด 24h → เวลาแจ้ง = 20:00 - 24h = เมื่อวาน → ผ่านไปแล้ว → mark fired
  ///   - จุด 8h  → เวลาแจ้ง = 20:00 - 8h  = 12:00     → ผ่านไปแล้ว → mark fired
  ///   - จุด 2h  → เวลาแจ้ง = 20:00 - 2h  = 18:00     → ยังไม่ถึง  → ปล่อยให้ timer เด้ง
  void _markPastRemindersAsFired(String apptId, DateTime appointmentAt) {
    final now = DateTime.now();

    for (final hours in _reminderHours) {
      final key = '$apptId:$hours';
      // เวลาที่ควรแจ้งเตือนของจุดนี้
      final fireTime = appointmentAt.subtract(Duration(hours: hours));

      if (fireTime.isBefore(now)) {
        // เวลาแจ้งผ่านไปแล้ว → mark ว่าเด้งไปแล้ว (ไม่เด้งย้อนหลัง)
        _reminderFired[key] = true;
        debugPrint('[NotifService] ⏭️ MARK PAST: ${hours}h (fireTime=$fireTime already passed)');
      }
    }
  }

  /// วนเช็คนัดหมายทุกตัว — เด้งเฉพาะตอนเวลาข้ามจุดพอดี
  void _checkAllReminders() {
    final now = DateTime.now();

    for (final apptId in _lastApptAtMillisById.keys) {
      final status = _lastStatusByApptId[apptId] ?? '';
      if (status != 'approved' && status != 'confirmed') continue;

      final millis = _lastApptAtMillisById[apptId]!;
      final appointmentAt = DateTime.fromMillisecondsSinceEpoch(millis);

      // ข้ามนัดหมายที่เวลาผ่านไปแล้ว
      if (appointmentAt.isBefore(now)) continue;

      for (final hours in _reminderHours) {
        final key = '$apptId:$hours';
        if (_reminderFired[key] == true) continue;

        // เวลาที่ควรแจ้งเตือนของจุดนี้
        final fireTime = appointmentAt.subtract(Duration(hours: hours));

        // ถ้าถึงเวลาแจ้งแล้ว (now >= fireTime) → เด้ง!
        if (now.isAfter(fireTime) || now.isAtSameMomentAs(fireTime)) {
          _reminderFired[key] = true;

          String bodyText;
          if (hours >= 24) {
            bodyText = 'อีก 1 วัน จะถึงเวลานัดแพทย์แล้ว กรุณาเตรียมตัว';
          } else {
            bodyText = 'อีก $hours ชั่วโมง จะถึงเวลานัดแพทย์แล้ว';
          }

          debugPrint('[NotifService] 🔔 FIRING ${hours}h reminder for $apptId');

          showLocal(
            title: '🔔 ใกล้ถึงวันนัดแพทย์',
            body: bodyText,
            payload: 'appointment:$apptId',
            type: 'appointment',
            refId: apptId,
          );
        }
      }
    }
  }

  // =====================================================
  // ⏰ BACKGROUND SCHEDULE (zonedSchedule — แม้ปิดแอป)
  // =====================================================

  int _reminderId(String apptId, int index) {
    return (apptId.hashCode.abs() * 10 + index) % 2147483647;
  }

  Future<void> _scheduleAppointmentReminders(
    String apptId,
    DateTime appointmentAt,
  ) async {
    await _cancelAppointmentReminders(apptId);

    final now = DateTime.now();
    debugPrint('[NotifService] 📅 zonedSchedule for appt=$apptId at=$appointmentAt');

    for (int i = 0; i < _reminderHours.length; i++) {
      final hours = _reminderHours[i];
      final reminderTime = appointmentAt.subtract(Duration(hours: hours));

      if (reminderTime.isBefore(now)) {
        debugPrint('[NotifService]    ❌ SKIP ${hours}h (past)');
        continue;
      }

      final tzTime = tz.TZDateTime.from(reminderTime, tz.local);
      final id = _reminderId(apptId, i);

      String bodyText;
      if (hours >= 24) {
        bodyText = 'อีก 1 วัน จะถึงเวลานัดแพทย์แล้ว กรุณาเตรียมตัว';
      } else {
        bodyText = 'อีก $hours ชั่วโมง จะถึงเวลานัดแพทย์แล้ว';
      }

      try {
        await _local.zonedSchedule(
          id,
          '🔔 ใกล้ถึงวันนัดแพทย์',
          bodyText,
          tzTime,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              _channelId,
              _channelName,
              channelDescription: _channelDesc,
              importance: Importance.max,
              priority: Priority.high,
            ),
          ),
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          payload: 'appointment:$apptId',
          matchDateTimeComponents: null,
        );
        debugPrint('[NotifService]    ✅ SCHEDULED ${hours}h at $tzTime');
      } catch (e) {
        debugPrint('[NotifService]    ❌ zonedSchedule error: $e');
      }
    }
  }

  Future<void> _cancelAppointmentReminders(String apptId) async {
    for (int i = 0; i < _reminderHours.length; i++) {
      await _local.cancel(_reminderId(apptId, i));
    }
  }

  // =====================================================
  // APPOINTMENT REALTIME LISTENER
  // =====================================================
  bool _apptFirstSnapshot = true;

  void _listenAppointmentStatus(String uid) {
    _apptSub?.cancel();
    _apptFirstSnapshot = true;

    // ✅ เริ่ม Timer เช็คทุก 30 วินาที (ทำงานขณะเปิดแอป)
    _startReminderTimer();

    _apptSub = _db
        .collection('appointments')
        .where('patientUid', isEqualTo: uid)
        .snapshots()
        .listen((qs) {
          if (_apptFirstSnapshot) {
            _apptFirstSnapshot = false;
            for (final d in qs.docs) {
              final data = d.data();
              final apptId = d.id;
              final status = (data['status'] ?? '').toString().toLowerCase();
              _lastStatusByApptId[apptId] = status;

              DateTime? dt;
              final apptAt = data['appointmentAt'];
              if (apptAt is Timestamp) dt = apptAt.toDate();
              final millis = dt?.millisecondsSinceEpoch;
              if (millis != null) _lastApptAtMillisById[apptId] = millis;

              // โหลดสถานะ fired จาก Firestore
              final firedList = data['remindersFired'];
              if (firedList is List) {
                for (final h in firedList) {
                  _reminderFired['$apptId:$h'] = true;
                }
              }

              // schedule background (zonedSchedule) สำหรับตอนปิดแอป
              if (dt != null &&
                  dt.isAfter(DateTime.now()) &&
                  (status == 'approved' || status == 'confirmed')) {
                // ✅ mark จุดที่เวลาผ่านไปแล้ว ไม่ต้องเด้งย้อนหลัง
                _markPastRemindersAsFired(apptId, dt);
                _scheduleAppointmentReminders(apptId, dt);
              }
            }

            // เช็ครอบแรกทันที
            _checkAllReminders();
            return;
          }

          for (final d in qs.docs) {
            final data = d.data();
            final apptId = d.id;
            final status = (data['status'] ?? '').toString().toLowerCase();

            DateTime? dt;
            final apptAt = data['appointmentAt'];
            if (apptAt is Timestamp) dt = apptAt.toDate();

            final millis = dt?.millisecondsSinceEpoch;
            if (millis != null) {
              final oldMillis = _lastApptAtMillisById[apptId];
              if (oldMillis != null && oldMillis != millis) {
                // เปลี่ยนเวลานัด → รีเซ็ต fired + re-schedule
                _cancelAppointmentReminders(apptId);
                for (final h in _reminderHours) {
                  _reminderFired['$apptId:$h'] = false;
                }
                if (dt!.isAfter(DateTime.now()) &&
                    (status == 'approved' || status == 'confirmed')) {
                  _scheduleAppointmentReminders(apptId, dt);
                }
              }
              _lastApptAtMillisById[apptId] = millis;
            }

            final oldStatus = _lastStatusByApptId[apptId];
            final statusChanged = oldStatus != status;

            if (statusChanged) {
              _lastStatusByApptId[apptId] = status;

              if (status == 'pending' && oldStatus == null) {
                showLocal(
                  title: 'ส่งคำขอนัดแพทย์แล้ว',
                  body: 'สถานะ: รออนุมัติ',
                  payload: 'appointment:$apptId',
                  type: 'appointment',
                  refId: apptId,
                );
              }

              if (status == 'approved' || status == 'confirmed') {
                showLocal(
                  title: 'คำขอนัดได้รับการอนุมัติ',
                  body: 'แพทย์อนุมัติแล้ว กรุณาตรวจสอบวันนัด',
                  payload: 'appointment:$apptId',
                  type: 'appointment',
                  refId: apptId,
                );

                // ✅ Schedule background + mark จุดที่ผ่านไปแล้ว
                if (dt != null && dt.isAfter(DateTime.now())) {
                  _markPastRemindersAsFired(apptId, dt);
                  _scheduleAppointmentReminders(apptId, dt);
                }

                // เช็คทันทีเลยหลัง approve
                _checkAllReminders();
              }

              if (status == 'rejected') {
                final note = (data['adminNote'] ?? '').toString();
                showLocal(
                  title: 'คำขอนัดถูกปฏิเสธ',
                  body: note.isEmpty
                      ? 'กรุณาตรวจสอบรายละเอียด'
                      : 'เหตุผล: $note',
                  payload: 'appointment:$apptId',
                  type: 'appointment',
                  refId: apptId,
                );
                _cancelAppointmentReminders(apptId);
              }

              if (status == 'cancelled' || status == 'completed') {
                _cancelAppointmentReminders(apptId);
              }
            }
          }
        });
  }

  void scheduleDeepReminderTest({required String uid}) {
    Timer(const Duration(minutes: 1), () async {
      await showLocal(
        title: 'แจ้งเตือนประเมินซ้ำ',
        body: 'กรุณากลับมาทำแบบประเมินเชิงลึกอีกครั้ง',
        type: 'deep_reminder',
      );
    });
  }

  StreamSubscription? _adminSub;

  final Set<String> _notifiedAdminIds = {};
  bool _adminFirstSnapshot = true;

  void listenAdminAppointments() {
    _adminSub?.cancel();
    _adminFirstSnapshot = true;

    _adminSub = FirebaseFirestore.instance
        .collection('admin_notifications')
        .where('read', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .limit(10)
        .snapshots()
        .listen((snapshot) {
          if (_adminFirstSnapshot) {
            _adminFirstSnapshot = false;

            for (int i = 0; i < snapshot.docs.length; i++) {
              final doc = snapshot.docs[i];
              _notifiedAdminIds.add(doc.id);
            }
            return;
          }

          for (final doc in snapshot.docs) {
            if (!_notifiedAdminIds.contains(doc.id)) {
              _notifiedAdminIds.add(doc.id);

              _local.show(
                DateTime.now().millisecondsSinceEpoch.remainder(100000),
                doc['title'] ?? 'แจ้งเตือนแอดมิน',
                doc['body'] ?? 'มีคำขอนัดหมายใหม่',
                const NotificationDetails(
                  android: AndroidNotificationDetails(
                    _channelId,
                    _channelName,
                    channelDescription: _channelDesc,
                    importance: Importance.max,
                    priority: Priority.high,
                  ),
                ),
              );
            }
          }
        });
  }

  // =====================================================
  // SAVE TO FIRESTORE
  // =====================================================
  Future<void> _saveNotificationToFirestore({
    required String uid,
    required String title,
    required String body,
    String? type,
    String? refId,
  }) async {
    await _db.collection('notifications').add({
      'uid': uid,
      'title': title,
      'body': body,
      'type': type ?? '',
      'refId': refId ?? '',
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
