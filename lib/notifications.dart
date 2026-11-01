import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'cloud.dart';
import 'config.dart';

/// FCM bootstrap. Native Firebase config (google-services.json) is required.
class PushNotifications {
  static bool _ready = false;
  static String? _currentToken;

  static Future<void> initialize() async {
    if (!AppConfig.enablePushNotifications || _ready) return;
    try {
      await Firebase.initializeApp();
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(alert: true, badge: true, sound: true);
      final token = await messaging.getToken();
      _currentToken = token;
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        // Foreground display can be wired to local notifications in the next pass.
      });
      FirebaseMessaging.instance.onTokenRefresh.listen((token) async {
        _currentToken = token;
        await registerCurrentDevice();
      });
      _ready = true;
    } catch (_) {
      // App remains usable when Firebase config has not been added yet.
    }
  }

  static Future<void> registerCurrentDevice() async {
    final token = _currentToken;
    if (token == null || token.isEmpty || !AppConfig.supabaseReady) return;
    await Cloud.insert('device_tokens', {'token': token, 'platform': 'android'}, upsert: true);
  }
}
