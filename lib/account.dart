import 'package:flutter/material.dart';
import 'auth.dart';
import 'config.dart';
import 'models.dart';
import 'pay.dart';
import 'store.dart';
import 'widgets.dart';
import 'home.dart';
import 'admin.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  Future<void> _openAdmin(BuildContext context, StoreController s) async {
    if (s.adminUnlocked) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminHome()));
      return;
    }
    final c = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Admin PIN'),
        content: TextField(
          controller: c,
          obscureText: true,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(hintText: 'Enter your admin PIN'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, null), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(90, 44)),
            onPressed: () => Navigator.pop(ctx, s.unlockAdmin(c.text.trim())),
            child: const Text('Unlock'),
          ),
        ],
      ),
    );
    c.dispose();
    if (!context.mounted) return;
    if (ok == true) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminHome()));
    } else if (ok == false) {
      toast(context, 'Wrong PIN');
    }
  }

  Future<void> _signOut(BuildContext context, StoreController s) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('You will need to login again to place orders.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sign out', style: TextStyle(color: danger))),
        ],
      ),
    );
    if (yes == true) {
      await s.logout();
      if (context.mounted) toast(context, 'Signed out');
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final ac = accentOf(context);
    final initial = s.customerName.isEmpty ? (s.isLoggedIn ? s.authEmail[0].toUpperCase() : 'G') : s.customerName[0].toUpperCase();
    final active = s.orders.where((o) => o['status'] != 'Delivered' && o['status'] != 'Cancelled').length;
    final guestNeedsLogin = AppConfig.supabaseReady && !s.isLoggedIn;

    return Scaffold(
      appBar: AppBar(title: const Text('Account')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 8), children: [
        // ---- profile
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: line)),
          child: guestNeedsLogin
              ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    const BrandLogo(size: 46),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('Welcome!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 2),
                        Text('Login to order, track and save more.', style: const TextStyle(color: muted, fontSize: 12)),
                      ]),
                    ),
                  ]),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(onPressed: () => ensureLogin(context), child: const Text('Login / Sign up')),
                  ),
                ])
              : Row(children: [
                  CircleAvatar(radius: 28, backgroundColor: ac, child: Text(initial, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900))),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(s.customerName.isEmpty ? 'Welcome!' : s.customerName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 2),
                      if (s.customerEmail.isNotEmpty) Text(s.customerEmail, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: muted, fontSize: 12)),
                      Text(s.phone.isEmpty ? 'Add your mobile number' : '+91 ${s.phone}', style: const TextStyle(color: muted, fontSize: 12)),
                      if (s.isMember)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.workspace_premium_rounded, size: 15, color: Color(0xFFB45309)),
                            const SizedBox(width: 4),
                            Text('${AppConfig.membershipName} member', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFFB45309))),
                          ]),
                        ),
                    ]),
                  ),
                  IconButton(
                    tooltip: 'Edit profile',
                    onPressed: () => showFieldsSheet(context, title: 'Edit profile', fields: [
                      FieldSpec('Full name', initial: s.customerName),
                      FieldSpec('Contact email (optional)', initial: s.customerEmail, type: TextInputType.emailAddress, required: false),
                    ], onSave: (v) => s.saveProfile(name: v[0], email: v[1])),
                    icon: const Icon(Icons.edit_outlined, size: 20),
                  ),
                ]),
        ),
        const SizedBox(height: 12),

        // ---- quick stats
        Container(
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: line)),
          child: IntrinsicHeight(
            child: Row(children: [
              _stat('${s.orders.length}', 'Orders', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OrdersScreen()))),
              VerticalDivider(width: 1, color: line),
              _stat('${s.favourites.length}', 'Saved', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WishlistScreen()))),
              VerticalDivider(width: 1, color: line),
              _stat('${s.notifications.length}', 'Offers', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CouponsScreen()))),
            ]),
          ),
        ),
        const SizedBox(height: 12),

        // ---- membership card
        GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MembershipScreen())),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF16181D), Color(0xFF30343F)]),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(children: [
              const Icon(Icons.workspace_premium_rounded, size: 34, color: Color(0xFFF5B301)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(s.isMember ? '${AppConfig.membershipName} · Active' : AppConfig.membershipName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
                  const SizedBox(height: 3),
                  Text(
                    s.isMember ? 'Free delivery on every order · ${s.memberDaysLeft} days left' : 'Free & faster delivery on every order for ₹${AppConfig.membershipPrice}/month',
                    style: const TextStyle(color: Color(0xCCFFFFFF), fontSize: 12, height: 1.3),
                  ),
                ]),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: const Color(0xFFF5B301), borderRadius: BorderRadius.circular(20)),
                child: Text(s.isMember ? 'Manage' : 'Join', style: const TextStyle(color: Color(0xFF16181D), fontWeight: FontWeight.w900, fontSize: 12)),
              ),
            ]),
          ),
        ),

        // ---- lists
        _label('SHOPPING'),
        _Group(children: [
          _Row(
            icon: Icons.receipt_long_outlined,
            title: 'My orders',
            subtitle: s.orders.isEmpty ? 'No orders yet' : '${s.orders.length} orders · $active in progress',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OrdersScreen())),
          ),
          _Row(
            icon: Icons.favorite_border,
            title: 'Saved products',
            subtitle: '${s.favourites.length} saved items',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WishlistScreen())),
          ),
          _Row(
            icon: Icons.local_offer_outlined,
            title: 'Coupons',
            subtitle: '${s.notifications.length} offers available',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CouponsScreen())),
          ),
          _Row(
            icon: Icons.notifications_none_rounded,
            title: 'Notifications',
            subtitle: s.unreadNotices > 0 ? '${s.unreadNotices} new' : 'Order updates and offers',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen())),
          ),
        ]),

        _label('MY DETAILS'),
        _Group(children: [
          _Row(
            icon: Icons.location_on_outlined,
            title: 'Delivery address',
            subtitle: s.address.isEmpty ? 'Add your delivery address' : '${s.address}, ${s.city} - ${s.pincode}',
            onTap: () => showFieldsSheet(context, title: 'Edit address', fields: [
              FieldSpec('House / street / area', initial: s.address, lines: 2),
              FieldSpec('City', initial: s.city),
              FieldSpec('PIN code', initial: s.pincode, type: TextInputType.number, maxLen: 6, check: pinCheck),
            ], onSave: (v) => s.saveProfile(addr: v[0], town: v[1], pin: v[2])),
          ),
          _Row(
            icon: Icons.phone_outlined,
            title: 'Mobile number',
            subtitle: s.phone.isEmpty ? 'Add your mobile number' : '+91 ${s.phone}',
            onTap: () => showFieldsSheet(context, title: 'Edit phone number', fields: [
              FieldSpec('Mobile number', initial: s.phone, type: TextInputType.phone, maxLen: 10, check: phoneCheck),
            ], onSave: (v) => s.saveProfile(mobile: v[0])),
          ),
        ]),

        _label('PREFERENCES & HELP'),
        _Group(children: [
          _Row(
            icon: s.dark ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
            title: 'Dark mode',
            subtitle: s.dark ? 'On' : 'Off',
            onTap: () => s.setDark(!s.dark),
            trailing: Switch(value: s.dark, onChanged: (v) => s.setDark(v)),
          ),
          _Row(
            icon: Icons.support_agent_outlined,
            title: 'Help & support',
            subtitle: 'Call, WhatsApp and FAQs',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SupportScreen())),
          ),
        ]),

        // ADMIN SECTION: visible only to admins
        if (s.isAdmin) ...[
          _label('STORE MANAGEMENT'),
          _Group(children: [
            _Row(
              icon: Icons.admin_panel_settings_outlined,
              title: 'Admin panel',
              subtitle: s.isOwner ? 'Owner · products, orders, settings' : 'Staff · products, orders',
              onTap: () => _openAdmin(context, s),
            ),
          ]),
        ],

        if (s.isLoggedIn) ...[
          const SizedBox(height: 18),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: danger, side: const BorderSide(color: danger)),
            onPressed: () => _signOut(context, s),
            icon: const Icon(Icons.logout_rounded, size: 18),
            label: const Text('Sign out'),
          ),
        ],
        const SizedBox(height: 12),
        const FooterBlock(),
      ]),
    );
  }

  Widget _stat(String v, String l, VoidCallback onTap) => Expanded(
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Column(children: [
              Text(v, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
              const SizedBox(height: 2),
              Text(l, style: const TextStyle(color: muted, fontSize: 11, fontWeight: FontWeight.w700)),
            ]),
          ),
        ),
      );

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 20, 0, 8),
        child: Text(t, style: const TextStyle(color: muted, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
      );
}

/// Rounded white card jisme rows divider se alag hoti hain
class _Group extends StatelessWidget {
  final List<Widget> children;
  const _Group({required this.children});
  @override
  Widget build(BuildContext context) {
    final items = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      items.add(children[i]);
      if (i != children.length - 1) items.add(Divider(height: 1, indent: 58, color: line));
    }
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: line)),
      child: Column(children: items),
    );
  }
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final VoidCallback onTap;
  final Widget? trailing;
  const _Row({required this.icon, required this.title, required this.subtitle, required this.onTap, this.trailing});
  @override
  Widget build(BuildContext context) => ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 1),
        leading: Icon(icon, size: 22),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
        subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: muted, fontSize: 11)),
        trailing: trailing ?? const Icon(Icons.chevron_right, color: muted),
      );
}

// ------------------------------------------------------------------ ORDERS
class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('My orders')),
      body: s.orders.isEmpty
          ? const EmptyState(title: 'No orders yet', subtitle: 'Your placed orders will appear here.', icon: Icons.receipt_long_outlined)
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: s.orders.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (c, i) {
                final o = s.orders[i];
                final items = (o['items'] as List).map((e) => '${(e as Map)['name'] ?? 'Item'} x${e['qty'] ?? 1}').join(', ');
                return GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => OrderDetailScreen(orderId: '${o['id']}'))),
                  child: Container(
                    padding: const EdgeInsets.all(15),
                    decoration: softBox(i, radius: 18),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Expanded(child: Text('Order #${o['id']}', style: const TextStyle(fontWeight: FontWeight.w900))),
                        Text('₹${o['total']}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                      ]),
                      const SizedBox(height: 4),
                      Text(shortDate('${o['date']}'), style: const TextStyle(color: muted, fontSize: 11)),
                      const SizedBox(height: 8),
                      Text(items, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                      const SizedBox(height: 12),
                      OrderProgress('${o['status']}'),
                      const SizedBox(height: 10),
                      Row(children: [StatusChip('${o['status']}'), const Spacer(), const Text('View details', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)), const Icon(Icons.chevron_right, size: 18)]),
                    ]),
                  ),
                );
              },
            ),
    );
  }
}

class OrderDetailScreen extends StatelessWidget {
  final String orderId;
  const OrderDetailScreen({super.key, required this.orderId});

  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final o = s.orderById(orderId);
    if (o == null) return Scaffold(appBar: AppBar(title: const Text('Order')), body: const EmptyState(title: 'Order not found', subtitle: ''));
    final status = '${o['status']}';
    final ac = accentOf(context);
    final history = ((o['history'] as List?) ?? const []).cast<Map>();
    String dateFor(String st) {
      for (final h in history) {
        if (h['status'] == st) return shortDate('${h['date']}');
      }
      return '';
    }

    final cancelled = status == 'Cancelled';
    final steps = cancelled ? history.map((h) => '${h['status']}').toList() : orderSteps;
    final idx = orderSteps.indexOf(status);
    final canCancel = status == 'Placed' || status == 'Confirmed';

    return Scaffold(
      appBar: AppBar(title: Text('Order #$orderId')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: softBox(3, radius: 18),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(shortDate('${o['date']}'), style: const TextStyle(color: muted, fontSize: 12)),
                const SizedBox(height: 4),
                Text('₹${o['total']}  ·  ${o['payment']}', style: const TextStyle(fontWeight: FontWeight.w900)),
              ]),
            ),
            StatusChip(status),
          ]),
        ),
        const SizedBox(height: 18),
        const Text('Order status', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
        const SizedBox(height: 10),
        ...List.generate(steps.length, (i) {
          final st = steps[i];
          final reached = cancelled ? true : i <= idx;
          final col = st == 'Cancelled' ? danger : (reached ? ac : const Color(0xFFD1D5DB));
          final last = i == steps.length - 1;
          return IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              SizedBox(
                width: 28,
                child: Column(children: [
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(color: reached ? col : Colors.white, shape: BoxShape.circle, border: Border.all(color: col, width: 2)),
                    child: reached ? const Icon(Icons.check, size: 12, color: Colors.white) : null,
                  ),
                  if (!last) Expanded(child: Container(width: 2, color: (cancelled || i < idx) ? col : const Color(0xFFE5E7EB))),
                ]),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(st, style: TextStyle(fontWeight: reached ? FontWeight.w900 : FontWeight.w600, color: reached ? ink : muted)),
                    if (dateFor(st).isNotEmpty) Text(dateFor(st), style: const TextStyle(color: muted, fontSize: 11)),
                  ]),
                ),
              ),
            ]),
          );
        }),
        const SizedBox(height: 8),
        const Text('Items', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
        const SizedBox(height: 10),
        ...(o['items'] as List).map((raw) {
          final it = raw as Map;
          final extra = [if ('${it['size'] ?? ''}'.isNotEmpty) 'Size ${it['size']}', if ('${it['color'] ?? ''}'.isNotEmpty) '${it['color']}'].join(' · ');
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${it['name'] ?? 'Item'}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                  if (extra.isNotEmpty) Text(extra, style: const TextStyle(color: muted, fontSize: 11)),
                ]),
              ),
              Text('x${it['qty'] ?? 1}', style: const TextStyle(color: muted)),
              const SizedBox(width: 14),
              Text(it['price'] == null ? '' : '₹${it['price']}', style: const TextStyle(fontWeight: FontWeight.w800)),
            ]),
          );
        }),
        const Divider(height: 28),
        if (o['subtotal'] != null) PriceRow(label: 'Subtotal', value: '₹${o['subtotal']}'),
        if (((o['couponDiscount'] ?? 0) as num) > 0) PriceRow(label: 'Coupon ${o['coupon'] ?? ''}', value: '-₹${o['couponDiscount']}', color: success),
        if (o['shipping'] != null) PriceRow(label: 'Delivery', value: ((o['shipping'] as num) == 0) ? 'FREE' : '₹${o['shipping']}'),
        PriceRow(label: 'Total', value: '₹${o['total']}', bold: true),
        const SizedBox(height: 18),
        const Text('Delivery address', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        Text('${o['name'] ?? ''}\n${o['address'] ?? ''}\n+91 ${o['phone'] ?? ''}', style: const TextStyle(color: Color(0xFF4B5563), height: 1.5, fontSize: 13)),
        if (canCancel) ...[
          const SizedBox(height: 20),
          OutlinedButton(
            style: OutlinedButton.styleFrom(foregroundColor: danger, side: const BorderSide(color: danger)),
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Cancel order?'),
                  content: const Text('This cannot be undone.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
                    TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Yes, cancel')),
                  ],
                ),
              );
              if (ok == true) await s.setOrderStatus(orderId, 'Cancelled');
            },
            child: const Text('Cancel order'),
          ),
        ],
      ]),
    );
  }
}

// ------------------------------------------------------------------ MEMBERSHIP
class MembershipScreen extends StatefulWidget {
  const MembershipScreen({super.key});
  @override
  State<MembershipScreen> createState() => _MembershipScreenState();
}

class _MembershipScreenState extends State<MembershipScreen> {
  bool busy = false;

  Future<void> _buy(StoreController s) async {
    if (!await ensureLogin(context)) return;
    if (!AppConfig.razorpayReady) {
      if (mounted) toast(context, 'Payments are not set up yet. Add the Razorpay key in config.dart');
      return;
    }
    setState(() => busy = true);
    final r = await payWithRazorpay(
      amountRupees: AppConfig.membershipPrice,
      description: '${AppConfig.membershipName} · ${AppConfig.membershipDays} days',
      name: s.customerName,
      email: s.customerEmail,
      phone: s.phone,
    );
    if (r.ok) await s.activateMembership(r.paymentId);
    if (!mounted) return;
    setState(() => busy = false);
    toast(context, r.ok ? '${AppConfig.membershipName} is active. Enjoy free delivery!' : r.message);
  }

  Widget _benefit(IconData icon, String title, String sub) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: line)),
            child: Icon(icon, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
              const SizedBox(height: 2),
              Text(sub, style: const TextStyle(color: muted, fontSize: 12, height: 1.4)),
            ]),
          ),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final st = s.settings;
    final member = s.isMember;
    const gold = Color(0xFFF5B301);
    final ends = s.membershipEnds;

    return Scaffold(
      appBar: AppBar(title: Text(AppConfig.membershipName)),
      body: Column(children: [
        Expanded(
          child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 20), children: [
            // hero
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF16181D), Color(0xFF353A46)]),
                borderRadius: BorderRadius.circular(26),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Icon(Icons.workspace_premium_rounded, color: gold, size: 30),
                  const SizedBox(width: 10),
                  Text(AppConfig.membershipName.toUpperCase(), style: const TextStyle(color: gold, fontWeight: FontWeight.w900, letterSpacing: 2.2, fontSize: 14)),
                  const Spacer(),
                  if (member)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: const Color(0x33F5B301), borderRadius: BorderRadius.circular(20)),
                      child: const Text('ACTIVE', style: TextStyle(color: gold, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1)),
                    ),
                ]),
                const SizedBox(height: 22),
                Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('₹${AppConfig.membershipPrice}', style: const TextStyle(color: Colors.white, fontSize: 46, fontWeight: FontWeight.w900, height: 1)),
                  const Padding(padding: EdgeInsets.only(bottom: 6, left: 6), child: Text('/ month', style: TextStyle(color: Color(0xB3FFFFFF), fontSize: 15))),
                ]),
                const SizedBox(height: 10),
                Text(
                  member && ends != null
                      ? 'Active till ${shortDate(ends.toIso8601String()).split('  ').first}  ·  ${s.memberDaysLeft} days left'
                      : 'Free delivery on every product, as long as your membership is active.',
                  style: const TextStyle(color: Color(0xCCFFFFFF), fontSize: 13, height: 1.4),
                ),
              ]),
            ),
            const SizedBox(height: 18),
            const Text('What you get', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            _benefit(Icons.local_shipping_outlined, 'FREE delivery on every product', 'No delivery charges on any order, any amount. Normally ₹${st.shippingFee} on orders below ₹${st.freeShipAbove}.'),
            _benefit(Icons.bolt_rounded, 'Faster delivery', 'Get your orders in ${st.etaDaysMember} days instead of ${st.etaDays}.'),
            _benefit(Icons.verified_outlined, 'Works automatically', 'Your benefits apply in the cart and at checkout. Nothing to enter.'),
            if (st.shippingFee >= AppConfig.membershipPrice)
              Container(
                margin: const EdgeInsets.only(top: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: line)),
                child: Row(children: [
                  const Icon(Icons.savings_outlined, size: 22, color: success),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('Pays for itself with just one order. You save ₹${st.shippingFee} on every delivery.', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, height: 1.4)),
                  ),
                ]),
              ),
            const SizedBox(height: 14),
            Text(
              'One-time payment of ₹${AppConfig.membershipPrice} for ${AppConfig.membershipDays} days. No auto-renewal. Buying again while active adds ${AppConfig.membershipDays} more days.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: muted, fontSize: 11, height: 1.5),
            ),
          ]),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          decoration: BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: line))),
          child: SafeArea(
            top: false,
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: busy ? null : () => _buy(s),
                child: Text(busy ? 'Please wait...' : (member ? 'Extend by ${AppConfig.membershipDays} days · ₹${AppConfig.membershipPrice}' : 'Join now · ₹${AppConfig.membershipPrice}/month')),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

// ------------------------------------------------------------------ COUPONS
class CouponsScreen extends StatelessWidget {
  const CouponsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final list = s.coupons.where((c) => c.active).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Coupons')),
      body: list.isEmpty
          ? const EmptyState(title: 'No coupons available', subtitle: 'Check back soon for new offers.', icon: Icons.local_offer_outlined)
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (c, i) => CouponCard(coupon: list[i], index: i),
            ),
    );
  }
}

// ------------------------------------------------------------------ SUPPORT
class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final st = s.settings;

    Future<void> contact(String kind) async {
      await s.trackSupport(); // counts for admin dashboard
      if (kind == 'call') {
        if (st.supportPhone.isEmpty) {
          if (context.mounted) toast(context, 'Support number is not available right now');
          return;
        }
        await openUrl('tel:${st.supportPhone}');
      } else {
        var n = (st.whatsapp.isEmpty ? st.supportPhone : st.whatsapp).replaceAll(RegExp(r'\D'), '');
        if (n.isEmpty) {
          if (context.mounted) toast(context, 'WhatsApp support is not available right now');
          return;
        }
        if (n.length == 10) n = '91$n';
        await openUrl('https://wa.me/$n?text=Hi%2C%20I%20need%20help');
      }
    }

    const faqs = [
      ['How long does delivery take?', 'Usually 3-5 days. Members get faster delivery and free delivery on every order.'],
      ['How do I return a product?', 'Returns are accepted on unused products as per the return policy shown on each product page.'],
      ['Can I cancel my order?', 'Yes. Open My orders and cancel while the order is Placed or Confirmed.'],
      ['How does membership work?', 'Join for ₹${AppConfig.membershipPrice}/month and get free, faster delivery on every order. See the Membership page.'],
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Help & support')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Row(children: [
          Expanded(
            child: GestureDetector(
              onTap: () => contact('call'),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 20),
                decoration: softBox(3, radius: 18),
                child: const Column(children: [Icon(Icons.call_outlined, size: 28), SizedBox(height: 8), Text('Call us', style: TextStyle(fontWeight: FontWeight.w900))]),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: () => contact('wa'),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 20),
                decoration: softBox(1, radius: 18),
                child: const Column(children: [Icon(Icons.chat_outlined, size: 28), SizedBox(height: 8), Text('WhatsApp', style: TextStyle(fontWeight: FontWeight.w900))]),
              ),
            ),
          ),
        ]),
        const SizedBox(height: 22),
        const Text('Frequently asked questions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        ...faqs.map((f) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(border: Border.all(color: line), borderRadius: BorderRadius.circular(16)),
              child: Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  title: Text(f[0], style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                  expandedCrossAxisAlignment: CrossAxisAlignment.start,
                  children: [Text(f[1], style: const TextStyle(color: Color(0xFF4B5563), height: 1.5, fontSize: 13))],
                ),
              ),
            )),
      ]),
    );
  }
}
