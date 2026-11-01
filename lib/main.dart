import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'models.dart';
import 'store.dart';
import 'home.dart';
import 'cart.dart';
import 'account.dart';
import 'widgets.dart';
import 'notifications.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await PushNotifications.initialize();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.white,
    systemNavigationBarIconBrightness: Brightness.dark,
  ));
  final store = StoreController();
  await store.load();
  runApp(ZenvoraApp(store: store));
  store.bootCloud();
}

class ZenvoraApp extends StatelessWidget {
  final StoreController store;
  const ZenvoraApp({super.key, required this.store});

  ThemeData _theme(Color ac, bool dark) => ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: pageBg,
        colorScheme: ColorScheme.light(primary: ac, onPrimary: Colors.white, secondary: ac, surface: Colors.white, onSurface: ink, error: danger),
        appBarTheme: AppBarTheme(
          systemOverlayStyle: dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
          backgroundColor: pageBg,
          foregroundColor: ink,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          titleTextStyle: const TextStyle(color: ink, fontSize: 20, fontWeight: FontWeight.w900),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          hintStyle: const TextStyle(color: muted, fontSize: 13),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: line)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: line)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: ac, width: 1.4)),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: ac,
            foregroundColor: Colors.white,
            disabledBackgroundColor: line,
            disabledForegroundColor: muted,
            minimumSize: const Size(0, 50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: ac,
            side: BorderSide(color: ac),
            minimumSize: const Size(0, 46),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
            textStyle: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        dividerColor: line,
      );

  @override
  Widget build(BuildContext context) => StoreScope(
        store: store,
        child: ListenableBuilder(
          listenable: store,
          builder: (context, _) => MaterialApp(
            title: store.settings.appName,
            debugShowCheckedModeBanner: false,
            theme: _theme(store.accent, store.dark),
            builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
              value: SystemUiOverlayStyle(
                statusBarColor: Colors.transparent,
                statusBarIconBrightness: store.dark ? Brightness.light : Brightness.dark,
                systemNavigationBarColor: store.dark ? Colors.black : Colors.white,
                systemNavigationBarIconBrightness: store.dark ? Brightness.light : Brightness.dark,
              ),
              child: store.dark ? ColorFiltered(colorFilter: kDarkFilter, child: child!) : child!,
            ),
            home: const SplashScreen(),
          ),
        ),
      );
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Timer(const Duration(milliseconds: 1500), () {
      if (mounted) Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const MainShell()));
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const BrandLogo(size: 78),
          const SizedBox(height: 18),
          Text(s.settings.appName.toUpperCase(), style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900, letterSpacing: 2.4)),
          const SizedBox(height: 7),
          Text(s.settings.tagline, style: const TextStyle(color: muted, fontSize: 12, letterSpacing: .4)),
        ]),
      ),
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int index = 0;

  @override
  void initState() {
    super.initState();
    // auto-detect delivery PIN code on first launch
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) StoreScope.read(context).autoPinOnce();
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    const pages = [HomeScreen(), WishlistScreen(), CartScreen(), AccountScreen()];
    const radius = BorderRadius.vertical(top: Radius.circular(28));

    return Scaffold(
      body: SafeArea(bottom: false, child: IndexedStack(index: index, children: pages)),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: radius,
          boxShadow: [BoxShadow(color: Color(0x1A000000), blurRadius: 20, offset: Offset(0, -4))],
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: NavigationBar(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            height: 66,
            indicatorColor: softGradients[3][1],
            selectedIndex: index,
            onDestinationSelected: (v) => setState(() => index = v),
            destinations: [
              const NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Home'),
              const NavigationDestination(icon: Icon(Icons.favorite_border), selectedIcon: Icon(Icons.favorite), label: 'Saved'),
              NavigationDestination(
                icon: Badge(isLabelVisible: s.itemCount > 0, label: Text('${s.itemCount}'), child: const Icon(Icons.shopping_cart_outlined)),
                selectedIcon: const Icon(Icons.shopping_cart),
                label: 'Cart',
              ),
              const NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Account'),
            ],
          ),
        ),
      ),
    );
  }
}
