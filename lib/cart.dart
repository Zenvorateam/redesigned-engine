import 'package:flutter/material.dart';
import 'models.dart';
import 'store.dart';
import 'widgets.dart';
import 'account.dart';
import 'auth.dart';
import 'config.dart';
import 'pay.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});
  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final code = TextEditingController();
  String couponMsg = '';

  @override
  void dispose() {
    code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final lines = s.cartLines;
    final st = s.settings;

    return Scaffold(
      appBar: AppBar(title: Text('Your cart (${s.itemCount})')),
      body: lines.isEmpty
          ? const EmptyState(title: 'Your cart is empty', subtitle: 'Explore the collection and add something you love.')
          : Column(children: [
              Expanded(
                child: ListView(padding: const EdgeInsets.all(16), children: [
                  ...List.generate(lines.length, (i) {
                    final l = lines[i];
                    final p = s.productById(l.pid)!;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(11),
                      decoration: softBox(i, radius: 18),
                      child: Row(children: [
                        ProductThumb(product: p),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(p.brand, style: const TextStyle(color: muted, fontSize: 10, fontWeight: FontWeight.w900)),
                            Text(p.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
                            if (l.size.isNotEmpty || l.color.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text([if (l.size.isNotEmpty) 'Size ${l.size}', if (l.color.isNotEmpty) l.color].join(' · '),
                                    style: const TextStyle(color: muted, fontSize: 11)),
                              ),
                            const SizedBox(height: 5),
                            Text('₹${p.price}', style: const TextStyle(fontWeight: FontWeight.w900)),
                            const SizedBox(height: 7),
                            Row(children: [
                              QtyButton(icon: Icons.remove, onTap: () => s.setQty(l, l.qty - 1)),
                              Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text('${l.qty}', style: const TextStyle(fontWeight: FontWeight.w900))),
                              QtyButton(
                                icon: Icons.add,
                                onTap: () {
                                  if (l.qty >= p.stock) {
                                    toast(context, 'Only ${p.stock} available');
                                  } else {
                                    s.setQty(l, l.qty + 1);
                                  }
                                },
                              ),
                            ]),
                          ]),
                        ),
                        IconButton(onPressed: () => s.setQty(l, 0), icon: const Icon(Icons.delete_outline)),
                      ]),
                    );
                  }),

                  // membership nudge: free + fast delivery
                  if (!s.isMember)
                    GestureDetector(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MembershipScreen())),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(13),
                        decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: ink, width: 1.1)),
                        child: Row(children: [
                          const Icon(Icons.workspace_premium_rounded, color: Color(0xFFB45309)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              s.normalShipping > 0
                                  ? 'Join ${AppConfig.membershipName} for ₹${AppConfig.membershipPrice}/month and get FREE, faster delivery on this order'
                                  : 'Join ${AppConfig.membershipName} for ₹${AppConfig.membershipPrice}/month: free delivery on every order, now and later',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, height: 1.35),
                            ),
                          ),
                          const Icon(Icons.chevron_right),
                        ]),
                      ),
                    ),

                  // coupon
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: softBox(2, radius: 18),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Coupon', style: TextStyle(fontWeight: FontWeight.w900)),
                      const SizedBox(height: 8),
                      if (s.coupon != null && s.couponDiscount > 0)
                        Row(children: [
                          const Icon(Icons.check_circle, color: success, size: 18),
                          const SizedBox(width: 8),
                          Expanded(child: Text('${s.coupon!.code} applied  (-₹${s.couponDiscount})', style: const TextStyle(fontWeight: FontWeight.w800))),
                          TextButton(onPressed: () => s.removeCoupon(), child: const Text('Remove')),
                        ])
                      else
                        Row(children: [
                          Expanded(
                            child: TextField(
                              controller: code,
                              textCapitalization: TextCapitalization.characters,
                              decoration: const InputDecoration(hintText: 'Enter coupon code', contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          FilledButton(
                            style: FilledButton.styleFrom(minimumSize: const Size(80, 46)),
                            onPressed: () async {
                              final r = await s.applyCoupon(code.text);
                              setState(() => couponMsg = r ?? '');
                              if (r == null) code.clear();
                            },
                            child: const Text('Apply'),
                          ),
                        ]),
                      if (couponMsg.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text(couponMsg, style: const TextStyle(color: danger, fontSize: 12))),
                    ]),
                  ),
                ]),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: line)),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
                ),
                child: SafeArea(
                  top: false,
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    PriceRow(label: 'Subtotal', value: '₹${s.subtotal}'),
                    if (s.couponDiscount > 0) PriceRow(label: 'Coupon', value: '-₹${s.couponDiscount}', color: success),
                    PriceRow(label: s.isMember && s.normalShipping > 0 ? 'Delivery (${AppConfig.membershipName})' : 'Delivery', value: s.shipping == 0 ? 'FREE' : '₹${s.shipping}', color: s.shipping == 0 ? success : null),
                    if (s.shipping > 0)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Add ₹${st.freeShipAbove - s.subtotal} more for free delivery', style: const TextStyle(color: muted, fontSize: 11)),
                      ),
                    const Divider(height: 18),
                    PriceRow(label: 'Total', value: '₹${s.total}', bold: true),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () async {
                          if (!await ensureLogin(context)) return;
                          if (!context.mounted) return;
                          s.endBuyNow();
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const CheckoutScreen()));
                        },
                        child: const Text('Continue to checkout'),
                      ),
                    ),
                  ]),
                ),
              ),
            ]),
    );
  }
}

// ------------------------------------------------------------------ CHECKOUT
class CheckoutScreen extends StatefulWidget {
  final bool buyNow; // true = sirf ek product (Buy now)
  const CheckoutScreen({super.key, this.buyNow = false});
  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final form = GlobalKey<FormState>();
  late final TextEditingController name, email, mobile, addr, pin, town;
  bool initialized = false;
  bool busy = false;
  String payment = 'Cash on Delivery';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!initialized) {
      final s = StoreScope.read(context);
      name = TextEditingController(text: s.customerName);
      email = TextEditingController(text: s.customerEmail);
      mobile = TextEditingController(text: s.phone);
      addr = TextEditingController(text: s.address);
      pin = TextEditingController(text: s.pincode);
      town = TextEditingController(text: s.city);
      initialized = true;
    }
  }

  @override
  void dispose() {
    for (final c in [name, email, mobile, addr, pin, town]) {
      c.dispose();
    }
    super.dispose();
  }

  Widget _field(TextEditingController c, String label, IconData icon,
      {TextInputType? type, bool required = true, String? Function(String?)? validator, void Function(String)? onChanged}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: TextFormField(
        controller: c,
        keyboardType: type,
        onChanged: onChanged,
        validator: validator ?? (v) => required && (v == null || v.trim().isEmpty) ? 'This field is required' : null,
        decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon, size: 19)),
      ),
    );
  }

  Future<void> _onPinChanged(String v) async {
    if (v.length == 6) {
      final s = StoreScope.read(context);
      final t = await s.lookupPin(v);
      if (t != null && mounted) setState(() => town.text = t);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: Form(
        key: form,
        child: ListView(padding: const EdgeInsets.all(18), children: [
          if (widget.buyNow) ...[
            const Text('Buying', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            ...s.activeLines.map((l) {
              final p = s.productById(l.pid)!;
              final extra = [if (l.size.isNotEmpty) 'Size ${l.size}', if (l.color.isNotEmpty) l.color].join(' · ');
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: line)),
                child: Row(children: [
                  ProductThumb(product: p),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(p.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
                      if (extra.isNotEmpty) Text(extra, style: const TextStyle(color: muted, fontSize: 11)),
                      const SizedBox(height: 4),
                      Text('₹${p.price}  ·  Qty 1', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
                    ]),
                  ),
                ]),
              );
            }),
            const SizedBox(height: 8),
          ],
          const Text('Delivery details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 14),
          _field(name, 'Full name', Icons.person_outline),
          _field(mobile, 'Mobile number', Icons.phone_outlined, type: TextInputType.phone, validator: (v) => phoneCheck((v ?? '').trim())),
          _field(email, 'Email address (optional)', Icons.email_outlined, type: TextInputType.emailAddress, required: false),
          _field(addr, 'House / street / area', Icons.location_on_outlined),
          Row(children: [
            Expanded(child: _field(pin, 'PIN code', Icons.pin_drop_outlined, type: TextInputType.number, validator: (v) => pinCheck((v ?? '').trim()), onChanged: _onPinChanged)),
            const SizedBox(width: 10),
            Expanded(child: _field(town, 'City', Icons.location_city_outlined)),
          ]),
          Container(
            padding: const EdgeInsets.all(13),
            margin: const EdgeInsets.only(bottom: 6),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: line)),
            child: Row(children: [
              Icon(s.isMember ? Icons.bolt_rounded : Icons.local_shipping_outlined, size: 20),
              const SizedBox(width: 10),
              Expanded(child: Text('${s.isMember ? 'Express delivery' : 'Estimated delivery'} by ${dateAfter(s.etaDays)}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13))),
            ]),
          ),
          const SizedBox(height: 12),
          const Text('Payment method', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          RadioListTile<String>(
            contentPadding: EdgeInsets.zero,
            value: 'Cash on Delivery',
            groupValue: payment,
            onChanged: (v) => setState(() => payment = v!),
            title: const Text('Cash on Delivery'),
            subtitle: const Text('Pay when your order arrives'),
          ),
          RadioListTile<String>(
            contentPadding: EdgeInsets.zero,
            value: 'Online payment',
            groupValue: payment,
            onChanged: (v) => setState(() => payment = v!),
            title: const Text('Pay online'),
            subtitle: const Text('UPI, cards, netbanking, wallets (Razorpay)'),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: line)),
            child: Column(children: [
              PriceRow(label: 'Items total', value: '₹${s.subtotal}'),
              if (s.couponDiscount > 0) PriceRow(label: 'Coupon ${s.appliedCoupon ?? ''}', value: '-₹${s.couponDiscount}', color: success),
              PriceRow(label: s.isMember && s.normalShipping > 0 ? 'Delivery (${AppConfig.membershipName})' : 'Delivery', value: s.shipping == 0 ? 'FREE' : '₹${s.shipping}', color: s.shipping == 0 ? success : null),
              const Divider(),
              PriceRow(label: 'Payable amount', value: '₹${s.total}', bold: true),
            ]),
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: busy
                ? null
                : () async {
                    if (!form.currentState!.validate()) return;
                    final issue = s.stockIssue();
                    if (issue != null) {
                      toast(context, issue);
                      return;
                    }
                    final online = payment == 'Online payment';
                    if (online && !AppConfig.razorpayReady) {
                      toast(context, 'Online payment is not set up yet. Please choose Cash on Delivery.');
                      return;
                    }
                    setState(() => busy = true);
                    await s.saveProfile(name: name.text.trim(), email: email.text.trim(), mobile: mobile.text.trim(), addr: addr.text.trim(), pin: pin.text.trim(), town: town.text.trim());
                    var method = payment;
                    var payId = '';
                    if (online) {
                      final pr = await payWithRazorpay(
                        amountRupees: s.total,
                        description: 'Order at ${s.settings.appName}',
                        name: name.text.trim(),
                        email: email.text.trim().isEmpty ? s.authEmail : email.text.trim(),
                        phone: mobile.text.trim(),
                      );
                      if (!mounted) return;
                      if (!pr.ok) {
                        setState(() => busy = false);
                        toast(context, pr.message);
                        return;
                      }
                      method = 'Online (Paid)';
                      payId = pr.paymentId;
                    }
                    final r = await s.placeOrder(method, paymentId: payId);
                    if (!mounted) return;
                    setState(() => busy = false);
                    if (r != null && r.startsWith('OK:')) {
                      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => OrderSuccessScreen(orderId: r.substring(3))));
                    } else {
                      toast(context, r ?? 'Could not place order');
                    }
                  },
            child: Text(busy ? 'Placing order...' : 'Place order · ₹${s.total}'),
          ),
        ]),
      ),
    );
  }
}

class OrderSuccessScreen extends StatelessWidget {
  final String orderId;
  const OrderSuccessScreen({super.key, required this.orderId});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(color: accentOf(context), shape: BoxShape.circle),
                child: const Icon(Icons.check_rounded, color: Colors.white, size: 46),
              ),
              const SizedBox(height: 22),
              const Text('Order placed!', style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              Text('Order #$orderId', style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              const Text('Thank you for shopping with us.', textAlign: TextAlign.center, style: TextStyle(color: muted)),
              const SizedBox(height: 25),
              SizedBox(
                width: double.infinity,
                child: FilledButton(onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst), child: const Text('Continue shopping')),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    final nav = Navigator.of(context);
                    nav.popUntil((r) => r.isFirst);
                    nav.push(MaterialPageRoute(builder: (_) => OrderDetailScreen(orderId: orderId)));
                  },
                  child: const Text('Track order'),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
