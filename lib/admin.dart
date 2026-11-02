import 'package:flutter/material.dart';
import 'models.dart';
import 'store.dart';
import 'widgets.dart';
import 'config.dart';
import 'admin_ops.dart';

// ------------------------------------------------------------------ HELPERS
Widget _tf(TextEditingController c, String label, {TextInputType? type, int lines = 1, String? hint}) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        keyboardType: type,
        maxLines: lines,
        decoration: InputDecoration(labelText: label, hintText: hint, alignLabelWithHint: lines > 1),
      ),
    );

Widget _h(String t) => Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 10),
      child: Text(t, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
    );

int _n(TextEditingController c, [int fallback = 0]) => int.tryParse(c.text.trim()) ?? fallback;

Widget _chip(BuildContext context, String label, bool on, VoidCallback onTap) {
  final ac = accentOf(context);
  return GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(color: on ? ac : Colors.white, borderRadius: BorderRadius.circular(30), border: Border.all(color: on ? ac : line)),
      child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: on ? Colors.white : ink)),
    ),
  );
}

Future<bool> _confirm(BuildContext context, String title, String msg) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(msg),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Yes')),
      ],
    ),
  );
  return r == true;
}

Future<void> adminSheet(
  BuildContext context, {
  required String title,
  required List<Widget> Function(StateSetter setS) body,
  required Future<String?> Function() onSave,
  String saveLabel = 'Save',
}) async {
  String err = '';
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 14),
            ...body(setS),
            if (err.isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(err, style: const TextStyle(color: danger, fontSize: 12))),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () async {
                  final e = await onSave();
                  if (e != null) {
                    setS(() => err = e);
                    return;
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: Text(saveLabel),
              ),
            ),
          ]),
        ),
      ),
    ),
  );
}

// ------------------------------------------------------------------ ADMIN HOME + DASHBOARD
class AdminHome extends StatelessWidget {
  const AdminHome({super.key});

  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    if (!s.isAdmin || !s.adminUnlocked) {
      return Scaffold(appBar: AppBar(title: const Text('Admin panel')), body: const EmptyState(title: 'Access denied', subtitle: 'Admin login required.', icon: Icons.lock_outline));
    }

    Widget menu(IconData icon, String title, String sub, int g, Widget page) {
      final permission = <String, String>{
        'Products':'products.manage','Categories':'settings.manage','Banners':'settings.manage','Orders':'orders.manage',
        'Returns & replacements':'returns.manage','Refund management':'refunds.manage','Customer support':'support.manage',
        'X-Admin & Staff access':'admins.manage','Suppliers & supply chain':'suppliers.manage','Supplier payments':'suppliers.manage',
        'Membership plans':'membership.manage','Customer messages':'messages.send','Business analytics':'analytics.view',
        'Coupons & notifications':'coupons.manage','Payment receipts':'receipts.view','Product return policies':'products.manage','Backup & restore':'audit.view','Store settings':'settings.manage'
      }[title] ?? 'settings.manage';
      if (!s.canManage(permission)) return const SizedBox.shrink();
      return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: line)),
          child: ListTile(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => page)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            leading: Container(width: 42, height: 42, decoration: softBox(g, radius: 13), child: Icon(icon, size: 20, color: ink)),
            title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
            subtitle: Text(sub, style: const TextStyle(color: muted, fontSize: 11)),
            trailing: const Icon(Icons.chevron_right, color: muted),
          ),
        );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin panel'),
        actions: [
          TextButton.icon(
            onPressed: () {
              s.lockAdmin();
              Navigator.pop(context);
            },
            icon: const Icon(Icons.lock_outline, size: 16),
            label: const Text('Lock'),
          ),
        ],
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 24), children: [
        Text('Signed in as ${s.currentAdmin?.name ?? ''}  ·  ${s.isOwner ? 'Owner' : 'Staff'}', style: const TextStyle(color: muted, fontSize: 12)),
        _h('Dashboard'),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.35,
          children: [
            _Stat(Icons.receipt_long_outlined, 'Total orders', '${s.ordersCount}', 3, sub: '${s.adminOrders.where((o) => o['status'] == 'Placed').length} new'),
            _Stat(Icons.currency_rupee_rounded, 'Revenue', '₹${s.revenue}', 1),
            _Stat(Icons.reviews_outlined, 'Reviews', '${s.reviews.length}', 2),
            _Stat(Icons.cancel_outlined, 'Cancelled', '${s.cancelledCount}', 0),
            _Stat(Icons.workspace_premium_outlined, 'Members', '${s.members.length}', 2),
            _Stat(Icons.category_outlined, 'Products', '${s.products.length}', 0, sub: '${s.categories.length} categories'),
          ],
        ),
        _h('Manage'),
        menu(Icons.add_box_outlined, 'Products', 'Add, edit, stock, delete', 1, const AdminProductsScreen()),
        menu(Icons.grid_view_outlined, 'Categories', 'Home category slider', 3, const AdminCategoriesScreen()),
        menu(Icons.view_carousel_outlined, 'Banners', 'Slider images and category links', 2, const AdminBannersScreen()),
        menu(Icons.receipt_long_outlined, 'Orders', 'View and update order status', 0, const AdminOrdersScreen()),
        menu(Icons.assignment_return_outlined, 'Returns & replacements', 'Return requests, pickup and decisions', 2, const AdminOpsScreen(title: 'Returns', table: 'return_requests', permission: 'returns.manage', statusField: 'status')),
        menu(Icons.payments_outlined, 'Refund management', 'Payout details, approval and refund records', 1, const AdminOpsScreen(title: 'Refunds', table: 'refund_records', permission: 'refunds.manage', statusField: 'status')),
        menu(Icons.support_agent_outlined, 'Customer support', 'Tickets and customer complaints', 3, const AdminOpsScreen(title: 'Support tickets', table: 'support_tickets', permission: 'support.manage', statusField: 'status')),
        menu(Icons.people_alt_outlined, 'X-Admin & Staff access', 'Manage roles through secure admin function', 0, const AdminAccessScreen()),
        menu(Icons.local_shipping_outlined, 'Suppliers & supply chain', 'Suppliers and partner payments', 2, const AdminOpsScreen(title: 'Suppliers', table: 'suppliers', permission: 'suppliers.manage', fields: ['name','phone','email','notes'])),
        menu(Icons.account_balance_wallet_outlined, 'Supplier payments', 'Record supplier settlements', 1, const AdminOpsScreen(title: 'Supplier payments', table: 'supplier_payments', permission: 'suppliers.manage', fields: ['supplier_id','order_id','amount','status','reference'])),
        menu(Icons.workspace_premium_outlined, 'Membership plans', 'Silver, Gold and Platinum plans', 2, const AdminOpsScreen(title: 'Membership plans', table: 'membership_plans', permission: 'membership.manage', statusField: 'active')),
        menu(Icons.notifications_active_outlined, 'Customer messages', 'In-app announcements and offers', 3, const AdminOpsScreen(title: 'Admin messages', table: 'admin_messages', permission: 'messages.send', fields: ['title','body','target','active'])),
        menu(Icons.analytics_outlined, 'Business analytics', 'Operational counts and performance', 0, const AdminReportsScreen()),
        menu(Icons.local_offer_outlined, 'Coupons & notifications', 'Create offers shown to customers', 1, const AdminCouponsScreen()),
        menu(Icons.receipt_long_outlined, 'Payment receipts', 'Verified payment receipts', 1, const AdminOpsScreen(title: 'Payment receipts', table: 'payment_receipts', permission: 'receipts.view', statusField: '')),
        menu(Icons.policy_outlined, 'Product return policies', 'Returnable, replacement or no return', 2, const AdminOpsScreen(title: 'Product policies', table: 'product_policies', permission: 'products.manage', fields: ['product_id','policy_type','return_days','policy_text'], statusField: '')),
        menu(Icons.backup_outlined, 'Backup & restore', 'Backup configuration and audit history', 3, const AdminOpsScreen(title: 'Audit logs', table: 'audit_logs', permission: 'audit.view', statusField: '')),
        if (s.canManage('settings.manage')) ...[
          menu(Icons.tune_rounded, 'Store settings', 'Theme, colour, text, footer, delivery', 2, const AdminSettingsScreen()),
        ],
        const SizedBox(height: 10),
        Text(
          AppConfig.supabaseReady
              ? 'Cloud sync is ON: products, banners, coupons and settings you save here reach all customers. Orders from all customers appear in Orders.'
              : 'Cloud sync is OFF: add Supabase keys in lib/config.dart so data is shared across devices.',
          style: const TextStyle(color: muted, fontSize: 11, height: 1.4),
        ),
      ]),
    );
  }

  Widget _alert(String name, String msg, Color c) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Expanded(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700))),
          Text(msg, style: TextStyle(color: c, fontSize: 12, fontWeight: FontWeight.w900)),
        ]),
      );
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final String label, value, sub;
  final int g;
  const _Stat(this.icon, this.label, this.value, this.g, {this.sub = ''});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: softBox(g, radius: 18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Icon(icon, size: 20, color: ink),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900))),
            Text(label, style: const TextStyle(color: Color(0xFF374151), fontSize: 12, fontWeight: FontWeight.w700)),
            if (sub.isNotEmpty) Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: muted, fontSize: 10)),
          ]),
        ]),
      );
}

// ------------------------------------------------------------------ PRODUCTS
class AdminProductsScreen extends StatelessWidget {
  const AdminProductsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    return Scaffold(
      appBar: AppBar(title: Text('Products (${s.products.length})')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProductFormScreen())),
        icon: const Icon(Icons.add),
        label: const Text('Add product'),
      ),
      body: s.products.isEmpty
          ? const EmptyState(title: 'No products', subtitle: 'Tap Add product to create one.')
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
              itemCount: s.products.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (c, i) {
                final p = s.products[i];
                return Container(
                  padding: const EdgeInsets.all(10),
                  decoration: softBox(i, radius: 16),
                  child: Row(children: [
                    ProductThumb(product: p),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(p.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                        const SizedBox(height: 3),
                        Text('${p.category} · ₹${p.price} (MRP ₹${p.mrp})', style: const TextStyle(color: muted, fontSize: 11)),
                        const SizedBox(height: 3),
                        Text(p.stock <= 0 ? 'Out of stock' : 'Stock: ${p.stock}${p.active ? '' : '  ·  Hidden'}',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: p.stock <= 0 ? danger : (p.stock <= 5 ? const Color(0xFFD97706) : success))),
                      ]),
                    ),
                    if (s.currentAdmin?.role != 'staff') Column(children: [
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProductFormScreen(product: p))),
                        icon: const Icon(Icons.edit_outlined, size: 20),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: () async {
                          if (await _confirm(context, 'Delete product?', p.name)) {
                            s.products.removeWhere((x) => x.id == p.id);
                            s.favourites.remove(p.id);
                            s.cart.removeWhere((l) => l.pid == p.id);
                            await s.commit();
                          }
                        },
                        icon: const Icon(Icons.delete_outline, size: 20, color: danger),
                      ),
                    ]),
                  ]),
                );
              },
            ),
    );
  }
}

class ProductFormScreen extends StatefulWidget {
  final Product? product;
  const ProductFormScreen({super.key, this.product});
  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  late final TextEditingController name, brand, sku, mrp, price, stock, sizes, colors, details, specs, about;
  late final List<TextEditingController> imgs;
  String category = '';
  bool active = true;
  String err = '';

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    name = TextEditingController(text: p?.name ?? '');
    brand = TextEditingController(text: p?.brand ?? '');
    sku = TextEditingController(text: p?.sku ?? '');
    mrp = TextEditingController(text: p == null ? '' : '${p.mrp}');
    price = TextEditingController(text: p == null ? '' : '${p.price}');
    stock = TextEditingController(text: p == null ? '' : '${p.stock}');
    sizes = TextEditingController(text: p?.sizes.join(', ') ?? '');
    colors = TextEditingController(text: p?.colors.join(', ') ?? '');
    details = TextEditingController(text: p?.description ?? '');
    specs = TextEditingController(text: p?.specs.entries.map((e) => '${e.key}: ${e.value}').join('\n') ?? '');
    about = TextEditingController(text: p?.aboutBrand ?? '');
    imgs = List.generate(6, (i) => TextEditingController(text: (p != null && i < p.images.length) ? p.images[i] : ''));
    category = p?.category ?? '';
    active = p?.active ?? true;
  }

  @override
  void dispose() {
    for (final c in [name, brand, sku, mrp, price, stock, sizes, colors, details, specs, about, ...imgs]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final s = StoreScope.read(context);
    if (name.text.trim().isEmpty) return setState(() => err = 'Product name is required');
    final sp = _n(price);
    if (sp <= 0) return setState(() => err = 'Enter the selling price');
    final mp = _n(mrp) <= 0 ? sp : _n(mrp);
    if (mp < sp) return setState(() => err = 'MRP cannot be lower than the selling price');
    if (category.isEmpty && s.categories.isNotEmpty) category = s.categories.first.name;

    final specMap = <String, String>{};
    for (final line in specs.text.split('\n')) {
      final i = line.indexOf(':');
      if (i > 0 && line.substring(i + 1).trim().isNotEmpty) specMap[line.substring(0, i).trim()] = line.substring(i + 1).trim();
    }
    final images = imgs.map((c) => c.text.trim()).where((e) => e.isNotEmpty).toList();

    Product p = widget.product ?? Product(id: s.nextProductId, name: '');
    p
      ..name = name.text.trim()
      ..brand = brand.text.trim().toUpperCase()
      ..category = category
      ..sku = sku.text.trim().isEmpty ? 'ZN-${p.id}' : sku.text.trim()
      ..price = sp
      ..mrp = mp
      ..stock = _n(stock)
      ..sizes = splitList(sizes.text)
      ..colors = splitList(colors.text)
      ..images = images
      ..description = details.text.trim()
      ..specs = specMap
      ..aboutBrand = about.text.trim()
      ..active = active;
    if (widget.product == null) s.products.insert(0, p);
    await s.commit();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(widget.product == null ? 'Add product' : 'Edit product')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 30), children: [
        _h('Basic'),
        _tf(name, 'Product name'),
        _tf(brand, 'Brand name'),
        const Text('Category', style: TextStyle(color: muted, fontSize: 12, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: s.categories.map((c) => _chip(context, c.name, category == c.name, () => setState(() => category = c.name))).toList()),
        const SizedBox(height: 14),
        _h('Price & stock'),
        Row(children: [
          Expanded(child: _tf(mrp, 'MRP (₹)', type: TextInputType.number)),
          const SizedBox(width: 10),
          Expanded(child: _tf(price, 'Selling price (₹)', type: TextInputType.number)),
        ]),
        Row(children: [
          Expanded(child: _tf(stock, 'Stock quantity', type: TextInputType.number)),
          const SizedBox(width: 10),
          Expanded(child: _tf(sku, 'SKU (optional)')),
        ]),
        _h('Images (URLs, up to 6)'),
        ...List.generate(6, (i) => _tf(imgs[i], 'Image ${i + 1} URL', type: TextInputType.url)),
        _h('Options'),
        _tf(sizes, 'Sizes (comma separated)', hint: 'S, M, L, XL'),
        _tf(colors, 'Colours (comma separated)', hint: 'Black, White, Navy'),
        _h('Content'),
        _tf(details, 'Product details', lines: 4),
        _tf(specs, 'Specification (one per line  Key: Value)', lines: 5, hint: 'Fabric: Cotton\nFit: Regular'),
        _tf(about, 'About the brand', lines: 3),
        SwitchListTile(contentPadding: EdgeInsets.zero, value: active, onChanged: (v) => setState(() => active = v), title: const Text('Visible in store', style: TextStyle(fontWeight: FontWeight.w800))),
        if (err.isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(err, style: const TextStyle(color: danger, fontSize: 12))),
        FilledButton(onPressed: _save, child: Text(widget.product == null ? 'Add product' : 'Save changes')),
      ]),
    );
  }
}

// ------------------------------------------------------------------ CATEGORIES
class AdminCategoriesScreen extends StatelessWidget {
  const AdminCategoriesScreen({super.key});

  Future<void> _edit(BuildContext context, StoreController s, {int? index}) async {
    final item = index == null ? null : s.categories[index];
    final name = TextEditingController(text: item?.name ?? '');
    String icon = item?.icon ?? 'star';
    await adminSheet(
      context,
      title: item == null ? 'Add category' : 'Edit category',
      body: (setS) => [
        _tf(name, 'Category name'),
        const Text('Icon', style: TextStyle(color: muted, fontSize: 12, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: iconRegistry.entries
              .map((e) => GestureDetector(
                    onTap: () => setS(() => icon = e.key),
                    child: Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: icon == e.key ? accentOf(context) : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: icon == e.key ? accentOf(context) : line),
                      ),
                      child: Icon(e.value, color: icon == e.key ? Colors.white : ink),
                    ),
                  ))
              .toList(),
        ),
        const SizedBox(height: 16),
      ],
      onSave: () async {
        final n = name.text.trim();
        if (n.isEmpty) return 'Enter a category name';
        if (s.categories.any((c) => c.name.toLowerCase() == n.toLowerCase() && c != item)) return 'This category already exists';
        if (item == null) {
          s.categories.add(CategoryItem(name: n, icon: icon));
        } else {
          for (final p in s.products) {
            if (p.category == item.name) p.category = n;
          }
          for (final b in s.banners) {
            if (b.category == item.name) b.category = n;
          }
          item.name = n;
          item.icon = icon;
        }
        await s.commit();
        return null;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Categories')),
      floatingActionButton: FloatingActionButton.extended(onPressed: () => _edit(context, s), icon: const Icon(Icons.add), label: const Text('Add category')),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
        itemCount: s.categories.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (c, i) {
          final cat = s.categories[i];
          final count = s.products.where((p) => p.category == cat.name).length;
          return Container(
            decoration: softBox(i, radius: 16),
            child: ListTile(
              leading: Icon(iconFor(cat.icon), color: ink),
              title: Text(cat.name, style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text('$count products', style: const TextStyle(fontSize: 11)),
              onTap: () => _edit(context, s, index: i),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline, color: danger),
                onPressed: () async {
                  if (await _confirm(context, 'Delete category?', '${cat.name} will be removed from the home slider.')) {
                    s.categories.removeAt(i);
                    await s.commit();
                  }
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

// ------------------------------------------------------------------ BANNERS
class AdminBannersScreen extends StatelessWidget {
  const AdminBannersScreen({super.key});

  Future<void> _edit(BuildContext context, StoreController s, {int? index}) async {
    final item = index == null ? null : s.banners[index];
    final url = TextEditingController(text: item?.image ?? '');
    String link = item?.category ?? '';
    await adminSheet(
      context,
      title: item == null ? 'Add banner' : 'Edit banner ${index! + 1}',
      body: (setS) => [
        _tf(url, 'Banner image URL', type: TextInputType.url),
        const Text('On tap, open category', style: TextStyle(color: muted, fontSize: 12, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          _chip(context, 'No link', link.isEmpty, () => setS(() => link = '')),
          ...s.categories.map((c) => _chip(context, c.name, link == c.name, () => setS(() => link = c.name))),
        ]),
        const SizedBox(height: 16),
      ],
      onSave: () async {
        if (item == null) {
          s.banners.add(BannerItem(image: url.text.trim(), category: link));
        } else {
          item.image = url.text.trim();
          item.category = link;
        }
        await s.commit();
        return null;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Banners')),
      floatingActionButton: s.banners.length >= 8 ? null : FloatingActionButton.extended(onPressed: () => _edit(context, s), icon: const Icon(Icons.add), label: const Text('Add banner')),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
        itemCount: s.banners.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (c, i) {
          final b = s.banners[i];
          return GestureDetector(
            onTap: () => _edit(context, s, index: i),
            child: Container(
              decoration: softBox(i + 1, radius: 18),
              clipBehavior: Clip.antiAlias,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(height: 110, width: double.infinity, child: NetImage(url: b.image, fallback: const SizedBox.expand())),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
                  child: Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Banner ${i + 1}', style: const TextStyle(fontWeight: FontWeight.w900)),
                        Text(b.category.isEmpty ? 'No link' : 'Opens: ${b.category}', style: const TextStyle(color: muted, fontSize: 11)),
                      ]),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: danger),
                      onPressed: () async {
                        if (await _confirm(context, 'Delete banner?', 'Banner ${i + 1} will be removed.')) {
                          s.banners.removeAt(i);
                          await s.commit();
                        }
                      },
                    ),
                  ]),
                ),
              ]),
            ),
          );
        },
      ),
    );
  }
}

// ------------------------------------------------------------------ COUPONS
class AdminCouponsScreen extends StatelessWidget {
  const AdminCouponsScreen({super.key});

  Future<void> _edit(BuildContext context, StoreController s, {int? index}) async {
    final item = index == null ? null : s.coupons[index];
    final code = TextEditingController(text: item?.code ?? '');
    final title = TextEditingController(text: item?.title ?? '');
    final value = TextEditingController(text: item == null ? '' : '${item.value}');
    final minOrder = TextEditingController(text: item == null ? '' : '${item.minOrder}');
    bool percent = item?.percent ?? true;
    bool notify = item?.notify ?? true;
    await adminSheet(
      context,
      title: item == null ? 'Add coupon' : 'Edit coupon',
      body: (setS) => [
        _tf(code, 'Coupon code'),
        _tf(title, 'Title (shown to customers)'),
        Wrap(spacing: 8, children: [
          _chip(context, 'Percent %', percent, () => setS(() => percent = true)),
          _chip(context, 'Flat ₹', !percent, () => setS(() => percent = false)),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _tf(value, percent ? 'Discount %' : 'Discount ₹', type: TextInputType.number)),
          const SizedBox(width: 10),
          Expanded(child: _tf(minOrder, 'Min order ₹', type: TextInputType.number)),
        ]),
        SwitchListTile(contentPadding: EdgeInsets.zero, value: notify, onChanged: (v) => setS(() => notify = v), title: const Text('Show in customer notifications')),
      ],
      onSave: () async {
        final cd = code.text.trim().toUpperCase();
        final v = _n(value);
        if (cd.isEmpty) return 'Enter a coupon code';
        if (v <= 0) return 'Enter the discount value';
        if (percent && v > 90) return 'Percent cannot be above 90';
        if (s.coupons.any((c) => c.code == cd && c != item)) return 'This code already exists';
        if (item == null) {
          s.coupons.add(Coupon(code: cd, title: title.text.trim(), percent: percent, value: v, minOrder: _n(minOrder), notify: notify));
        } else {
          item
            ..code = cd
            ..title = title.text.trim()
            ..percent = percent
            ..value = v
            ..minOrder = _n(minOrder)
            ..notify = notify;
        }
        await s.commit();
        return null;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Coupons & notifications')),
      floatingActionButton: FloatingActionButton.extended(onPressed: () => _edit(context, s), icon: const Icon(Icons.add), label: const Text('Add coupon')),
      body: s.coupons.isEmpty
          ? const EmptyState(title: 'No coupons', subtitle: 'Create a coupon to show it to customers.', icon: Icons.local_offer_outlined)
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
              itemCount: s.coupons.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (c, i) {
                final cp = s.coupons[i];
                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: softBox(i + 1, radius: 18),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: Text('${cp.code}  ·  ${cp.label}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15))),
                      IconButton(visualDensity: VisualDensity.compact, icon: const Icon(Icons.edit_outlined, size: 20), onPressed: () => _edit(context, s, index: i)),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.delete_outline, size: 20, color: danger),
                        onPressed: () async {
                          if (await _confirm(context, 'Delete coupon?', cp.code)) {
                            if (s.appliedCoupon == cp.code) s.appliedCoupon = null;
                            s.coupons.removeAt(i);
                            await s.commit();
                          }
                        },
                      ),
                    ]),
                    Text('${cp.title.isEmpty ? 'No title' : cp.title}  ·  Min ₹${cp.minOrder}', style: const TextStyle(color: muted, fontSize: 12)),
                    const SizedBox(height: 6),
                    Row(children: [
                      const Text('Active', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                      Switch(value: cp.active, onChanged: (v) async {
                        cp.active = v;
                        await s.commit();
                      }),
                      const SizedBox(width: 10),
                      const Text('Notify', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                      Switch(value: cp.notify, onChanged: (v) async {
                        cp.notify = v;
                        await s.commit();
                      }),
                    ]),
                  ]),
                );
              },
            ),
    );
  }
}

// ------------------------------------------------------------------ ORDERS
class AdminOrdersScreen extends StatefulWidget {
  const AdminOrdersScreen({super.key});
  @override
  State<AdminOrdersScreen> createState() => _AdminOrdersScreenState();
}

class _AdminOrdersScreenState extends State<AdminOrdersScreen> {
  String filter = 'All';
  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final list = s.adminOrders.where((o) => filter == 'All' || o['status'] == filter).toList();
    return Scaffold(
      appBar: AppBar(title: Text('Orders (${s.adminOrders.length})')),
      body: Column(children: [
        SizedBox(
          height: 46,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: ['All', ...allStatuses].map((x) => Padding(padding: const EdgeInsets.only(right: 8, top: 4, bottom: 4), child: _chip(context, x, filter == x, () => setState(() => filter = x)))).toList(),
          ),
        ),
        Expanded(
          child: list.isEmpty
              ? const EmptyState(title: 'No orders', subtitle: 'Orders will appear here.', icon: Icons.receipt_long_outlined)
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (c, i) {
                    final o = list[i];
                    return GestureDetector(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AdminOrderDetail(orderId: '${o['id']}'))),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: softBox(i, radius: 16),
                        child: Row(children: [
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('#${o['id']}', style: const TextStyle(fontWeight: FontWeight.w900)),
                              const SizedBox(height: 2),
                              Text('${o['name'] ?? ''} · ${o['phone'] ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: muted, fontSize: 12)),
                              Text(shortDate('${o['date']}'), style: const TextStyle(color: muted, fontSize: 11)),
                            ]),
                          ),
                          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                            Text('₹${o['total']}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                            const SizedBox(height: 4),
                            StatusChip('${o['status']}'),
                          ]),
                        ]),
                      ),
                    );
                  },
                ),
        ),
      ]),
    );
  }
}

class AdminOrderDetail extends StatelessWidget {
  final String orderId;
  const AdminOrderDetail({super.key, required this.orderId});
  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final o = s.orderById(orderId);
    if (o == null) return Scaffold(appBar: AppBar(title: const Text('Order')), body: const EmptyState(title: 'Order not found', subtitle: ''));
    final status = '${o['status']}';
    return Scaffold(
      appBar: AppBar(title: Text('Order #$orderId')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: softBox(3, radius: 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [Expanded(child: Text(shortDate('${o['date']}'), style: const TextStyle(color: muted, fontSize: 12))), StatusChip(status)]),
            const SizedBox(height: 8),
            Text('${o['name'] ?? ''}${(o['member'] == true) ? '  (Member)' : ''}', style: const TextStyle(fontWeight: FontWeight.w900)),
            Text('+91 ${o['phone'] ?? ''}', style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 4),
            Text('${o['address'] ?? ''}', style: const TextStyle(color: Color(0xFF4B5563), fontSize: 13, height: 1.4)),
          ]),
        ),
        if (s.currentAdmin?.role != 'staff') ...[
        _h('Update status'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: allStatuses
              .map((x) => _chip(context, x, status == x, () async {
                    if (x == 'Cancelled' && !await _confirm(context, 'Cancel this order?', 'Stock will be returned to inventory.')) return;
                    await s.setOrderStatus(orderId, x);
                  }))
              .toList(),
        ),
        ],
        _h('Items'),
        ...(o['items'] as List).map((raw) {
          final it = raw as Map;
          final extra = [if ('${it['size'] ?? ''}'.isNotEmpty) 'Size ${it['size']}', if ('${it['color'] ?? ''}'.isNotEmpty) '${it['color']}'].join(' · ');
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${it['name'] ?? 'Item'}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                  if (extra.isNotEmpty) Text(extra, style: const TextStyle(color: muted, fontSize: 11)),
                ]),
              ),
              Text('x${it['qty'] ?? 1}', style: const TextStyle(color: muted)),
              const SizedBox(width: 12),
              Text(it['price'] == null ? '' : '₹${it['price']}', style: const TextStyle(fontWeight: FontWeight.w800)),
            ]),
          );
        }),
        const Divider(height: 24),
        if (o['subtotal'] != null) PriceRow(label: 'Subtotal', value: '₹${o['subtotal']}'),
        if (((o['memberDiscount'] ?? 0) as num) > 0) PriceRow(label: 'Membership discount', value: '-₹${o['memberDiscount']}', color: success),
        if (((o['couponDiscount'] ?? 0) as num) > 0) PriceRow(label: 'Coupon ${o['coupon'] ?? ''}', value: '-₹${o['couponDiscount']}', color: success),
        PriceRow(label: 'Total (${o['payment']})', value: '₹${o['total']}', bold: true),
      ]),
    );
  }
}

// ------------------------------------------------------------------ STORE SETTINGS
class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});
  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  late final TextEditingController appName, tagline, logoUrl, ship, free, eta, etaM, t1, p1, t2, p2, supp, wa, ret, footer, links;
  int accent = 0;

  @override
  void initState() {
    super.initState();
    final st = StoreScope.read(context).settings;
    appName = TextEditingController(text: st.appName);
    tagline = TextEditingController(text: st.tagline);
    logoUrl = TextEditingController(text: st.logoUrl);
    ship = TextEditingController(text: '${st.shippingFee}');
    free = TextEditingController(text: '${st.freeShipAbove}');
    eta = TextEditingController(text: '${st.etaDays}');
    etaM = TextEditingController(text: '${st.etaDaysMember}');
    t1 = TextEditingController(text: '${st.tier1}');
    p1 = TextEditingController(text: '${st.pct1}');
    t2 = TextEditingController(text: '${st.tier2}');
    p2 = TextEditingController(text: '${st.pct2}');
    supp = TextEditingController(text: st.supportPhone);
    wa = TextEditingController(text: st.whatsapp);
    ret = TextEditingController(text: st.returnPolicy);
    footer = TextEditingController(text: st.footerText);
    links = TextEditingController(text: st.footerLinks.map((l) => '${l['label']} | ${l['url']}').join('\n'));
    accent = st.accent;
  }

  @override
  void dispose() {
    for (final c in [appName, tagline, logoUrl, ship, free, eta, etaM, t1, p1, t2, p2, supp, wa, ret, footer, links]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final s = StoreScope.read(context);
    final st = s.settings;
    st
      ..appName = appName.text.trim().isEmpty ? st.appName : appName.text.trim()
      ..tagline = tagline.text.trim()
      ..logoUrl = logoUrl.text.trim()
      ..accent = accent
      ..shippingFee = _n(ship, st.shippingFee)
      ..freeShipAbove = _n(free, st.freeShipAbove)
      ..etaDays = _n(eta, st.etaDays)
      ..etaDaysMember = _n(etaM, st.etaDaysMember)
      ..tier1 = _n(t1, st.tier1)
      ..pct1 = _n(p1, st.pct1)
      ..tier2 = _n(t2, st.tier2)
      ..pct2 = _n(p2, st.pct2)
      ..supportPhone = supp.text.trim()
      ..whatsapp = wa.text.trim()
      ..returnPolicy = ret.text.trim()
      ..footerText = footer.text.trim();
    final parsed = <Map<String, String>>[];
    for (final line in links.text.split('\n')) {
      final i = line.indexOf('|');
      if (i > 0 && line.substring(i + 1).trim().isNotEmpty) {
        parsed.add({'label': line.substring(0, i).trim(), 'url': line.substring(i + 1).trim()});
      }
    }
    st.footerLinks = parsed;
    await s.commit();
    if (mounted) {
      toast(context, 'Store settings saved');
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Store settings')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 30), children: [
        _h('Branding'),
        _tf(appName, 'Store name'),
        _tf(tagline, 'Tagline'),
        _tf(logoUrl, 'Logo image URL (https://...)', hint: 'Paste a direct image URL'),
        const Text('Theme colour', style: TextStyle(color: muted, fontSize: 12, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: List.generate(accentPalette.length, (i) {
            final e = accentPalette[i];
            return GestureDetector(
              onTap: () => setState(() => accent = i),
              child: Column(children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(color: e.value, shape: BoxShape.circle, border: Border.all(color: accent == i ? ink : Colors.transparent, width: 2.5)),
                  child: accent == i ? const Icon(Icons.check, color: Colors.white, size: 20) : null,
                ),
                const SizedBox(height: 4),
                Text(e.key, style: const TextStyle(fontSize: 10)),
              ]),
            );
          }),
        ),
        _h('Delivery'),
        Row(children: [
          Expanded(child: _tf(ship, 'Delivery fee ₹', type: TextInputType.number)),
          const SizedBox(width: 10),
          Expanded(child: _tf(free, 'Free above ₹', type: TextInputType.number)),
        ]),
        Row(children: [
          Expanded(child: _tf(eta, 'Delivery days', type: TextInputType.number)),
          const SizedBox(width: 10),
          Expanded(child: _tf(etaM, 'Member days', type: TextInputType.number)),
        ]),
        _h('Support'),
        _tf(supp, 'Support phone number', type: TextInputType.phone),
        _tf(wa, 'WhatsApp number (optional)', type: TextInputType.phone),
        _h('Return policy text'),
        _tf(ret, 'Return policy', lines: 4),
        _h('Footer'),
        _tf(footer, 'Footer text', lines: 2),
        _tf(links, 'Footer links (one per line  Label | URL)', lines: 4, hint: 'Privacy Policy | https://...'),
        const SizedBox(height: 6),
        FilledButton(onPressed: _save, child: const Text('Save settings')),
      ]),
    );
  }
}
