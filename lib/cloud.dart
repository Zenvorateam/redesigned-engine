import 'dart:convert';
import 'package:http/http.dart' as http;
import 'config.dart';

/// Chhota Supabase REST client (auth + tables). Extra package ki zarurat nahi.
class AuthSession {
  final String accessToken, refreshToken, userId, email, name;
  const AuthSession({required this.accessToken, required this.refreshToken, required this.userId, required this.email, this.name = ''});
}

class CloudResult<T> {
  final T? data;
  final String? error;
  const CloudResult.ok(this.data) : error = null;
  const CloudResult.fail(this.error) : data = null;
  bool get ok => error == null;
}

class Cloud {
  static String? _token;
  static void setToken(String? t) => _token = t;

  static Map<String, String> _headers({bool json = true, String? prefer}) => {
        'apikey': AppConfig.supabaseAnonKey,
        'Authorization': 'Bearer ${_token ?? AppConfig.supabaseAnonKey}',
        if (json) 'Content-Type': 'application/json',
        if (prefer != null) 'Prefer': prefer,
      };

  static Uri _u(String path, [Map<String, String>? q]) => Uri.parse('${AppConfig.supabaseUrl}$path').replace(queryParameters: q);

  static String _err(http.Response r) {
    try {
      final j = jsonDecode(r.body);
      if (j is Map) {
        return '${j['msg'] ?? j['message'] ?? j['error_description'] ?? j['error'] ?? 'Something went wrong'}';
      }
    } catch (_) {}
    return 'Something went wrong (${r.statusCode})';
  }

  static AuthSession? _session(Map<String, dynamic> j) {
    final at = j['access_token'];
    final user = j['user'];
    if (at == null || user is! Map) return null;
    final meta = (user['user_metadata'] as Map?) ?? const {};
    return AuthSession(
      accessToken: '$at',
      refreshToken: '${j['refresh_token'] ?? ''}',
      userId: '${user['id']}',
      email: '${user['email'] ?? ''}',
      name: '${meta['name'] ?? ''}',
    );
  }

  // ------------------------------------------------------------ AUTH
  /// ok(null) => account bana, par email confirm karna baaki hai.
  static Future<CloudResult<AuthSession?>> signUp(String email, String password, String name) async {
    if (!AppConfig.supabaseReady) return const CloudResult.fail('Supabase keys config.dart me add karo');
    try {
      final r = await http
          .post(_u('/auth/v1/signup'), headers: _headers(), body: jsonEncode({'email': email, 'password': password, 'data': {'name': name}}))
          .timeout(const Duration(seconds: 15));
      if (r.statusCode >= 300) return CloudResult.fail(_err(r));
      return CloudResult.ok(_session(jsonDecode(r.body) as Map<String, dynamic>));
    } catch (_) {
      return const CloudResult.fail('Internet check karo');
    }
  }

  static Future<CloudResult<AuthSession?>> signIn(String email, String password) async {
    if (!AppConfig.supabaseReady) return const CloudResult.fail('Supabase keys config.dart me add karo');
    try {
      final r = await http
          .post(_u('/auth/v1/token', {'grant_type': 'password'}), headers: _headers(), body: jsonEncode({'email': email, 'password': password}))
          .timeout(const Duration(seconds: 15));
      if (r.statusCode >= 300) return CloudResult.fail(_err(r));
      return CloudResult.ok(_session(jsonDecode(r.body) as Map<String, dynamic>));
    } catch (_) {
      return const CloudResult.fail('Internet check karo');
    }
  }

  /// Sign in to Supabase using a Google ID token obtained from google_sign_in.
  static Future<CloudResult<AuthSession?>> signInWithGoogleIdToken(String idToken) async {
    if (!AppConfig.supabaseReady) return const CloudResult.fail('Supabase keys config.dart me add karo');
    try {
      final r = await http.post(
        _u('/auth/v1/token', {'grant_type': 'id_token'}),
        headers: _headers(),
        body: jsonEncode({'provider': 'google', 'id_token': idToken}),
      ).timeout(const Duration(seconds: 20));
      if (r.statusCode >= 300) return CloudResult.fail(_err(r));
      return CloudResult.ok(_session(jsonDecode(r.body) as Map<String, dynamic>));
    } catch (_) {
      return const CloudResult.fail('Google sign-in network error');
    }
  }

  static Future<AuthSession?> refresh(String refreshToken) async {
    if (!AppConfig.supabaseReady || refreshToken.isEmpty) return null;
    try {
      final r = await http
          .post(_u('/auth/v1/token', {'grant_type': 'refresh_token'}), headers: _headers(), body: jsonEncode({'refresh_token': refreshToken}))
          .timeout(const Duration(seconds: 15));
      if (r.statusCode >= 300) return null;
      return _session(jsonDecode(r.body) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  static Future<void> signOut() async {
    if (!AppConfig.supabaseReady || _token == null) return;
    try {
      await http.post(_u('/auth/v1/logout'), headers: _headers()).timeout(const Duration(seconds: 8));
    } catch (_) {}
  }

  // ------------------------------------------------------------ TABLE HELPERS
  static Future<List<Map<String, dynamic>>?> select(String table, {Map<String, String>? query}) async {
    if (!AppConfig.supabaseReady) return null;
    try {
      final r = await http.get(_u('/rest/v1/$table', query), headers: _headers(json: false)).timeout(const Duration(seconds: 15));
      if (r.statusCode >= 300) return null;
      return (jsonDecode(r.body) as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return null;
    }
  }

  /// null => ok, warna error message
  static Future<String?> insert(String table, Map<String, dynamic> row, {bool upsert = false}) async {
    if (!AppConfig.supabaseReady) return 'Supabase not configured';
    try {
      final r = await http
          .post(_u('/rest/v1/$table'), headers: _headers(prefer: upsert ? 'resolution=merge-duplicates,return=minimal' : 'return=minimal'), body: jsonEncode(row))
          .timeout(const Duration(seconds: 15));
      return r.statusCode >= 300 ? _err(r) : null;
    } catch (_) {
      return 'Internet check karo';
    }
  }

  static Future<String?> update(String table, Map<String, String> filter, Map<String, dynamic> values) async {
    if (!AppConfig.supabaseReady) return 'Supabase not configured';
    try {
      final r = await http
          .patch(_u('/rest/v1/$table', filter), headers: _headers(prefer: 'return=minimal'), body: jsonEncode(values))
          .timeout(const Duration(seconds: 15));
      return r.statusCode >= 300 ? _err(r) : null;
    } catch (_) {
      return 'Internet check karo';
    }
  }
}
