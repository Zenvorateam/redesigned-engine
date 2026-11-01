import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'models.dart';
import 'store.dart';
import 'widgets.dart';

void openCategory(BuildContext context, String name) =>
    Navigator.push(context, MaterialPageRoute(builder: (_) => CategoryProductsScreen(category: name)));

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final products = s.listProducts(brand: s.selectedBrand);
    final notifCount = s.unreadNotices;

    return CustomScrollView(slivers: [
      // header: logo + name, search, notifications
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 10, 8),
          child: Row(children: [
            const BrandLogo(size: 42),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s.settings.appName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: -.6)),
                Text(s.settings.tagline, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: muted, fontSize: 11)),
              ]),
            ),
            IconButton(
              tooltip: s.dark ? 'Light mode' : 'Dark mode',
              onPressed: () => s.setDark(!s.dark),
              icon: Icon(s.dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
            ),
            IconButton(
              tooltip: 'Search',
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchScreen())),
              icon: const Icon(Icons.search_rounded),
            ),
            IconButton(
              tooltip: 'Notifications',
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen())),
              icon: Badge(isLabelVisible: notifCount > 0, label: Text('$notifCount'), child: const Icon(Icons.notifications_none_rounded)),
            ),
          ]),
        ),
      ),

      // auto delivery PIN
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 12),
          child: GestureDetector(
            onTap: () => showPinSheet(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: softBox(3, radius: 14),
              child: Row(children: [
                const Icon(Icons.location_on_outlined, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    s.pincode.isEmpty ? 'Detecting your delivery location...' : 'Deliver to ${s.city.isEmpty ? '' : '${s.city} - '}${s.pincode}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                  ),
                ),
                Text(s.isMember ? 'Express' : 'Change', style: const TextStyle(fontSize: 11, color: muted, fontWeight: FontWeight.w700)),
                const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
              ]),
            ),
          ),
        ),
      ),

      // banner slider (image only, admin sets link)
      if (s.banners.isNotEmpty) const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.symmetric(horizontal: 18), child: BannerSlider())),

      // categories (sliding)
      const SliverToBoxAdapter(child: SectionHeading(title: 'Shop by category')),
      SliverToBoxAdapter(
        child: SizedBox(
          height: 98,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            itemCount: s.categories.length,
            itemBuilder: (c, i) => _CategoryTile(item: s.categories[i], index: i),
          ),
        ),
      ),

      // brands
      const SliverToBoxAdapter(child: SectionHeading(title: 'Current brands')),
      SliverToBoxAdapter(
        child: SizedBox(
          height: 88,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            children: s.brands.map((b) => _BrandTile(name: b)).toList(),
          ),
        ),
      ),

      SliverToBoxAdapter(
        child: SectionHeading(
          title: s.selectedBrand == 'All' ? 'Popular products' : '${s.selectedBrand} collection',
          action: 'Sort',
          onTap: () => showSortSheet(context),
        ),
      ),
      if (products.isEmpty)
        const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.symmetric(vertical: 30), child: EmptyState(title: 'No products found', subtitle: 'Try another brand or category.')))
      else
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
          sliver: SliverGrid(
            delegate: SliverChildBuilderDelegate((c, i) => ProductCard(product: products[i], index: i), childCount: products.length),
            gridDelegate: productGridDelegate(),
          ),
        ),
      const SliverToBoxAdapter(child: FooterBlock()),
    ]);
  }
}

// ------------------------------------------------------------------ BANNER SLIDER
class BannerSlider extends StatefulWidget {
  const BannerSlider({super.key});
  @override
  State<BannerSlider> createState() => _BannerSliderState();
}

class _BannerSliderState extends State<BannerSlider> {
  final PageController controller = PageController();
  Timer? timer;
  int page = 0;

  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || !controller.hasClients) return;
      final n = StoreScope.read(context).banners.length;
      if (n < 2) return;
      controller.animateToPage((page + 1) % n, duration: const Duration(milliseconds: 450), curve: Curves.easeInOut);
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final list = s.banners;
    final ac = accentOf(context);
    return Column(children: [
      Container(
        height: 170,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(24)),
        child: PageView.builder(
          controller: controller,
          itemCount: list.length,
          onPageChanged: (v) => setState(() => page = v),
          itemBuilder: (c, i) {
            final b = list[i];
            return GestureDetector(
              onTap: () {
                if (b.category.isNotEmpty) openCategory(context, b.category);
              },
              // no text on the banner, only the image (gradient if no image yet)
              child: Container(
                decoration: softBox(i + 1, radius: 0, border: false),
                child: NetImage(url: b.image, fallback: const SizedBox.expand()),
              ),
            );
          },
        ),
      ),
      const SizedBox(height: 10),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(
          list.length,
          (i) => AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: i == page ? 22 : 6,
            height: 6,
            decoration: BoxDecoration(color: i == page ? ac : const Color(0xFFD1D5DB), borderRadius: BorderRadius.circular(9)),
          ),
        ),
      ),
    ]);
  }
}

class _CategoryTile extends StatelessWidget {
  final CategoryItem item;
  final int index;
  const _CategoryTile({required this.item, required this.index});
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () => openCategory(context, item.name),
        child: SizedBox(
          width: 82,
          child: Column(children: [
            Container(
              width: 58,
              height: 58,
              decoration: softBox(index, radius: 20),
              child: Icon(iconFor(item.icon), size: 25, color: ink),
            ),
            const SizedBox(height: 7),
            Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
          ]),
        ),
      );
}

class _BrandTile extends StatelessWidget {
  final String name;
  const _BrandTile({required this.name});
  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final active = s.selectedBrand == name;
    final ac = accentOf(context);
    return GestureDetector(
      onTap: () => s.setBrand(active ? 'All' : name),
      child: Container(
        width: 105,
        margin: const EdgeInsets.symmetric(horizontal: 5),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          gradient: softGradient(0),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: active ? ac : const Color(0x14000000), width: active ? 1.6 : 1),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Expanded(
            child: AssetPic(
              path: 'assets/brands/${name.toLowerCase()}.png',
              fallback: Center(child: Text(name, style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2))),
            ),
          ),
          const SizedBox(height: 4),
          Text(name, style: const TextStyle(fontSize: 9, color: muted, fontWeight: FontWeight.w800, letterSpacing: 1)),
        ]),
      ),
    );
  }
}

// ------------------------------------------------------------------ CATEGORY PAGE
class CategoryProductsScreen extends StatelessWidget {
  final String category;
  const CategoryProductsScreen({super.key, required this.category});
  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final list = s.listProducts(category: category);
    return Scaffold(
      appBar: AppBar(title: Text(category), actions: [IconButton(onPressed: () => showSortSheet(context), icon: const Icon(Icons.sort_rounded))]),
      body: list.isEmpty
          ? const EmptyState(title: 'No products yet', subtitle: 'Products in this category will appear here.')
          : GridView.builder(
              padding: const EdgeInsets.all(14),
              itemCount: list.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 11, mainAxisSpacing: 12, childAspectRatio: .68),
              itemBuilder: (c, i) => ProductCard(product: list[i], index: i),
            ),
    );
  }
}

// ------------------------------------------------------------------ SEARCH
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final controller = TextEditingController();
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final list = s.listProducts(q: controller.text, sortBy: 'Featured');
    return Scaffold(
      appBar: AppBar(title: const Text('Search products')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: controller,
            autofocus: true,
            onChanged: (v) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Search products, brands, categories',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                onPressed: () {
                  controller.clear();
                  setState(() {});
                },
                icon: const Icon(Icons.close),
              ),
            ),
          ),
        ),
        Expanded(
          child: list.isEmpty
              ? const EmptyState(title: 'No matches', subtitle: 'Try a different search.', icon: Icons.search_off_rounded)
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (c, i) => ListTile(
                    contentPadding: const EdgeInsets.symmetric(vertical: 6),
                    leading: ProductThumb(product: list[i]),
                    title: Text(list[i].name, style: const TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: Text('${list[i].brand} · ₹${list[i].price}'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => openProduct(context, list[i]),
                  ),
                ),
        ),
      ]),
    );
  }
}

// ------------------------------------------------------------------ NOTIFICATIONS
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late final StoreController store;

  @override
  void initState() {
    super.initState();
    store = StoreScope.read(context);
    // screen kholte hi sab "seen" ho jaye; badge hat jaye
    WidgetsBinding.instance.addPostFrameCallback((_) => store.markNoticesSeen());
  }

  IconData _icon(String k) {
    switch (k) {
      case 'order':
        return Icons.local_shipping_outlined;
      case 'admin':
        return Icons.receipt_long_outlined;
      case 'member':
        return Icons.workspace_premium_outlined;
      default:
        return Icons.notifications_none_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final updates = s.notices.where((n) => n.kind != 'offer').toList();
    final offers = s.notifications;
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: (updates.isEmpty && offers.isEmpty)
          ? const EmptyState(title: 'No notifications', subtitle: 'Order updates and offers will show up here.', icon: Icons.notifications_none_rounded)
          : ListView(padding: const EdgeInsets.all(16), children: [
              if (updates.isNotEmpty) ...[
                const Text('UPDATES', style: TextStyle(color: muted, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                const SizedBox(height: 8),
                ...updates.map((n) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(13),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: line)),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: line)),
                          child: Icon(_icon(n.kind), size: 19),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(n.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                            const SizedBox(height: 2),
                            Text(n.body, style: const TextStyle(color: muted, fontSize: 12, height: 1.35)),
                            if (n.date.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text(shortDate(n.date), style: const TextStyle(color: muted, fontSize: 10))),
                          ]),
                        ),
                      ]),
                    )),
                const SizedBox(height: 10),
              ],
              if (offers.isNotEmpty) ...[
                const Text('OFFERS', style: TextStyle(color: muted, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                const SizedBox(height: 8),
                ...List.generate(offers.length, (i) => Padding(padding: const EdgeInsets.only(bottom: 10), child: CouponCard(coupon: offers[i], index: i))),
              ],
            ]),
    );
  }
}

class CouponCard extends StatelessWidget {
  final Coupon coupon;
  final int index;
  const CouponCard({super.key, required this.coupon, this.index = 1});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: softBox(index, radius: 18),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(coupon.label, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
              const SizedBox(height: 2),
              Text(coupon.title.isEmpty ? 'Special offer' : coupon.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              const SizedBox(height: 2),
              Text(coupon.minOrder > 0 ? 'On orders above ₹${coupon.minOrder}' : 'No minimum order', style: const TextStyle(color: muted, fontSize: 11)),
            ]),
          ),
          GestureDetector(
            onTap: () async {
              await Clipboard.setData(ClipboardData(text: coupon.code));
              if (context.mounted) toast(context, 'Code ${coupon.code} copied');
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: line)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(coupon.code, style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
                const SizedBox(width: 6),
                const Icon(Icons.copy_rounded, size: 14),
              ]),
            ),
          ),
        ]),
      );
}

// ------------------------------------------------------------------ WISHLIST
class WishlistScreen extends StatelessWidget {
  const WishlistScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final list = s.products.where((p) => p.active && s.favourites.contains(p.id)).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Saved products')),
      body: list.isEmpty
          ? const EmptyState(title: 'Nothing saved yet', subtitle: 'Tap the heart on a product to save it.', icon: Icons.favorite_border)
          : GridView.builder(
              padding: const EdgeInsets.all(14),
              itemCount: list.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 11, mainAxisSpacing: 12, childAspectRatio: .68),
              itemBuilder: (c, i) => ProductCard(product: list[i], index: i),
            ),
    );
  }
}
