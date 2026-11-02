import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'cloud.dart';
import 'config.dart';
import 'notifications.dart';
import 'models.dart';
import 'seed.dart';

class StoreScope extends InheritedNotifier<StoreController> {
  const StoreScope(
      {super.key, required StoreController store, required super.child})
      : super(notifier: store);
  static StoreController of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<StoreScope>()!.notifier!;
  static StoreController read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<StoreScope>()!.notifier!;
}

class StoreController extends ChangeNotifier {
  late SharedPreferences prefs;

  List<Product> products = [];
  List<CategoryItem> categories = [];
  List<BannerItem> banners = [];
  List<Coupon> coupons = [];
  List<Review> reviews = [];
  List<AdminUser> admins = [];
  List<String> members = [];
  List<Map<String, dynamic>> orders = []; // my orders
  List<Map<String, dynamic>> cloudOrders = []; // all orders (admin only)
  List<CartLine> cart = [];
  CartLine?
      buyNowLine; // "Buy now" = sirf ek product ka order, cart ko touch nahi karta
  Set<int> favourites = {};
  StoreSettings settings = StoreSettings();

  String customerName = '',
      customerEmail = '',
      phone = '',
      address = '',
      pincode = '',
      city = '';
  String? appliedCoupon;
  String membershipUntil = '';
  int supportTries = 0;
  bool adminUnlocked = false;
  bool dark = false;
  String noticesSeen = '';
  bool _pinTried = false;

  // login (Supabase)
  String authUserId = '', authEmail = '', _refresh = '';
  DateTime _tokenTime = DateTime.fromMillisecondsSinceEpoch(0);
  Timer? _catalogTimer;

  String selectedBrand = 'All';
  String sort = 'Featured';

  // ------------------------------------------------------------ LOAD / SAVE
  List<T> _readList<T>(
      String key, T Function(Map<String, dynamic>) f, List<T> Function() seed) {
    final raw = prefs.getString(key);
    if (raw == null) return seed();
    try {
      return (jsonDecode(raw) as List)
          .map((e) => f(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return seed();
    }
  }

  Future<void> load() async {
    prefs = await SharedPreferences.getInstance();
    products = _readList('z2_products', Product.fromJson, seedProducts);
    categories =
        _readList('z2_categories', CategoryItem.fromJson, seedCategories);
    banners = _readList('z2_banners', BannerItem.fromJson, seedBanners);
    coupons = _readList('z2_coupons', Coupon.fromJson, seedCoupons);
    reviews = _readList('z2_reviews', Review.fromJson, () => <Review>[]);
    admins = _readList('z2_admins', AdminUser.fromJson, seedAdmins);
    cart = _readList('z2_cart', CartLine.fromJson, () => <CartLine>[]);
    orders = _readList<Map<String, dynamic>>(
        'z_orders', (m) => m, () => <Map<String, dynamic>>[]);
    try {
      members = List<String>.from(
          jsonDecode(prefs.getString('z2_members') ?? '[]') as List);
      favourites = (jsonDecode(prefs.getString('z_favourites') ?? '[]') as List)
          .map((e) => (e as num).toInt())
          .toSet();
      final s = prefs.getString('z2_settings');
      if (s != null)
        settings = StoreSettings.fromJson(
            Map<String, dynamic>.from(jsonDecode(s) as Map));
    } catch (_) {}
    customerName = prefs.getString('z_name') ?? '';
    customerEmail = prefs.getString('z_email') ?? '';
    phone = prefs.getString('z_phone') ?? '';
    address = prefs.getString('z_address') ?? '';
    pincode = prefs.getString('z_pin') ?? '';
    city = prefs.getString('z_city') ?? '';
    membershipUntil = prefs.getString('z3_member_until') ?? '';
    supportTries = prefs.getInt('z2_support') ?? 0;
    appliedCoupon = prefs.getString('z2_coupon');
    dark = prefs.getBool('z3_dark') ?? false;
    noticesSeen = prefs.getString('z3_notice_seen') ?? '';
    authUserId = prefs.getString('z3_uid') ?? '';
    authEmail = prefs.getString('z3_auth_email') ?? '';
    _refresh = prefs.getString('z3_refresh') ?? '';
    // make sure an owner always exists
    if (!admins.any((a) => a.role == 'owner'))
      admins.insert(0, seedAdmins().first);
  }

  Future<void> _save() async {
    String enc(List l) => jsonEncode(l);
    await prefs.setString(
        'z2_products', enc(products.map((e) => e.toJson()).toList()));
    await prefs.setString(
        'z2_categories', enc(categories.map((e) => e.toJson()).toList()));
    await prefs.setString(
        'z2_banners', enc(banners.map((e) => e.toJson()).toList()));
    await prefs.setString(
        'z2_coupons', enc(coupons.map((e) => e.toJson()).toList()));
    await prefs.setString(
        'z2_reviews', enc(reviews.map((e) => e.toJson()).toList()));
    await prefs.setString(
        'z2_admins', enc(admins.map((e) => e.toJson()).toList()));
    await prefs.setString('z2_cart', enc(cart.map((e) => e.toJson()).toList()));
    await prefs.setString('z_orders', enc(orders));
    await prefs.setString('z2_members', enc(members));
    await prefs.setString('z_favourites', enc(favourites.toList()));
    await prefs.setString('z2_settings', jsonEncode(settings.toJson()));
    await prefs.setString('z_name', customerName);
    await prefs.setString('z_email', customerEmail);
    await prefs.setString('z_phone', phone);
    await prefs.setString('z_address', address);
    await prefs.setString('z_pin', pincode);
    await prefs.setString('z_city', city);
    await prefs.setString('z3_member_until', membershipUntil);
    await prefs.setInt('z2_support', supportTries);
    await prefs.setBool('z3_dark', dark);
    await prefs.setString('z3_notice_seen', noticesSeen);
    await prefs.setString('z3_uid', authUserId);
    await prefs.setString('z3_auth_email', authEmail);
    await prefs.setString('z3_refresh', _refresh);
    if (appliedCoupon == null) {
      await prefs.remove('z2_coupon');
    } else {
      await prefs.setString('z2_coupon', appliedCoupon!);
    }
  }

  /// Call after changing anything.
  Future<void> commit() async {
    notifyListeners();
    await _save();
    if (isAdmin && adminUnlocked && AppConfig.supabaseReady && isLoggedIn)
      _scheduleCatalogPush();
  }

  // ------------------------------------------------------------ THEME
  Future<void> setDark(bool v) async {
    dark = v;
    await commit();
  }

  // ------------------------------------------------------------ LOGIN
  bool get isLoggedIn => authUserId.isNotEmpty;

  /// Supabase set hai aur user login nahi => login zaroori
  bool get needsLogin => AppConfig.supabaseReady && !isLoggedIn;

  void _setSession(AuthSession s) {
    authUserId = s.userId;
    authEmail = s.email;
    if (s.refreshToken.isNotEmpty) _refresh = s.refreshToken;
    Cloud.setToken(s.accessToken);
    _tokenTime = DateTime.now();
  }

  Future<void> _fresh() async {
    if (!AppConfig.supabaseReady || _refresh.isEmpty) return;
    if (DateTime.now().difference(_tokenTime).inMinutes < 50) return;
    final s = await Cloud.refresh(_refresh);
    if (s != null) _setSession(s);
  }

  Future<String?> login(String email, String password) async {
    final r = await Cloud.signIn(email.trim(), password);
    if (!r.ok) return r.error;
    if (r.data == null) return 'Login failed. Please try again.';
    await _afterLogin(r.data!, '');
    return null;
  }

  Future<String?> loginWithGoogleIdToken(String idToken) async {
    final r = await Cloud.signInWithGoogleIdToken(idToken);
    if (!r.ok) return r.error;
    if (r.data == null) return 'Google login failed. Please try again.';
    await _afterLogin(r.data!, r.data!.name);
    return null;
  }

  /// null = done, 'CONFIRM' = email confirm karna baaki, warna error text
  Future<String?> signup(String name, String email, String password) async {
    final r = await Cloud.signUp(email.trim(), password, name.trim());
    if (!r.ok) return r.error;
    if (r.data == null) return 'CONFIRM';
    await _afterLogin(r.data!, name.trim());
    return null;
  }

  Future<void> _afterLogin(AuthSession s, String fallbackName) async {
    _setSession(s);
    final nm = s.name.isNotEmpty ? s.name : fallbackName;
    if (nm.isNotEmpty) customerName = nm;
    customerEmail = s.email;
    orders = [];
    membershipUntil = '';
    await commit();
    await syncCloud();
    final deviceTokenError = await PushNotifications.registerCurrentDevice();
    print('POST-LOGIN DEVICE TOKEN SAVE: ${deviceTokenError ?? "SUCCESS"}');
  }

  Future<void> logout() async {
    await Cloud.signOut();
    Cloud.setToken(null);
    authUserId = '';
    authEmail = '';
    _refresh = '';
    adminUnlocked = false;
    buyNowLine = null;
    cloudOrders = [];
    orders = [];
    membershipUntil = '';
    customerName = '';
    customerEmail = '';
    phone = '';
    address = '';
    await commit();
  }

  // ------------------------------------------------------------ CLOUD SYNC
  Future<void> bootCloud() async {
    if (!AppConfig.supabaseReady) return;
    await syncCloud();
  }

  Map<String, dynamic> _orderFromRow(Map<String, dynamic> r) {
    final d = Map<String, dynamic>.from((r['data'] as Map?) ?? const {});
    d['status'] = '${r['status'] ?? d['status'] ?? 'Placed'}';
    d['id'] = '${r['id']}';
    return d;
  }

  Future<String?> _pushOrder(Map<String, dynamic> o) => Cloud.insert('orders', {
        'id': o['id'],
        'user_id': authUserId,
        'user_email': authEmail,
        'status': o['status'],
        'data': o,
      });

  Future<void> syncCloud() async {
    if (!AppConfig.supabaseReady) return;
    await _fresh();

    // store catalog (products, banners, coupons, settings) - admin ne jo set kiya
    final cat = await Cloud.select('app_data',
        query: {'key': 'eq.catalog', 'select': 'data'});
    if (cat != null) {
      if (cat.isNotEmpty) {
        _applyCatalog(Map<String, dynamic>.from(cat.first['data'] as Map));
      } else if (isAdmin && isLoggedIn) {
        await _pushCatalog();
      }
    }

    // reviews (sabko dikhte hain)
    final rv = await Cloud.select('reviews', query: {
      'select': 'product_id,user_id,name,rating,body,created_at',
      'order': 'created_at.asc'
    });
    if (rv != null) {
      reviews = rv
          .map((r) => Review(
                productId: ((r['product_id'] ?? 0) as num).toInt(),
                rating: ((r['rating'] ?? 5) as num).toInt(),
                name: '${r['name'] ?? 'Customer'}',
                text: '${r['body'] ?? ''}',
                date: '${r['created_at'] ?? ''}',
                uid: '${r['user_id'] ?? ''}',
              ))
          .toList();
    }

    if (isLoggedIn) {
      // pehle jo orders push nahi ho paye the
      final pending = orders.where((o) => o['pending'] == true).toList();
      for (final o in pending) {
        if (await _pushOrder(o) == null) o.remove('pending');
      }
      final mine = await Cloud.select('orders', query: {
        'select': 'id,status,data,created_at',
        'user_id': 'eq.$authUserId',
        'order': 'created_at.desc'
      });
      if (mine != null) {
        final fetched = mine.map(_orderFromRow).toList();
        final stillPending = orders
            .where((o) =>
                o['pending'] == true && !fetched.any((f) => f['id'] == o['id']))
            .toList();
        orders = [...stillPending, ...fetched];
      }
      final m = await Cloud.select('memberships', query: {
        'select': 'user_id,active_until',
        'user_id': 'eq.$authUserId'
      });
      if (m != null)
        membershipUntil = m.isEmpty ? '' : '${m.first['active_until']}';

      if (isAdmin) {
        final all = await Cloud.select('orders', query: {
          'select': 'id,status,data,created_at',
          'order': 'created_at.desc',
          'limit': '500'
        });
        if (all != null) cloudOrders = all.map(_orderFromRow).toList();
        final mm = await Cloud.select('memberships',
            query: {'select': 'user_id,active_until'});
        if (mm != null) {
          members = mm
              .where((e) =>
                  (DateTime.tryParse('${e['active_until']}') ?? DateTime(2000))
                      .isAfter(DateTime.now()))
              .map((e) => '${e['user_id']}')
              .toList();
        }
      }
    }
    notifyListeners();
    await _save();
  }

  Map<String, dynamic> _catalogJson() => {
        'products': products.map((e) => e.toJson()).toList(),
        'categories': categories.map((e) => e.toJson()).toList(),
        'banners': banners.map((e) => e.toJson()).toList(),
        'coupons': coupons.map((e) => e.toJson()).toList(),
        'settings': settings.toJson(),
      };

  void _applyCatalog(Map<String, dynamic> j) {
    try {
      List<T> list<T>(String k, T Function(Map<String, dynamic>) f) =>
          (j[k] as List)
              .map((e) => f(Map<String, dynamic>.from(e as Map)))
              .toList();
      final p = list('products', Product.fromJson);
      final c = list('categories', CategoryItem.fromJson);
      final b = list('banners', BannerItem.fromJson);
      final cp = list('coupons', Coupon.fromJson);
      final st = StoreSettings.fromJson(
          Map<String, dynamic>.from(j['settings'] as Map));
      products = p;
      categories = c;
      banners = b;
      coupons = cp;
      settings = st;
    } catch (_) {}
  }

  Future<void> _pushCatalog() async {
    await _fresh();
    await Cloud.insert(
        'app_data',
        {
          'key': 'catalog',
          'data': _catalogJson(),
          'updated_at': DateTime.now().toUtc().toIso8601String()
        },
        upsert: true);
  }

  void _scheduleCatalogPush() {
    _catalogTimer?.cancel();
    _catalogTimer = Timer(const Duration(seconds: 2), _pushCatalog);
  }

  // ------------------------------------------------------------ SETTINGS / ROLE
  Color get accent => settings.accentColor;

  AdminUser? get currentAdmin {
    if (AppConfig.isAdminEmail(authEmail)) {
      return AdminUser(
          name: customerName.isEmpty ? 'Owner' : customerName,
          phone: phone,
          pin: AppConfig.adminPin,
          role: 'owner');
    }
    if (phone.isEmpty) return null;
    for (final a in admins) {
      if (a.phone.isNotEmpty && a.phone == phone) return a;
    }
    return null;
  }

  bool get isAdmin => currentAdmin != null;
  bool get isOwner => currentAdmin?.role == 'owner';

  bool unlockAdmin(String pin) {
    final a = currentAdmin;
    if (a != null && a.pin == pin) {
      adminUnlocked = true;
      notifyListeners();
      return true;
    }
    return false;
  }

  void lockAdmin() {
    adminUnlocked = false;
    notifyListeners();
  }

  // ------------------------------------------------------------ CATALOG
  Product? productById(int id) {
    for (final p in products) {
      if (p.id == id) return p;
    }
    return null;
  }

  int get nextProductId => products.isEmpty
      ? 101
      : products.map((e) => e.id).reduce((a, b) => a > b ? a : b) + 1;

  List<String> get brands {
    final out = <String>[];
    for (final p in products) {
      if (p.active && p.brand.isNotEmpty && !out.contains(p.brand))
        out.add(p.brand);
    }
    return out;
  }

  String iconKeyFor(String category) {
    for (final c in categories) {
      if (c.name == category) return c.icon;
    }
    return 'bag';
  }

  List<Product> listProducts(
      {String category = 'All',
      String brand = 'All',
      String q = '',
      String? sortBy}) {
    final qq = q.toLowerCase().trim();
    final list = products
        .where((p) =>
            p.active &&
            (category == 'All' || p.category == category) &&
            (brand == 'All' || p.brand == brand) &&
            (qq.isEmpty ||
                '${p.name} ${p.brand} ${p.category}'
                    .toLowerCase()
                    .contains(qq)))
        .toList();
    final so = sortBy ?? sort;
    if (so == 'Price: Low to High')
      list.sort((a, b) => a.price.compareTo(b.price));
    if (so == 'Price: High to Low')
      list.sort((a, b) => b.price.compareTo(a.price));
    if (so == 'Top Rated')
      list.sort((a, b) => ratingOf(b.id).compareTo(ratingOf(a.id)));
    return list;
  }

  void setBrand(String b) {
    selectedBrand = b;
    notifyListeners();
  }

  void setSort(String s) {
    sort = s;
    notifyListeners();
  }

  // ------------------------------------------------------------ REVIEWS
  List<Review> reviewsOf(int pid) =>
      reviews.where((r) => r.productId == pid).toList().reversed.toList();

  double ratingOf(int pid) {
    final l = reviews.where((r) => r.productId == pid).toList();
    if (l.isEmpty) return 0;
    return l.fold<int>(0, (a, r) => a + r.rating) / l.length;
  }

  String get _myUid => authUserId.isEmpty ? 'local' : authUserId;

  /// Kya is user ne ye product order kiya hai (cancelled chhodke)?
  bool hasPurchased(int pid) {
    for (final o in orders) {
      if (o['status'] == 'Cancelled') continue;
      for (final raw in ((o['items'] as List?) ?? const [])) {
        final it = raw as Map;
        if (((it['pid'] ?? it['id'] ?? 0) as num).toInt() == pid) return true;
      }
    }
    return false;
  }

  bool hasReviewed(int pid) =>
      reviews.any((r) => r.productId == pid && r.uid == _myUid);

  bool canReview(int pid) => hasPurchased(pid) && !hasReviewed(pid);

  /// null = ok, warna error message
  Future<String?> addReview(int pid, int rating, String text) async {
    if (!hasPurchased(pid))
      return 'Only customers who ordered this product can review it.';
    if (hasReviewed(pid)) return 'You have already reviewed this product.';
    final nm = customerName.isEmpty ? 'Customer' : customerName;
    if (AppConfig.supabaseReady && isLoggedIn) {
      await _fresh();
      final err = await Cloud.insert('reviews', {
        'product_id': pid,
        'user_id': authUserId,
        'name': nm,
        'rating': rating,
        'body': text
      });
      if (err != null) return err;
    }
    reviews.add(Review(
        productId: pid,
        rating: rating,
        name: nm,
        text: text,
        date: DateTime.now().toIso8601String(),
        uid: _myUid));
    await commit();
    return null;
  }

  // ------------------------------------------------------------ FAVOURITES
  Future<void> toggleFavourite(int id) async {
    favourites.contains(id) ? favourites.remove(id) : favourites.add(id);
    await commit();
  }

  // ------------------------------------------------------------ MEMBERSHIP
  DateTime? get membershipEnds => DateTime.tryParse(membershipUntil)?.toLocal();
  bool get isMember => membershipEnds?.isAfter(DateTime.now()) ?? false;
  int get memberDaysLeft =>
      isMember ? membershipEnds!.difference(DateTime.now()).inDays + 1 : 0;

  Future<void> activateMembership(String paymentId) async {
    final base = isMember ? membershipEnds! : DateTime.now();
    membershipUntil = base
        .add(const Duration(days: AppConfig.membershipDays))
        .toUtc()
        .toIso8601String();
    if (!members.contains(authUserId.isEmpty ? 'device-user' : authUserId))
      members.add(authUserId.isEmpty ? 'device-user' : authUserId);
    if (AppConfig.supabaseReady && isLoggedIn) {
      await _fresh();
      await Cloud.insert(
          'memberships',
          {
            'user_id': authUserId,
            'active_until': membershipUntil,
            'payment_id': paymentId
          },
          upsert: true);
    }
    await commit();
  }

  // ------------------------------------------------------------ CART + PRICING
  List<CartLine> get cartLines =>
      cart.where((l) => productById(l.pid) != null).toList();

  /// Buy now chal raha ho to sirf wahi ek product, warna poora cart
  List<CartLine> get activeLines {
    final b = buyNowLine;
    if (b != null && productById(b.pid) != null) return [b];
    return cartLines;
  }

  int get itemCount => cartLines.fold(0, (a, l) => a + l.qty);
  int get subtotal =>
      activeLines.fold(0, (a, l) => a + productById(l.pid)!.price * l.qty);

  // Membership ab discount nahi, free + fast delivery deti hai
  int get memberPct => 0;
  int get potentialPct => 0;
  int get memberDiscount => 0;

  Coupon? get coupon {
    if (appliedCoupon == null) return null;
    for (final c in coupons) {
      if (c.code.toLowerCase() == appliedCoupon!.toLowerCase()) return c;
    }
    return null;
  }

  int get couponDiscount => coupon?.discountFor(subtotal) ?? 0;

  /// Delivery fee jo non-member ko lagti
  int get normalShipping => subtotal == 0 || subtotal >= settings.freeShipAbove
      ? 0
      : settings.shippingFee;
  int get shipping => isMember ? 0 : normalShipping;
  int get total => subtotal - couponDiscount + shipping;
  int get etaDays => isMember ? settings.etaDaysMember : settings.etaDays;

  Future<void> addToCart(int pid, {String size = '', String color = ''}) async {
    final k = CartLine(pid: pid, size: size, color: color).key;
    final i = cart.indexWhere((l) => l.key == k);
    if (i >= 0) {
      cart[i].qty += 1;
    } else {
      cart.add(CartLine(pid: pid, size: size, color: color));
    }
    await commit();
  }

  void startBuyNow(int pid, {String size = '', String color = ''}) {
    buyNowLine = CartLine(pid: pid, size: size, color: color);
    notifyListeners();
  }

  void endBuyNow() {
    buyNowLine = null; // notify nahi (dispose ke time safe)
  }

  Future<void> setQty(CartLine l, int q) async {
    if (q <= 0) {
      cart.removeWhere((x) => x.key == l.key);
    } else {
      l.qty = q;
    }
    await commit();
  }

  Future<String?> applyCoupon(String code) async {
    final c = code.trim().toLowerCase();
    for (final x in coupons) {
      if (x.code.toLowerCase() == c && x.active) {
        if (subtotal < x.minOrder)
          return 'Add items worth ₹${x.minOrder - subtotal} more to use this coupon';
        appliedCoupon = x.code;
        await commit();
        return null;
      }
    }
    return 'Invalid or expired coupon';
  }

  Future<void> removeCoupon() async {
    appliedCoupon = null;
    await commit();
  }

  // ------------------------------------------------------------ PROFILE
  Future<void> saveProfile(
      {String? name,
      String? email,
      String? mobile,
      String? addr,
      String? pin,
      String? town}) async {
    if (name != null) customerName = name;
    if (email != null) customerEmail = email;
    if (mobile != null) phone = mobile;
    if (addr != null) address = addr;
    if (pin != null) pincode = pin;
    if (town != null) city = town;
    if (!isAdmin) adminUnlocked = false;
    await commit();
  }

  // ------------------------------------------------------------ PIN CODE
  Future<String?> lookupPin(String pin) async {
    try {
      final r = await http
          .get(Uri.parse('https://api.postalpincode.in/pincode/$pin'))
          .timeout(const Duration(seconds: 7));
      final j = jsonDecode(r.body) as List;
      final first = j.first as Map;
      if (first['Status'] == 'Success') {
        final po = (first['PostOffice'] as List).first as Map;
        return '${po['District']}';
      }
    } catch (_) {}
    return null;
  }

  Future<void> setPin(String pin) async {
    final town = await lookupPin(pin);
    pincode = pin;
    if (town != null) city = town;
    await commit();
  }

  /// Approximate auto-detect using the network location (no permission needed)
  Future<bool> autoDetectPin() async {
    try {
      final r = await http
          .get(Uri.parse('https://ipapi.co/json/'))
          .timeout(const Duration(seconds: 7));
      if (r.statusCode != 200) return false;
      final j = jsonDecode(r.body) as Map<String, dynamic>;
      final p = '${j['postal'] ?? ''}'.replaceAll(RegExp(r'\D'), '');
      if (p.length == 6) {
        pincode = p;
        city = '${j['city'] ?? city}';
        await commit();
        return true;
      }
    } catch (_) {}
    return false;
  }

  Future<void> autoPinOnce() async {
    if (pincode.isNotEmpty || _pinTried) return;
    _pinTried = true;
    await autoDetectPin();
  }

  // ------------------------------------------------------------ ORDERS
  Map<String, dynamic>? orderById(String id) {
    for (final o in orders) {
      if (o['id'] == id) return o;
    }
    for (final o in cloudOrders) {
      if (o['id'] == id) return o;
    }
    return null;
  }

  /// Admin ko saare customers ke orders (cloud se), warna apne orders
  List<Map<String, dynamic>> get adminOrders =>
      cloudOrders.isNotEmpty ? cloudOrders : orders;

  /// Payment se pehle stock check
  String? stockIssue() {
    for (final l in activeLines) {
      final p = productById(l.pid)!;
      if (p.stock < l.qty) return '${p.name}: only ${p.stock} left in stock';
    }
    return null;
  }

  Future<String?> placeOrder(String payment, {String paymentId = ''}) async {
    final lines = activeLines;
    if (lines.isEmpty) return 'Your cart is empty';
    final issue = stockIssue();
    if (issue != null) return issue;
    final single = buyNowLine != null;
    final now = DateTime.now();
    final items = lines.map((l) {
      final p = productById(l.pid)!;
      p.stock -= l.qty;
      return {
        'pid': p.id,
        'name': p.name,
        'brand': p.brand,
        'size': l.size,
        'color': l.color,
        'qty': l.qty,
        'price': p.price
      };
    }).toList();
    final order = <String, dynamic>{
      'id': 'ZV${now.millisecondsSinceEpoch.toString().substring(6)}',
      'date': now.toIso8601String(),
      'items': items,
      'subtotal': subtotal,
      'memberDiscount': 0,
      'couponDiscount': couponDiscount,
      'coupon': appliedCoupon ?? '',
      'shipping': shipping,
      'total': total,
      'payment': payment,
      'paymentId': paymentId,
      'status': 'Placed',
      'history': [
        {'status': 'Placed', 'date': now.toIso8601String()}
      ],
      'name': customerName,
      'phone': phone,
      'email': customerEmail,
      'address': '$address, $city - $pincode',
      'member': isMember,
    };
    orders.insert(0, order);
    if (single) {
      buyNowLine = null;
    } else {
      cart.clear();
    }
    appliedCoupon = null;
    if (AppConfig.supabaseReady && isLoggedIn) {
      await _fresh();
      final err = await _pushOrder(order);
      if (err != null) order['pending'] = true; // net aate hi dobara push hoga
    }
    await commit();
    return 'OK:${order['id']}';
  }

  Future<void> setOrderStatus(String id, String status) async {
    final o = orderById(id);
    if (o == null || o['status'] == status) return;
    final wasCancelled = o['status'] == 'Cancelled';
    final h = List<dynamic>.from((o['history'] as List?) ?? const []);
    h.add({'status': status, 'date': DateTime.now().toIso8601String()});
    for (final list in [orders, cloudOrders]) {
      for (final x in list) {
        if (x['id'] == id) {
          x['status'] = status;
          x['history'] = h;
        }
      }
    }
    // stock handling
    if (status == 'Cancelled' && !wasCancelled) {
      for (final raw in (o['items'] as List)) {
        final it = raw as Map;
        final pid = ((it['pid'] ?? it['id'] ?? 0) as num).toInt();
        final p = productById(pid);
        if (p != null) p.stock += ((it['qty'] ?? 0) as num).toInt();
      }
    }
    if (AppConfig.supabaseReady && isLoggedIn) {
      await _fresh();
      final data = Map<String, dynamic>.from(o)..remove('pending');
      await Cloud.update(
          'orders', {'id': 'eq.$id'}, {'status': status, 'data': data});
    }
    await commit();
  }

  // ------------------------------------------------------------ SUPPORT
  Future<void> trackSupport() async {
    supportTries += 1;
    await commit();
  }

  // ------------------------------------------------------------ NOTIFICATIONS
  static const Map<String, String> _statusText = {
    'Placed': 'Your order has been placed.',
    'Confirmed': 'Your order is confirmed.',
    'Packed': 'Your order is packed and ready to ship.',
    'Shipped': 'Your order has been shipped.',
    'Out for delivery': 'Your order is out for delivery today.',
    'Delivered': 'Your order was delivered. Share a review!',
    'Cancelled': 'Your order was cancelled.',
  };

  List<AppNotice> get notices {
    final out = <AppNotice>[];
    for (final o in orders) {
      for (final raw in ((o['history'] as List?) ?? const [])) {
        final h = raw as Map;
        final st = '${h['status']}';
        out.add(AppNotice(
            kind: 'order',
            title: 'Order #${o['id']} · $st',
            body: _statusText[st] ?? st,
            date: '${h['date']}'));
      }
    }
    if (isAdmin) {
      for (final o
          in adminOrders.where((o) => o['status'] == 'Placed').take(20)) {
        out.add(AppNotice(
            kind: 'admin',
            title: 'New order #${o['id']}',
            body: '${o['name'] ?? 'Customer'} · ₹${o['total']}',
            date: '${o['date']}'));
      }
    }
    if (isMember && memberDaysLeft <= 3) {
      out.add(AppNotice(
          kind: 'member',
          title: '${AppConfig.membershipName} ends soon',
          body:
              'Renew for ₹${AppConfig.membershipPrice} to keep free delivery.',
          date: DateTime.now().toIso8601String()));
    }
    out.sort((a, b) => b.date.compareTo(a.date));
    for (final c in coupons.where((c) => c.active && c.notify)) {
      out.add(AppNotice(
          kind: 'offer',
          title: '${c.label} · ${c.code}',
          body: c.title.isEmpty ? 'Special offer' : c.title));
    }
    return out;
  }

  int get unreadNotices {
    final n = notices;
    var c = n
        .where((x) => x.date.isNotEmpty && x.date.compareTo(noticesSeen) > 0)
        .length;
    if (noticesSeen.isEmpty) c += n.where((x) => x.kind == 'offer').length;
    return c;
  }

  Future<void> markNoticesSeen() async {
    noticesSeen = DateTime.now().toIso8601String();
    await commit();
  }

  // ------------------------------------------------------------ DASHBOARD
  int get ordersCount => adminOrders.length;
  int get cancelledCount =>
      adminOrders.where((o) => o['status'] == 'Cancelled').length;
  int get revenue => adminOrders
      .where((o) => o['status'] != 'Cancelled')
      .fold(0, (a, o) => a + ((o['total'] ?? 0) as num).toInt());
  int get stockUnits => products.fold(0, (a, p) => a + p.stock);
  List<Product> get lowStock =>
      products.where((p) => p.stock > 0 && p.stock <= 5).toList();
  List<Product> get outOfStock => products.where((p) => p.stock <= 0).toList();
  List<Coupon> get notifications =>
      coupons.where((c) => c.active && c.notify).toList();
}
