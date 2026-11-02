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

      final token = await messaging.getToken();
      _currentToken = token;

      print('FCM TOKEN: $token');

      await registerCurrentDevice();

      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        print('Notification received: ${message.notification?.title}');
      });

      FirebaseMessaging.instance.onTokenRefresh.listen((token) async {
        _currentToken = token;
        print('FCM TOKEN REFRESHED: $token');
        await registerCurrentDevice();
      });

      _ready = true;
    } catch (e) {
      print('FCM initialization error: $e');
    }
  }

  static Future<void> registerCurrentDevice() async {
    final token = _currentToken;

    if (token == null || token.isEmpty || !AppConfig.supabaseReady) {
      return;
    }

    await Cloud.insert(
      'device_tokens',
      {
        'token': token,
        'platform': 'android',
      },
      upsert: true,
    );
  }
}
