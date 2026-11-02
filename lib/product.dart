import 'package:flutter/material.dart';
import 'account.dart';
import 'auth.dart';
import 'cart.dart';
import 'config.dart';
import 'models.dart';
import 'store.dart';
import 'widgets.dart';

class ProductDetailsScreen extends StatefulWidget {
  final Product product;
  const ProductDetailsScreen({super.key, required this.product});
  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen> {
  final PageController pager = PageController();
  int page = 0;
  String size = '';
  String color = '';

  @override
  void dispose() {
    pager.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------ small parts
  Widget _section(String title, Widget child) => Padding(
        padding: const EdgeInsets.only(top: 22),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Divider(height: 1),
          const SizedBox(height: 18),
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          child,
        ]),
      );

  Widget _label(String t, String chosen) => Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 10),
        child: Row(children: [
          Text(t, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900)),
          if (chosen.isNotEmpty) Text('  ·  $chosen', style: const TextStyle(fontSize: 13, color: muted)),
        ]),
      );

  Widget _chips(List<String> items, String selected, void Function(String) onPick) {
    final ac = accentOf(context);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items.map((x) {
        final on = x == selected;
        return GestureDetector(
          onTap: () => onPick(x),
          child: Container(
            constraints: const BoxConstraints(minWidth: 48),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: on ? ac : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: on ? ac : line),
            ),
            child: Text(x, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: on ? Colors.white : ink)),
          ),
        );
      }).toList(),
    );
  }

  Widget _perk(IconData icon, String text) => Expanded(
        child: Column(children: [
          Icon(icon, size: 22),
          const SizedBox(height: 6),
          Text(text, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, height: 1.25)),
        ]),
      );

  bool _pickedOptions(Product p) {
    if (p.sizes.isNotEmpty && size.isEmpty) {
      toast(context, 'Please select a size');
      return false;
    }
    if (p.colors.isNotEmpty && color.isEmpty) {
      toast(context, 'Please select a colour');
      return false;
    }
    return true;
  }

  Future<void> _addToCart(StoreController s, Product p) async {
    if (!_pickedOptions(p)) return;
    await s.addToCart(p.id, size: size, color: color);
    if (mounted) toast(context, 'Added to cart');
  }

  /// Buy now = sirf ye ek product, cart me kuch add nahi hota
  Future<void> _buyNow(StoreController s, Product p) async {
    if (!_pickedOptions(p)) return;
    if (!await ensureLogin(context)) return;
    s.startBuyNow(p.id, size: size, color: color);
    if (!mounted) return;
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const CheckoutScreen(buyNow: true)));
    s.endBuyNow();
  }

  Future<void> _writeReview(StoreController s, Product p) async {
    int rating = 5;
    final text = TextEditingController();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Rate this product', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            Row(
              children: List.generate(
                5,
                (i) => GestureDetector(
                  onTap: () => setS(() => rating = i + 1),
                  child: Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Icon(i < rating ? Icons.star_rounded : Icons.star_outline_rounded, size: 34, color: const Color(0xFFF59E0B)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(controller: text, maxLines: 3, decoration: const InputDecoration(hintText: 'Share your experience with this product')),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () async {
                  final err = await s.addReview(p.id, rating, text.text.trim());
                  if (!ctx.mounted) return;
                  Navigator.pop(ctx);
                  if (mounted) toast(context, err ?? 'Thanks for your review!');
                },
                child: const Text('Submit review'),
              ),
            ),
          ]),
        ),
      ),
    );
    text.dispose();
  }

  // ------------------------------------------------------------ build
  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final p = s.productById(widget.product.id) ?? widget.product;
    final fav = s.favourites.contains(p.id);
    final rating = s.ratingOf(p.id);
    final revs = s.reviewsOf(p.id);
    final ac = accentOf(context);
    final imgCount = p.images.isEmpty ? 1 : p.images.length;
    final days = s.etaDays;
    final inStock = p.stock > 0;

    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            onPressed: () => s.toggleFavourite(p.id),
            icon: Icon(fav ? Icons.favorite : Icons.favorite_border, color: fav ? const Color(0xFFE11D48) : ink),
          ),
          IconButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CartScreen())),
            icon: Badge(isLabelVisible: s.itemCount > 0, label: Text('${s.itemCount}'), child: const Icon(Icons.shopping_cart_outlined)),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(children: [
        Expanded(
          child: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 28), children: [
            // ---- gallery
            Container(
              height: 380,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: line)),
              child: Stack(children: [
                PageView.builder(
                  controller: pager,
                  itemCount: imgCount,
                  onPageChanged: (v) => setState(() => page = v),
                  itemBuilder: (c, i) => NetImage(
                    url: p.images.isEmpty ? '' : p.images[i],
                    fit: BoxFit.cover,
                    fallback: iconFallback(s.iconKeyFor(p.category), size: 90),
                  ),
                ),
                if (p.discount > 0)
                  Positioned(
                    left: 12,
                    top: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(color: ac, borderRadius: BorderRadius.circular(20)),
                      child: Text('${p.discount}% OFF', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900)),
                    ),
                  ),
                if (imgCount > 1)
                  Positioned(
                    right: 12,
                    bottom: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: const Color(0xCC000000), borderRadius: BorderRadius.circular(20)),
                      child: Text('${page + 1} / $imgCount', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                    ),
                  ),
              ]),
            ),
            if (imgCount > 1)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: SizedBox(
                  height: 58,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: imgCount,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (c, i) => GestureDetector(
                      onTap: () => pager.animateToPage(i, duration: const Duration(milliseconds: 250), curve: Curves.easeOut),
                      child: Container(
                        width: 58,
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: i == page ? ac : line, width: i == page ? 1.8 : 1),
                        ),
                        child: NetImage(url: p.images[i], fallback: iconFallback(s.iconKeyFor(p.category), size: 20)),
                      ),
                    ),
                  ),
                ),
              ),

            // ---- title + price
            const SizedBox(height: 20),
            Text(p.brand.toUpperCase(), style: const TextStyle(color: muted, letterSpacing: 1.6, fontSize: 11, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(p.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, height: 1.2)),
            const SizedBox(height: 10),
            Row(children: [
              if (rating > 0) ...[
                const Icon(Icons.star_rounded, size: 18, color: Color(0xFFF59E0B)),
                const SizedBox(width: 3),
                Text(rating.toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
                Text('  ·  ${revs.length} ${revs.length == 1 ? 'review' : 'reviews'}', style: const TextStyle(color: muted, fontSize: 12)),
              ] else
                const Text('No reviews yet', style: TextStyle(color: muted, fontSize: 12)),
            ]),
            const SizedBox(height: 14),
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('₹${p.price}', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, height: 1)),
              if (p.mrp > p.price) ...[
                const SizedBox(width: 10),
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text('₹${p.mrp}', style: const TextStyle(color: muted, fontSize: 14, decoration: TextDecoration.lineThrough)),
                ),
                const SizedBox(width: 10),
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text('${p.discount}% off', style: const TextStyle(color: success, fontSize: 14, fontWeight: FontWeight.w900)),
                ),
              ],
            ]),
            const SizedBox(height: 6),
            Text(
              !inStock ? 'Out of stock' : (p.stock <= 5 ? 'Only ${p.stock} left in stock' : 'In stock'),
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: !inStock ? danger : (p.stock <= 5 ? const Color(0xFFD97706) : success)),
            ),

            // ---- options
            if (p.sizes.isNotEmpty) ...[_label('Size', size), _chips(p.sizes, size, (v) => setState(() => size = v))],
            if (p.colors.isNotEmpty) ...[_label('Colour', color), _chips(p.colors, color, (v) => setState(() => color = v))],

            // ---- delivery + membership
            _section(
              'Delivery',
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Icon(Icons.location_on_outlined, size: 19),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      s.pincode.isEmpty ? 'Add your PIN code to check delivery' : 'Deliver to ${s.city.isEmpty ? '' : '${s.city} - '}${s.pincode}',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                  ),
                  TextButton(onPressed: () => showPinSheet(context), child: Text(s.pincode.isEmpty ? 'Add' : 'Change')),
                ]),
                const SizedBox(height: 4),
                Row(children: [
                  Icon(s.isMember ? Icons.bolt_rounded : Icons.local_shipping_outlined, size: 19),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      s.isMember ? 'Express delivery by ${dateAfter(days)}' : 'Delivery by ${dateAfter(days)}',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  Text(
                    s.isMember ? 'FREE' : (s.normalShipping == 0 ? 'FREE' : '₹${s.settings.shippingFee}'),
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: (s.isMember || s.normalShipping == 0) ? success : ink),
                  ),
                ]),
                const SizedBox(height: 10),
                const Row(children: [
                  Icon(Icons.payments_outlined, size: 19),
                  SizedBox(width: 10),
                  Text('Cash on Delivery & online payment', style: TextStyle(fontSize: 13)),
                ]),
                const SizedBox(height: 16),

              ]),
            ),

            // ---- trust row
            Padding(
              padding: const EdgeInsets.only(top: 22),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _perk(Icons.autorenew_rounded, '7-day easy\nreturns'),
                _perk(Icons.verified_user_outlined, 'Secure\npayments'),
                _perk(Icons.inventory_2_outlined, '100% genuine\nproducts'),
              ]),
            ),

            // ---- details
            _section('Product details', Text(p.description.isEmpty ? 'No details added yet.' : p.description, style: const TextStyle(color: Color(0xFF4B5563), height: 1.6, fontSize: 13))),

            _section(
              'Specifications',
              Container(
                decoration: BoxDecoration(border: Border.all(color: line), borderRadius: BorderRadius.circular(14)),
                clipBehavior: Clip.antiAlias,
                child: Column(children: [
                  _specRow('SKU', p.sku.isEmpty ? '-' : p.sku, false),
                  _specRow('Category', p.category, true),
                  ...List.generate(p.specs.length, (i) {
                    final e = p.specs.entries.elementAt(i);
                    return _specRow(e.key, e.value, true);
                  }),
                ]),
              ),
            ),

            _section('Return policy', Text(s.settings.returnPolicy, style: const TextStyle(color: Color(0xFF4B5563), fontSize: 13, height: 1.55))),

            if (p.brand.isNotEmpty)
              _section(
                'About ${p.brand}',
                Text(p.aboutBrand.isEmpty ? 'Brand information will be added soon.' : p.aboutBrand, style: const TextStyle(color: Color(0xFF4B5563), height: 1.6, fontSize: 13)),
              ),

            // ---- reviews
            _section('Ratings & reviews', _reviews(s, p, rating, revs)),
          ]),
        ),

        // ---- bottom bar
        Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          decoration: BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: line))),
          child: SafeArea(
            top: false,
            child: Row(children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                  onPressed: inStock ? () => _addToCart(s, p) : null,
                  child: const Text('Add to cart'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: inStock ? () => _buyNow(s, p) : null,
                  child: Text(inStock ? 'Buy now' : 'Out of stock'),
                ),
              ),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _reviews(StoreController s, Product p, double rating, List<Review> revs) {
    final counts = List.generate(5, (i) => revs.where((r) => r.rating == 5 - i).length);
    final ac = accentOf(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (revs.isNotEmpty)
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Column(children: [
            Text(rating.toStringAsFixed(1), style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900, height: 1)),
            const SizedBox(height: 6),
            StarRow(rating: rating, size: 16),
            const SizedBox(height: 4),
            Text('${revs.length} ${revs.length == 1 ? 'review' : 'reviews'}', style: const TextStyle(color: muted, fontSize: 11)),
          ]),
          const SizedBox(width: 22),
          Expanded(
            child: Column(
              children: List.generate(5, (i) {
                final frac = revs.isEmpty ? 0.0 : counts[i] / revs.length;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(children: [
                    Text('${5 - i}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(value: frac, minHeight: 6, backgroundColor: line, color: ac),
                      ),
                    ),
                  ]),
                );
              }),
            ),
          ),
        ])
      else
        const Text('No reviews yet.', style: TextStyle(color: muted, fontSize: 13)),
      const SizedBox(height: 14),
      // sirf order karne wale review likh sakte hain
      if (s.canReview(p.id))
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(onPressed: () => _writeReview(s, p), icon: const Icon(Icons.rate_review_outlined, size: 18), label: const Text('Write a review')),
        )
      else
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(s.hasReviewed(p.id) ? Icons.check_circle_outline : Icons.lock_outline, size: 16, color: muted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              s.hasReviewed(p.id) ? 'You have reviewed this product. Thank you!' : 'Only customers who have ordered this product can write a review.',
              style: const TextStyle(color: muted, fontSize: 12, height: 1.4),
            ),
          ),
        ]),
      if (revs.isNotEmpty) const SizedBox(height: 6),
      ...revs.map((r) => Container(
            margin: const EdgeInsets.only(top: 10),
            padding: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(border: Border(top: BorderSide(color: line))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                StarRow(rating: r.rating.toDouble(), size: 14),
                const SizedBox(width: 8),
                Expanded(child: Text(r.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13))),
                Text(shortDate(r.date).split('  ').first, style: const TextStyle(color: muted, fontSize: 11)),
              ]),
              if (r.text.isNotEmpty) ...[const SizedBox(height: 6), Text(r.text, style: const TextStyle(fontSize: 13, height: 1.5))],
              const SizedBox(height: 4),
              const Row(children: [
                Icon(Icons.verified_outlined, size: 13, color: success),
                SizedBox(width: 4),
                Text('Verified purchase', style: TextStyle(color: success, fontSize: 11, fontWeight: FontWeight.w700)),
              ]),
            ]),
          )),
    ]);
  }

  Widget _specRow(String k, String v, bool top) => Container(
        decoration: BoxDecoration(border: top ? Border(top: BorderSide(color: line)) : null),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(flex: 4, child: Text(k, style: const TextStyle(color: muted, fontSize: 13))),
          Expanded(flex: 5, child: Text(v, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700))),
        ]),
      );
}
