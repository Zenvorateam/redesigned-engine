import 'package:flutter/material.dart';
import 'cloud.dart';
import 'auth.dart';
import 'config.dart';
import 'models.dart';
import 'store.dart';
import 'widgets.dart';
import 'home.dart';
import 'admin.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  Future<void> _openAdmin(BuildContext context, StoreController s) async {
    if (!s.isAdmin || !s.isLoggedIn) return;
    s.unlockAdmin('');
    if (!context.mounted) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminHome()));
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
        if (status.toLowerCase() == 'delivered') ...[
          const SizedBox(height: 14),
          OutlinedButton.icon(onPressed: () async {
            final reason = TextEditingController();
            final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: const Text('Return / replacement request'), content: TextField(controller: reason, maxLines: 3, decoration: const InputDecoration(labelText: 'Reason for return')), actions: [TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Submit'))]));
            if (ok == true && reason.text.trim().isNotEmpty) {
              final result = await Cloud.invokeFunction('return-request', {'order_id':'$orderId','reason':reason.text.trim()});
              if (context.mounted) toast(context, result.ok ? 'Return request submitted' : (result.error ?? 'Could not submit return request'));
            }
            reason.dispose();
          }, icon: const Icon(Icons.assignment_return_outlined), label: const Text('Request return / replacement')),
        ],
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
        const SizedBox(height: 16),
        OutlinedButton.icon(onPressed: () async {
          final subject = TextEditingController(); final detail = TextEditingController();
          final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: const Text('Create support ticket'), content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: subject, decoration: const InputDecoration(labelText: 'Subject')), TextField(controller: detail, maxLines: 3, decoration: const InputDecoration(labelText: 'Describe your issue'))]), actions: [TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Submit'))]));
          if (ok == true && subject.text.trim().isNotEmpty && s.authUserId.isNotEmpty) {
            final err = await Cloud.insert('support_tickets', {'user_id':s.authUserId,'subject':subject.text.trim(),'category':'general'});
            if (context.mounted) toast(context, err ?? 'Support ticket created');
          }
          subject.dispose(); detail.dispose();
        }, icon: const Icon(Icons.add_comment_outlined), label: const Text('Create support ticket')),
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
