// Deploy: supabase functions deploy razorpay-webhook
// Required secrets: SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, RAZORPAY_WEBHOOK_SECRET
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
const cors = { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Headers': 'content-type, x-razorpay-signature' };
async function hmacHex(secret: string, body: string) {
  const key = await crypto.subtle.importKey('raw', new TextEncoder().encode(secret), { name: 'HMAC', hash: 'SHA-256' }, false, ['sign']);
  return [...new Uint8Array(await crypto.subtle.sign('HMAC', key, new TextEncoder().encode(body)))].map((b) => b.toString(16).padStart(2,'0')).join('');
}
Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });
  if (req.method !== 'POST') return new Response('Method not allowed', { status: 405, headers: cors });
  const raw = await req.text();
  const secret = Deno.env.get('RAZORPAY_WEBHOOK_SECRET');
  const supplied = req.headers.get('x-razorpay-signature') ?? '';
  if (!secret || !supplied) return new Response('Unauthorized', { status: 401, headers: cors });
  const expected = await hmacHex(secret, raw);
  const a = new TextEncoder().encode(expected); const b = new TextEncoder().encode(supplied);
  if (a.length !== b.length) return new Response('Invalid signature', { status: 401, headers: cors });
  let signatureDiff = 0; for (let i = 0; i < a.length; i++) signatureDiff |= a[i] ^ b[i];
  if (signatureDiff !== 0) return new Response('Invalid signature', { status: 401, headers: cors });
  try {
    const event = JSON.parse(raw);
    const admin = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);
    const payment = event.payload?.payment?.entity;
    const razorpayOrderId = payment?.order_id;
    const paymentId = payment?.id;
    if (event.event === 'payment.captured' && razorpayOrderId && paymentId) {
      const { data: order } = await admin.from('orders').select('*').eq('payment_order_id', razorpayOrderId).maybeSingle();
      if (order && order.payment_status !== 'captured') {
        const receiptData = { ...(order.data ?? {}), status: 'Placed', payment: 'Online (Paid)', paymentId };
        const { error } = await admin.rpc('confirm_razorpay_payment', {
          p_order_id: order.id, p_payment_id: paymentId, p_receipt_data: receiptData,
        });
        if (error) throw error;
      }
    }
    if (event.event === 'payment.failed' && razorpayOrderId) {
      await admin.from('orders').update({ payment_status: 'failed', updated_at: new Date().toISOString() }).eq('payment_order_id', razorpayOrderId).neq('payment_status','captured');
      await admin.from('payment_attempts').update({ status: 'failed', updated_at: new Date().toISOString() }).eq('provider_order_id', razorpayOrderId);
    }
    return new Response(JSON.stringify({ received: true }), { headers: { ...cors, 'Content-Type': 'application/json' } });
  } catch (e) {
    console.error('webhook processing failed', e);
    return new Response('Webhook processing failed', { status: 500, headers: cors });
  }
});
