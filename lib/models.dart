import 'package:flutter/material.dart';
import 'config.dart';

// ---------------------------------------------------------------- OWNER LOGIN
// Pehli baar owner ka phone aur PIN yahan se set hota hai.
// Profile mein ye phone number daalo, phir Account > Admin Panel khulega aur PIN maangega.
// Baad mein Admin > Staff se isko badal sakte ho.
const String kOwnerPhone = AppConfig.ownerPhone;
const String kOwnerPin = AppConfig.adminPin;

// ---------------------------------------------------------------- COLORS
const Color ink = Color(0xFF16181D);
const Color muted = Color(0xFF6B7280);
const Color line = Color(0xFFE5E7EB);
const Color pageBg = Color(0xFFF7F8FA);
const Color danger = Color(0xFFDC2626);
const Color success = Color(0xFF059669);

/// Light gray, light green, light pink, light blue
const List<List<Color>> softGradients = [
  [Color(0xFFF4F5F7), Color(0xFFE4E7EC)],
  [Color(0xFFEBF9F1), Color(0xFFD2F0E0)],
  [Color(0xFFFEEFF5), Color(0xFFF9D9E8)],
  [Color(0xFFEBF3FF), Color(0xFFD5E5FC)],
];

LinearGradient softGradient(int i) => LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: softGradients[i % softGradients.length],
    );

BoxDecoration softBox(int i, {double radius = 18, bool border = true}) => BoxDecoration(
      gradient: softGradient(i),
      borderRadius: BorderRadius.circular(radius),
      border: border ? Border.all(color: const Color(0x14000000)) : null,
    );

const List<MapEntry<String, Color>> accentPalette = [
  MapEntry('Black', Color(0xFF16181D)),
  MapEntry('Navy', Color(0xFF1E3A8A)),
  MapEntry('Emerald', Color(0xFF047857)),
  MapEntry('Plum', Color(0xFF9D174D)),
  MapEntry('Violet', Color(0xFF6D28D9)),
  MapEntry('Teal', Color(0xFF0F766E)),
];

const Map<String, IconData> iconRegistry = {
  'checkroom': Icons.checkroom_outlined,
  'watch': Icons.watch_outlined,
  'home': Icons.chair_outlined,
  'spa': Icons.spa_outlined,
  'devices': Icons.headphones_outlined,
  'beauty': Icons.face_retouching_natural_outlined,
  'kids': Icons.child_care_outlined,
  'shoes': Icons.directions_run_outlined,
  'bag': Icons.shopping_bag_outlined,
  'gift': Icons.card_giftcard_outlined,
  'star': Icons.star_outline,
};

IconData iconFor(String key) => iconRegistry[key] ?? Icons.category_outlined;

const List<String> orderSteps = ['Placed', 'Confirmed', 'Packed', 'Shipped', 'Out for delivery', 'Delivered'];
const List<String> allStatuses = [...orderSteps, 'Cancelled'];

Color statusColor(String s) => s == 'Cancelled' ? danger : (s == 'Delivered' ? success : const Color(0xFF2563EB));

String dateAfter(int days) {
  final d = DateTime.now().add(Duration(days: days));
  const w = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${w[d.weekday - 1]}, ${d.day} ${m[d.month - 1]}';
}

String shortDate(String iso) {
  final d = DateTime.tryParse(iso);
  if (d == null) return '';
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final mm = d.minute.toString().padLeft(2, '0');
  return '${d.day}/${d.month}/${d.year}  $h:$mm ${d.hour >= 12 ? 'PM' : 'AM'}';
}

int _i(dynamic v) => (v as num?)?.toInt() ?? 0;
List<String> splitList(String t) => t.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

// ---------------------------------------------------------------- MODELS
class Product {
  int id;
  String name, brand, category, description, aboutBrand, sku;
  List<String> images, sizes, colors;
  Map<String, String> specs;
  int price, mrp, stock;
  bool active;

  Product({
    required this.id,
    required this.name,
    this.brand = '',
    this.category = '',
    this.description = '',
    this.aboutBrand = '',
    this.sku = '',
    List<String>? images,
    List<String>? sizes,
    List<String>? colors,
    Map<String, String>? specs,
    this.price = 0,
    this.mrp = 0,
    this.stock = 0,
    this.active = true,
  })  : images = images ?? [],
        sizes = sizes ?? [],
        colors = colors ?? [],
        specs = specs ?? {};

  int get discount => mrp > price && mrp > 0 ? ((mrp - price) * 100 / mrp).round() : 0;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'brand': brand,
        'category': category,
        'description': description,
        'aboutBrand': aboutBrand,
        'sku': sku,
        'images': images,
        'sizes': sizes,
        'colors': colors,
        'specs': specs,
        'price': price,
        'mrp': mrp,
        'stock': stock,
        'active': active,
      };

  factory Product.fromJson(Map<String, dynamic> j) => Product(
        id: _i(j['id']),
        name: '${j['name'] ?? ''}',
        brand: '${j['brand'] ?? ''}',
        category: '${j['category'] ?? ''}',
        description: '${j['description'] ?? ''}',
        aboutBrand: '${j['aboutBrand'] ?? ''}',
        sku: '${j['sku'] ?? ''}',
        images: List<String>.from((j['images'] as List?) ?? const []),
        sizes: List<String>.from((j['sizes'] as List?) ?? const []),
        colors: List<String>.from((j['colors'] as List?) ?? const []),
        specs: Map<String, String>.from((j['specs'] as Map?) ?? const {}),
        price: _i(j['price']),
        mrp: _i(j['mrp']),
        stock: _i(j['stock']),
        active: j['active'] != false,
      );
}

class CategoryItem {
  String name, icon;
  CategoryItem({required this.name, this.icon = 'star'});
  Map<String, dynamic> toJson() => {'name': name, 'icon': icon};
  factory CategoryItem.fromJson(Map<String, dynamic> j) =>
      CategoryItem(name: '${j['name'] ?? ''}', icon: '${j['icon'] ?? 'star'}');
}

class BannerItem {
  String image, category; // category = link (empty = no link)
  BannerItem({this.image = '', this.category = ''});
  Map<String, dynamic> toJson() => {'image': image, 'category': category};
  factory BannerItem.fromJson(Map<String, dynamic> j) =>
      BannerItem(image: '${j['image'] ?? ''}', category: '${j['category'] ?? ''}');
}

class Coupon {
  String code, title;
  bool percent, active, notify;
  int value, minOrder;
  Coupon({
    required this.code,
    this.title = '',
    this.percent = true,
    this.value = 10,
    this.minOrder = 0,
    this.active = true,
    this.notify = true,
  });
  int discountFor(int amount) {
    if (!active || amount < minOrder || amount <= 0) return 0;
    final d = percent ? amount * value ~/ 100 : value;
    return d > amount ? amount : d;
  }

  String get label => percent ? '$value% OFF' : '₹$value OFF';
  Map<String, dynamic> toJson() => {
        'code': code,
        'title': title,
        'percent': percent,
        'value': value,
        'minOrder': minOrder,
        'active': active,
        'notify': notify,
      };
  factory Coupon.fromJson(Map<String, dynamic> j) => Coupon(
        code: '${j['code'] ?? ''}',
        title: '${j['title'] ?? ''}',
        percent: j['percent'] != false,
        value: _i(j['value']),
        minOrder: _i(j['minOrder']),
        active: j['active'] != false,
        notify: j['notify'] != false,
      );
}

class Review {
  int productId, rating;
  String name, text, date, uid;
  Review({required this.productId, required this.rating, required this.name, required this.text, required this.date, this.uid = ''});
  Map<String, dynamic> toJson() =>
      {'productId': productId, 'rating': rating, 'name': name, 'text': text, 'date': date, 'uid': uid};
  factory Review.fromJson(Map<String, dynamic> j) => Review(
        productId: _i(j['productId']),
        rating: _i(j['rating']),
        name: '${j['name'] ?? ''}',
        text: '${j['text'] ?? ''}',
        date: '${j['date'] ?? ''}',
        uid: '${j['uid'] ?? ''}',
      );
}

/// In-app notification (order update, offer, membership)
class AppNotice {
  final String kind, title, body, date; // kind: order | offer | member | admin
  const AppNotice({required this.kind, required this.title, required this.body, this.date = ''});
}

class CartLine {
  int pid, qty;
  String size, color;
  CartLine({required this.pid, this.size = '', this.color = '', this.qty = 1});
  String get key => '$pid|$size|$color';
  Map<String, dynamic> toJson() => {'pid': pid, 'size': size, 'color': color, 'qty': qty};
  factory CartLine.fromJson(Map<String, dynamic> j) =>
      CartLine(pid: _i(j['pid']), size: '${j['size'] ?? ''}', color: '${j['color'] ?? ''}', qty: _i(j['qty']));
}

class AdminUser {
  String name, phone, pin, role; // role: owner | staff
  AdminUser({required this.name, required this.phone, required this.pin, this.role = 'staff'});
  Map<String, dynamic> toJson() => {'name': name, 'phone': phone, 'pin': pin, 'role': role};
  factory AdminUser.fromJson(Map<String, dynamic> j) => AdminUser(
        name: '${j['name'] ?? ''}',
        phone: '${j['phone'] ?? ''}',
        pin: '${j['pin'] ?? ''}',
        role: '${j['role'] ?? 'staff'}',
      );
}

class StoreSettings {
  String appName, tagline, footerText, returnPolicy, supportPhone, whatsapp;
  int accent, shippingFee, freeShipAbove, etaDays, etaDaysMember, tier1, pct1, tier2, pct2;
  List<Map<String, String>> footerLinks;

  StoreSettings({
    this.appName = AppConfig.appName,
    this.tagline = 'Good finds. Better living.',
    this.footerText = '© 2026 Zenvora Mart. All rights reserved.',
    this.returnPolicy =
        '7-day easy returns and exchange on unused products with original tags and packaging. Refund is processed within 5-7 working days after pickup.',
    this.supportPhone = '',
    this.whatsapp = '',
    this.accent = 0,
    this.shippingFee = 49,
    this.freeShipAbove = 999,
    this.etaDays = 5,
    this.etaDaysMember = 2,
    this.tier1 = 799,
    this.pct1 = 10,
    this.tier2 = 1599,
    this.pct2 = 15,
    List<Map<String, String>>? footerLinks,
  }) : footerLinks = footerLinks ??
            [
              {'label': 'Privacy Policy', 'url': 'https://example.com/privacy'},
              {'label': 'Terms', 'url': 'https://example.com/terms'},
              {'label': 'Contact', 'url': 'https://example.com/contact'},
            ];

  Color get accentColor => accentPalette[accent % accentPalette.length].value;

  Map<String, dynamic> toJson() => {
        'appName': appName,
        'tagline': tagline,
        'footerText': footerText,
        'returnPolicy': returnPolicy,
        'supportPhone': supportPhone,
        'whatsapp': whatsapp,
        'accent': accent,
        'shippingFee': shippingFee,
        'freeShipAbove': freeShipAbove,
        'etaDays': etaDays,
        'etaDaysMember': etaDaysMember,
        'tier1': tier1,
        'pct1': pct1,
        'tier2': tier2,
        'pct2': pct2,
        'footerLinks': footerLinks,
      };

  factory StoreSettings.fromJson(Map<String, dynamic> j) {
    final d = StoreSettings();
    return StoreSettings(
      appName: '${j['appName'] ?? d.appName}',
      tagline: '${j['tagline'] ?? d.tagline}',
      footerText: '${j['footerText'] ?? d.footerText}',
      returnPolicy: '${j['returnPolicy'] ?? d.returnPolicy}',
      supportPhone: '${j['supportPhone'] ?? ''}',
      whatsapp: '${j['whatsapp'] ?? ''}',
      accent: _i(j['accent']),
      shippingFee: j['shippingFee'] == null ? d.shippingFee : _i(j['shippingFee']),
      freeShipAbove: j['freeShipAbove'] == null ? d.freeShipAbove : _i(j['freeShipAbove']),
      etaDays: j['etaDays'] == null ? d.etaDays : _i(j['etaDays']),
      etaDaysMember: j['etaDaysMember'] == null ? d.etaDaysMember : _i(j['etaDaysMember']),
      tier1: j['tier1'] == null ? d.tier1 : _i(j['tier1']),
      pct1: j['pct1'] == null ? d.pct1 : _i(j['pct1']),
      tier2: j['tier2'] == null ? d.tier2 : _i(j['tier2']),
      pct2: j['pct2'] == null ? d.pct2 : _i(j['pct2']),
      footerLinks: (j['footerLinks'] as List?)?.map((e) => Map<String, String>.from(e as Map)).toList(),
    );
  }
}
