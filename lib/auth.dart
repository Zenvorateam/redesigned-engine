import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'config.dart';
import 'models.dart';
import 'store.dart';
import 'widgets.dart';

/// Login zaroori ho to AuthScreen kholta hai. true = ab logged-in (ya login ki zarurat nahi).
Future<bool> ensureLogin(BuildContext context) async {
  final s = StoreScope.read(context);
  if (!s.needsLogin) return true;
  final ok = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => const AuthScreen()));
  return ok == true;
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final name = TextEditingController();
  final email = TextEditingController();
  final pass = TextEditingController();
  bool signup = false, busy = false, hide = true;
  String error = '', info = '';

  @override
  void dispose() {
    name.dispose();
    email.dispose();
    pass.dispose();
    super.dispose();
  }

  Future<void> _googleLogin() async {
    if (AppConfig.googleWebClientId.isEmpty) {
      setState(() => error = 'config.dart me Google Web Client ID add karo.');
      return;
    }
    setState(() { busy = true; error = ''; info = ''; });
    try {
      final google = GoogleSignIn(serverClientId: AppConfig.googleWebClientId);
      final account = await google.signIn();
      if (account == null) { if (mounted) setState(() => busy = false); return; }
      final auth = await account.authentication;
      final token = auth.idToken;
      if (token == null) throw Exception('Google ID token nahi mila. Web Client ID check karo.');
      final result = await StoreScope.read(context).loginWithGoogleIdToken(token);
      if (!mounted) return;
      if (result == null) { Navigator.pop(context, true); }
      else { setState(() { busy = false; error = result; }); }
    } catch (e) {
      if (mounted) setState(() { busy = false; error = e.toString().replaceFirst('Exception: ', ''); });
    }
  }

  Future<void> _submit() async {
    final s = StoreScope.read(context);
    final e = email.text.trim();
    if (signup && name.text.trim().isEmpty) {
      setState(() => error = 'Please enter your name');
      return;
    }
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(e)) {
      setState(() => error = 'Enter a valid email address');
      return;
    }
    if (pass.text.length < 6) {
      setState(() => error = 'Password must be at least 6 characters');
      return;
    }
    setState(() {
      busy = true;
      error = '';
      info = '';
    });
    final r = signup ? await s.signup(name.text, e, pass.text) : await s.login(e, pass.text);
    if (!mounted) return;
    if (r == null) {
      Navigator.pop(context, true);
    } else if (r == 'CONFIRM') {
      setState(() {
        busy = false;
        signup = false;
        info = 'Account created! Check your email, confirm it, then login.';
      });
    } else {
      setState(() {
        busy = false;
        error = r;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.fromLTRB(24, 8, 24, 24), children: [
          const Center(child: BrandLogo(size: 64)),
          const SizedBox(height: 18),
          Center(child: Text(signup ? 'Create your account' : 'Welcome back', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900))),
          const SizedBox(height: 6),
          Center(
            child: Text(signup ? 'Sign up to order, track and get member benefits.' : 'Login to continue shopping on ${StoreScope.of(context).settings.appName}.',
                textAlign: TextAlign.center, style: const TextStyle(color: muted, fontSize: 13)),
          ),
          const SizedBox(height: 26),
          if (!AppConfig.supabaseReady)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(border: Border.all(color: danger), borderRadius: BorderRadius.circular(12)),
              child: const Text('Supabase keys config.dart me add karo, tab login chalega.', style: TextStyle(color: danger, fontSize: 12)),
            ),
          if (signup) ...[
            TextField(controller: name, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Full name', prefixIcon: Icon(Icons.person_outline, size: 20))),
            const SizedBox(height: 12),
          ],
          TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email address', prefixIcon: Icon(Icons.mail_outline, size: 20))),
          const SizedBox(height: 12),
          TextField(
            controller: pass,
            obscureText: hide,
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock_outline, size: 20),
              suffixIcon: IconButton(onPressed: () => setState(() => hide = !hide), icon: Icon(hide ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 20)),
            ),
          ),
          if (error.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 10), child: Text(error, style: const TextStyle(color: danger, fontSize: 12))),
          if (info.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 10), child: Text(info, style: const TextStyle(color: success, fontSize: 12, fontWeight: FontWeight.w700))),
          const SizedBox(height: 18),
          FilledButton(onPressed: busy ? null : _submit, child: Text(busy ? 'Please wait...' : (signup ? 'Create account' : 'Login'))),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: busy ? null : _googleLogin,
            icon: const Icon(Icons.g_mobiledata, size: 26),
            label: const Text('Continue with Google'),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: busy
                ? null
                : () => setState(() {
                      signup = !signup;
                      error = '';
                      info = '';
                    }),
            child: Text(signup ? 'Already have an account? Login' : 'New here? Create an account'),
          ),
        ]),
      ),
    );
  }
}
