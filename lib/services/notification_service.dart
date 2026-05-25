// ignore_for_file: avoid_print

import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  NotificationService._();
  static final FlutterLocalNotificationsPlugin _localNotif =
      FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    if (Platform.isAndroid) {
      await _localNotif
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(
            const AndroidNotificationChannel(
              'order_ready_channel',
              'Order Ready',
              description: 'แจ้งเตือนเมื่ออาหารพร้อมให้รับที่ร้าน',
              importance: Importance.max,
              playSound: true,
              sound: RawResourceAndroidNotificationSound('order_ready'),
              enableVibration: true,
              showBadge: true,
            ),
          );
    }

    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: true,
            requestBadgePermission: true,
            requestSoundPermission: true,
          ),
        );

    await _localNotif.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {},
    );

    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    FirebaseMessaging.onMessage.listen((message) {
      showLocalNotification(message);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((message) {});

    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) {}
  }

  static Future<void> showLocalNotification(RemoteMessage message) async {
    final title =
        message.data['title'] ?? message.notification?.title ?? '🔔 แจ้งเตือน';
    final body = message.data['body'] ?? message.notification?.body ?? '';

    if (title.isEmpty && body.isEmpty) return;

    if (Platform.isAndroid) {
      await _localNotif.show(
        id: message.hashCode.abs(),
        title: title,
        body: body,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'order_ready_channel',
            'Order Ready',
            channelDescription: 'แจ้งเตือนเมื่ออาหารพร้อมให้รับที่ร้าน',
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
            sound: RawResourceAndroidNotificationSound('order_ready'),
            enableVibration: true,
            icon: '@mipmap/ic_launcher',
            channelShowBadge: true,
          ),
        ),
      );
    } else {
      await _localNotif.show(
        id: message.hashCode.abs(),
        title: title,
        body: body,
        notificationDetails: const NotificationDetails(
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
      );
    }
  }

  static Future<void> saveToken(String uid) async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || uid.isEmpty) return;

      await FirebaseFirestore.instance.collection('buyers').doc(uid).update({
        'fcmToken': token,
      });

      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
        FirebaseFirestore.instance.collection('buyers').doc(uid).update({
          'fcmToken': newToken,
        });
      });
    } catch (e) {
      print('Error saving FCM token: $e');
    }
  }
}
