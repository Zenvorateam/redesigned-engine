import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'cloud.dart';
import 'config.dart';

class PushNotifications {
  static bool _ready = false;
  static String? _currentToken;

  static Future<void> initialize() async {
    if (!AppConfig.enablePushNotifications || _ready) return;

    try {
      await Firebase.initializeApp();

      final messaging = FirebaseMessaging.instance;

      await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      _currentToken = await messaging.getToken();

      print('FCM TOKEN: $_currentToken');

      final error = await registerCurrentDevice();
      print('DEVICE TOKEN SAVE RESULT: ${error ?? "SUCCESS"}');

      FirebaseMessaging.onMessage.listen((message) {
        print('Notification received: ${message.notification?.title}');
      });

      FirebaseMessaging.instance.onTokenRefresh.listen((token) async {
        _currentToken = token;
        print('FCM TOKEN REFRESHED: $token');

        final refreshError = await registerCurrentDevice();
        print('DEVICE TOKEN SAVE RESULT: ${refreshError ?? "SUCCESS"}');
      });

      _ready = true;
    } catch (e) {
      print('FCM initialization error: $e');
    }
  }

  static Future<String?> registerCurrentDevice() async {
    final token = _currentToken;

    if (token == null || token.isEmpty) {
      return 'FCM token is null or empty';
    }

    if (!AppConfig.supabaseReady) {
      return 'Supabase is not configured';
    }

    return Cloud.insert(
      'device_tokens',
      {
        'token': token,
        'platform': 'android',
      },
      upsert: true,
    );
  }
}
