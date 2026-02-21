import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

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
  final Map<String, bool> _nearDueNotifiedByApptId = {};
  final Map<String, int> _lastApptAtMillisById = {};

  final StreamController<String?> _tapController =
      StreamController<String?>.broadcast();
  Stream<String?> get onTapStream => _tapController.stream;

  // =====================================================
  // INIT
  // =====================================================
  Future<void> initForUser(String uid) async {
    _currentUid = uid;

    if (!_inited) {
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
  // APPOINTMENT REALTIME LISTENER
  // =====================================================
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

            DateTime? dt;
            final apptAt = data['appointmentAt'];
            if (apptAt is Timestamp) dt = apptAt.toDate();

            final millis = dt?.millisecondsSinceEpoch;
            if (millis != null) {
              final oldMillis = _lastApptAtMillisById[apptId];
              if (oldMillis != null && oldMillis != millis) {
                _nearDueNotifiedByApptId[apptId] = false;
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
              }
            }

            // 🔔 ใกล้ถึงวันนัด
            if (dt != null && (status == 'approved' || status == 'confirmed')) {
              final diff = dt.difference(DateTime.now());
              final alreadyNotified = _nearDueNotifiedByApptId[apptId] ?? false;

              if (!alreadyNotified &&
                  diff.inHours <= 24 &&
                  diff.inMinutes > 0) {
                _nearDueNotifiedByApptId[apptId] = true;

                showLocal(
                  title: 'ใกล้ถึงวันนัดแพทย์',
                  body: 'อีกประมาณ ${diff.inHours} ชั่วโมง จะถึงเวลานัดแล้ว',
                  payload: 'appointment:$apptId',
                  type: 'appointment',
                  refId: apptId,
                );
              }
            }
          }
        });
  }

  void scheduleDeepReminderTest({required String uid}) {
    Timer(const Duration(minutes: 1), () async {
      //แจ้ง1นาที
      /*Timer(const Duration(days: 3), () async {*/ //แจ้ง3วัน
      await showLocal(
        title: 'แจ้งเตือนประเมินซ้ำ',
        body: 'กรุณากลับมาทำแบบประเมินเชิงลึกอีกครั้ง',
        type: 'deep_reminder',
      );
    });
  }

  StreamSubscription? _adminSub;

  final Set<String> _notifiedAdminIds = {};

  void listenAdminAppointments() {
    _adminSub?.cancel();

    _adminSub = FirebaseFirestore.instance
        .collection('admin_notifications')
        .where('read', isEqualTo: false)
        .snapshots()
        .listen((snapshot) {
          for (final doc in snapshot.docs) {
            if (!_notifiedAdminIds.contains(doc.id)) {
              _notifiedAdminIds.add(doc.id);

              // 🔔 แสดงอย่างเดียว ไม่ต้อง save ซ้ำ
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
