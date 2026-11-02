// =====================================================================
//  ZENVORA MART  -  CONFIG FILE
//  Saari keys / logo / admin yahin add karo. Baaki code ko chhedna nahi hai.
// =====================================================================

class AppConfig {
  // ---------------------------------------------------------------- APP
  static const String appName = 'Zenvora Mart';

  // ---------------------------------------------------------------- LOGO
  // Option 1: internet link (https://...png)      -> logoUrl me daalo
  // Option 2: assets/logo.png (pubspec me already folder added hai)
  //           -> file rakho `assets/logo/logo.png` aur logoAsset me wahi path daalo
  // Dono khali chhodoge to "Z" letter wala default logo dikhega.
  static const String logoUrl = ''; // Use the bundled Zenvora logo by default.
  static const String logoAsset = 'assets/logo/logo.png'; // e.g. 'assets/logo/logo.png'

  // ---------------------------------------------------------------- SUPABASE
  // Supabase > Project Settings > API
  static const String supabaseUrl = 'https://bpvfbzkefyqocmqdggtb.supabase.co'; // https://xxxxx.supabase.co
  static const String supabaseAnonKey = 'sb_publishable_WeJBU8u6xUXtXDfwEMRfDg_j_5tgHCn'; // anon public key (service_role KEY KABHI MAT DAALNA)

  // ---------------------------------------------------------------- GOOGLE / FIREBASE
  // Google Cloud OAuth Web Client ID (Supabase Google provider ka Web Client ID).
  static const String googleWebClientId = '887357388211-bp8t5hpi8gq6upaih1d0d32khae6chim.apps.googleusercontent.com';
  // FCM admin token registration is stored against the signed-in user.
  static const bool enablePushNotifications = true;

  // ---------------------------------------------------------------- RAZORPAY
  // Razorpay Key ID is returned by the trusted Edge Function. Secrets stay server-side.
  static const String razorpayMerchantName = 'Zenvora Mart';

  // ---------------------------------------------------------------- ADMIN
  // Ye email se login karne wale log Admin panel dekhenge.
  // Supabase me bhi wahi email `admins` table me daalna (supabase/setup.sql dekho).
  static const List<String> adminEmails = ['kajgarvarad@gmail.com'
    // 'you@example.com',
  ];

  // ---------------------------------------------------------------- HELPERS
  static bool get supabaseReady => supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
  static bool isAdminEmail(String email) =>
      email.isNotEmpty && adminEmails.any((e) => e.trim().toLowerCase() == email.trim().toLowerCase());
}
