// Deploy: supabase functions deploy send-admin-push
// Configure secrets: FIREBASE_PROJECT_ID, FIREBASE_CLIENT_EMAIL, FIREBASE_PRIVATE_KEY
// Invoke only from a trusted Database Webhook/Edge Function workflow; never from a public client.
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { GoogleAuth } from 'npm:google-auth-library@9';
const cors = { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type' };
Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });
  try {
    const webhookSecret = Deno.env.get('DATABASE_WEBHOOK_SECRET');
    if (!webhookSecret || req.headers.get('x-webhook-secret') !== webhookSecret) return new Response('Unauthorized', { status: 401, headers: cors });
    const event = await req.json();
    const projectId = Deno.env.get('FIREBASE_PROJECT_ID')!;
    const clientEmail = Deno.env.get('FIREBASE_CLIENT_EMAIL')!;
    const privateKey = Deno.env.get('FIREBASE_PRIVATE_KEY')!.replace(/\\n/g, '\n');
    const auth = new GoogleAuth({ credentials: { client_email: clientEmail, private_key: privateKey }, scopes: ['https://www.googleapis.com/auth/firebase.messaging'] });
    const access = await auth.getAccessToken();
    const supabase = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);
    const { data: admins } = await supabase.from('admins').select('email');
    const emails = (admins ?? []).map((x) => x.email);
    const { data: users } = await supabase.auth.admin.listUsers({ perPage: 1000 });
    const adminIds = (users?.users ?? []).filter((u) => emails.includes(u.email ?? '')).map((u) => u.id);
    if (!adminIds.length) return new Response(JSON.stringify({ sent: 0 }), { headers: { ...cors, 'Content-Type': 'application/json' } });
    const { data: devices } = await supabase.from('device_tokens').select('token').in('user_id', adminIds);
    const table = String(event.table ?? event.type ?? 'store');
    const record = event.record ?? event.new ?? {};
    let title = String(event.title ?? 'Zenvora Mart update');
    let body = String(event.body ?? 'New activity in your store.');
    if (!event.title) {
      if (table === 'orders') { title = `Order ${record.status ?? 'updated'} · ${record.id ?? ''}`; body = `Customer: ${record.user_email ?? 'Customer'}`; }
      else if (table === 'reviews') { title = 'New product review'; body = `${record.name ?? 'Customer'} · ${record.rating ?? ''}/5 · Pending admin approval`; }
      else if (table === 'payment_attempts') { title = `Payment ${record.status ?? 'updated'}`; body = `${record.purpose ?? ''} · ₹${record.amount ?? ''} · ${record.message ?? ''}`; }
      else if (table === 'memberships') { title = 'New membership activity'; body = `User: ${record.user_id ?? ''}`; }
    }
    let sent = 0;
    for (const device of devices ?? []) {
      const result = await fetch(`https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`, {
        method: 'POST', headers: { Authorization: `Bearer ${access}`, 'Content-Type': 'application/json' },
        body: JSON.stringify({ message: { token: device.token, notification: { title, body }, data: { type: String(event.type ?? 'store_event') }, android: { priority: 'HIGH', notification: { channel_id: 'default' } } } }),
      });
      if (result.ok) sent++;
    }
    return new Response(JSON.stringify({ sent }), { headers: { ...cors, 'Content-Type': 'application/json' } });
  } catch (error) {
    return new Response(JSON.stringify({ error: String(error) }), { status: 500, headers: { ...cors, 'Content-Type': 'application/json' } });
  }
});
