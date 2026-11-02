// Secure checkout endpoint. Deploy: supabase functions deploy razorpay-checkout
// Required secrets: SUPABASE_URL, SUPABASE_ANON_KEY, SUPABASE_SERVICE_ROLE_KEY,
// RAZORPAY_KEY_ID, RAZORPAY_KEY_SECRET
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
const cors = { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Headers': 'authorization, apikey, content-type', 'Access-Control-Allow-Methods': 'POST, OPTIONS' };
const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), { status, headers: { ...cors, 'Content-Type': 'application/json' } });
const hex = (buffer: ArrayBuffer) => [...new Uint8Array(buffer)].map((b) => b.toString(16).padStart(2, '0')).join('');
async function hmac(secret: string, value: string) {
  const key = await crypto.subtle.importKey('raw', new TextEncoder().encode(secret), { name: 'HMAC', hash: 'SHA-256' }, false, ['sign']);
  return hex(await crypto.subtle.sign('HMAC', key, new TextEncoder().encode(value)));
}
Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });
  if (req.method !== 'POST') return json({ error: 'Method not allowed' }, 405);
  try {
    const authHeader = req.headers.get('Authorization') ?? '';
    const token = authHeader.replace(/^Bearer\s+/i, '');
    if (!token) return json({ error: 'Authentication required' }, 401);
    const url = Deno.env.get('SUPABASE_URL')!;
    const anon = createClient(url, Deno.env.get('SUPABASE_ANON_KEY')!, { global: { headers: { Authorization: `Bearer ${token}` } } });
    const { data: authData, error: authError } = await anon.auth.getUser(token);
    if (authError || !authData.user) return json({ error: 'Invalid session' }, 401);
    const admin = createClient(url, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);
    const body = await req.json();
    const action = String(body.action ?? '');
    const user = authData.user;

    if (action === 'create_order') {
      if (!['razorpay', 'cod'].includes(String(body.payment_method ?? ''))) return json({ error: 'Unsupported payment method' }, 400);
      const checkoutId = String(body.checkout_id ?? '');
      if (!/^[a-zA-Z0-9_-]{8,80}$/.test(checkoutId)) return json({ error: 'Invalid checkout request ID' }, 400);
      const { data: existingOrder } = await admin.from('orders').select('*').eq('user_id', user.id).eq('checkout_request_id', checkoutId).maybeSingle();
      if (existingOrder) return json({ order_id: existingOrder.id, amount: Number(existingOrder.amount_paise ?? 0), currency: 'INR', razorpay_order_id: existingOrder.payment_order_id, key_id: Deno.env.get('RAZORPAY_KEY_ID') ?? null, already_paid: existingOrder.payment_status === 'captured', receipt_number: existingOrder.receipt_number });
      const lines = Array.isArray(body.items) ? body.items : [];
      if (!lines.length || lines.length > 30) return json({ error: 'Invalid cart' }, 400);
      const { data: catalogRow, error: catalogError } = await admin.from('app_data').select('data').eq('key', 'catalog').maybeSingle();
      if (catalogError || !catalogRow?.data) return json({ error: 'Store catalogue is not configured' }, 409);
      const catalog = catalogRow.data as Record<string, unknown>;
      const products = Array.isArray(catalog.products) ? catalog.products as Record<string, unknown>[] : [];
      const items: Record<string, unknown>[] = [];
      let subtotal = 0;
      for (const raw of lines) {
        const pid = Number(raw.pid); const qty = Number(raw.qty);
        if (!Number.isInteger(pid) || !Number.isInteger(qty) || qty < 1 || qty > 20) return json({ error: 'Invalid item quantity' }, 400);
        const product = products.find((p) => Number(p.id) === pid && p.active !== false);
        if (!product) return json({ error: `Product ${pid} is unavailable` }, 409);
        if (Number(product.stock ?? 0) < qty) return json({ error: `${String(product.name)} is out of stock` }, 409);
        const requestedSize = String(raw.size ?? '');
        const requestedColor = String(raw.color ?? '');
        const sizes = Array.isArray(product.sizes) ? product.sizes.map(String) : [];
        const colors = Array.isArray(product.colors) ? product.colors.map(String) : [];
        if (sizes.length && !sizes.includes(requestedSize)) return json({ error: `Invalid size for ${String(product.name)}` }, 400);
        if (colors.length && !colors.includes(requestedColor)) return json({ error: `Invalid colour for ${String(product.name)}` }, 400);
        const price = Number(product.price ?? 0);
        if (!Number.isSafeInteger(price) || price <= 0) return json({ error: 'Invalid product price' }, 409);
        subtotal += price * qty;
        items.push({ pid, name: String(product.name ?? ''), brand: String(product.brand ?? ''), size: requestedSize, color: requestedColor, qty, price });
      }
      const settings = (catalog.settings ?? {}) as Record<string, unknown>;
      const couponCode = String(body.coupon_code ?? '').trim().toUpperCase();
      let couponDiscount = 0;
      let appliedCoupon = '';
      if (couponCode) {
        const coupons = Array.isArray(catalog.coupons) ? catalog.coupons as Record<string, unknown>[] : [];
        const coupon = coupons.find((c) => String(c.code ?? '').toUpperCase() === couponCode && c.active !== false);
        if (!coupon) return json({ error: 'Coupon is invalid or inactive' }, 400);
        const minOrder = Number(coupon.minOrder ?? 0);
        if (subtotal < minOrder) return json({ error: `Minimum order for coupon is ₹${minOrder}` }, 400);
        const value = Number(coupon.value ?? 0);
        couponDiscount = coupon.percent === false ? Math.min(subtotal, value) : Math.min(subtotal, Math.floor(subtotal * value / 100));
        appliedCoupon = String(coupon.code);
      }
      const shippingFee = Math.max(0, Number(settings.shippingFee ?? 69));
      const freeAbove = Math.max(0, Number(settings.freeShipAbove ?? 0));
      const shipping = freeAbove > 0 && subtotal >= freeAbove ? 0 : shippingFee;
      const total = subtotal - couponDiscount + shipping;
      if (!Number.isSafeInteger(total) || total <= 0 || total > 10000000) return json({ error: 'Invalid order total' }, 400);
      const orderId = `ZV-${crypto.randomUUID().replaceAll('-', '').slice(0, 12).toUpperCase()}`;
      const now = new Date().toISOString();
      const orderData = {
        id: orderId, date: now, items, subtotal, couponDiscount, coupon: appliedCoupon, shipping, total,
        payment: body.payment_method === 'razorpay' ? 'Online (Pending)' : 'Cash on Delivery', paymentId: '', status: 'Placed',
        history: [{ status: 'Placed', date: now }], name: String(body.name ?? '').slice(0, 100),
        phone: String(body.phone ?? '').slice(0, 20), email: user.email ?? '',
        address: String(body.address ?? '').slice(0, 500), member: false,
      };
      const reserve = await admin.rpc('reserve_catalog_stock', { p_items: lines });
      if (reserve.error) return json({ error: reserve.error.message || 'Stock reservation failed' }, 409);
      let providerOrderId: string | null = null;
      if (body.payment_method === 'razorpay') {
        const keyId = Deno.env.get('RAZORPAY_KEY_ID'); const keySecret = Deno.env.get('RAZORPAY_KEY_SECRET');
        if (!keyId || !keySecret) { await admin.rpc('release_catalog_stock', { p_items: lines }); return json({ error: 'Online payments are not configured' }, 503); }
        const credentials = btoa(`${keyId}:${keySecret}`);
        const rr = await fetch('https://api.razorpay.com/v1/orders', { method: 'POST', headers: { Authorization: `Basic ${credentials}`, 'Content-Type': 'application/json' }, body: JSON.stringify({ amount: total * 100, currency: 'INR', receipt: orderId, notes: { zenvora_order_id: orderId, user_id: user.id } }) });
        const rj = await rr.json();
        if (!rr.ok) { await admin.rpc('release_catalog_stock', { p_items: lines }); return json({ error: 'Payment gateway could not create the order', details: rj.error?.description ?? 'Razorpay error' }, 502); }
        providerOrderId = String(rj.id);
        orderData.status = 'Payment Pending';
        orderData.payment = 'Online (Pending)';
      }
      const { error: insertError } = await admin.from('orders').insert({ id: orderId, user_id: user.id, user_email: user.email, status: orderData.status, data: orderData, payment_status: providerOrderId ? 'pending' : 'cod_pending', payment_order_id: providerOrderId, amount_paise: total * 100, checkout_request_id: checkoutId });
      if (insertError) { await admin.rpc('release_catalog_stock', { p_items: lines }); return json({ error: 'Could not save order', details: insertError.message }, 500); }
      if (providerOrderId) {
        await admin.from('payment_attempts').insert({ order_id: orderId, user_id: user.id, provider_order_id: providerOrderId, amount_paise: total * 100, status: 'created' });
      }
      return json({ order_id: orderId, amount: total * 100, currency: 'INR', razorpay_order_id: providerOrderId, key_id: Deno.env.get('RAZORPAY_KEY_ID') ?? null, order: orderData });
    }

    if (action === 'verify_payment') {
      const orderId = String(body.order_id ?? '');
      const razorpayOrderId = String(body.razorpay_order_id ?? '');
      const paymentId = String(body.razorpay_payment_id ?? '');
      const signature = String(body.razorpay_signature ?? '');
      if (!orderId || !razorpayOrderId || !paymentId || !signature) return json({ error: 'Missing payment verification fields' }, 400);
      const { data: order, error: orderError } = await admin.from('orders').select('*').eq('id', orderId).eq('user_id', user.id).single();
      if (orderError || !order || order.payment_order_id !== razorpayOrderId) return json({ error: 'Order not found' }, 404);
      if (order.payment_status === 'captured') return json({ verified: true, order_id: orderId, receipt_number: order.receipt_number });
      const secret = Deno.env.get('RAZORPAY_KEY_SECRET');
      if (!secret) return json({ error: 'Payment verification is not configured' }, 503);
      const expected = await hmac(secret, `${razorpayOrderId}|${paymentId}`);
      const a = new TextEncoder().encode(expected); const b = new TextEncoder().encode(signature);
      if (a.length !== b.length) return json({ error: 'Payment signature verification failed' }, 400);
      let diff = 0; for (let i = 0; i < a.length; i++) diff |= a[i] ^ b[i];
      if (diff !== 0) return json({ error: 'Payment signature verification failed' }, 400);
      const keyId = Deno.env.get('RAZORPAY_KEY_ID');
      const credentials = btoa(`${keyId}:${secret}`);
      const paymentResponse = await fetch(`https://api.razorpay.com/v1/payments/${encodeURIComponent(paymentId)}`, {
        headers: { Authorization: `Basic ${credentials}` },
      });
      const paymentDetails = await paymentResponse.json();
      if (!paymentResponse.ok || paymentDetails.order_id !== razorpayOrderId || Number(paymentDetails.amount) !== Number(order.amount_paise) || paymentDetails.currency !== 'INR') {
        return json({ error: 'Gateway payment details did not match this order' }, 400);
      }
      if (paymentDetails.status !== 'captured') {
        return json({ verified: false, pending: true, message: 'Payment is not captured yet. Awaiting gateway confirmation.' }, 202);
      }
      const receiptData = { ...(order.data as Record<string, unknown>), status: 'Placed', payment: 'Online (Paid)', paymentId,
        history: [...(((order.data as any).history ?? []) as unknown[]), { status: 'Payment Confirmed', date: new Date().toISOString() }] };
      const { data: receiptNumber, error: finalizeError } = await admin.rpc('confirm_razorpay_payment', {
        p_order_id: orderId, p_payment_id: paymentId, p_receipt_data: receiptData,
      });
      if (finalizeError) return json({ error: 'Payment captured but order finalization needs reconciliation', details: finalizeError.message }, 500);
      return json({ verified: true, order_id: orderId, receipt_number: receiptNumber });
    }
    return json({ error: 'Unknown action' }, 400);
  } catch (e) {
    console.error('razorpay-checkout error', e);
    return json({ error: 'Unexpected checkout error' }, 500);
  }
});
