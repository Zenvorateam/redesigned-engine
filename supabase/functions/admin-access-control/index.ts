import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
const cors = { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type', 'Access-Control-Allow-Methods': 'POST, OPTIONS' }
Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors })
  const fail = (message: string, status = 400) => new Response(JSON.stringify({ error: message }), { status, headers: { ...cors, 'Content-Type': 'application/json' } })
  try {
    const url = Deno.env.get('SUPABASE_URL')!, anon = Deno.env.get('SUPABASE_ANON_KEY')!, service = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const auth = req.headers.get('Authorization') || ''
    const caller = createClient(url, anon, { global: { headers: { Authorization: auth } } })
    const { data: { user } } = await caller.auth.getUser()
    if (!user) return fail('Authentication required', 401)
    const root = createClient(url, service)
    const { data: role } = await root.from('admin_roles').select('role,active').eq('user_id', user.id).maybeSingle()
    const { data: bootstrap } = await root.from('admins').select('email').ilike('email', user.email ?? '').maybeSingle()
    if (!(role?.active && role.role === 'super_admin') && !bootstrap) return fail('Super Admin permission required', 403)
    const body = await req.json()
    const email = String(body.email ?? '').trim().toLowerCase()
    const action = String(body.action ?? 'upsert')
    if (!email || !email.includes('@')) return fail('Valid admin email required')
    const { data: list } = await root.auth.admin.listUsers({ page: 1, perPage: 1000 })
    const target = list.users.find((u) => (u.email ?? '').toLowerCase() === email)
    if (!target) return fail('User must create a customer account first, then grant admin access')
    if (target.id === user.id && body.role !== 'super_admin') return fail('You cannot downgrade your own Super Admin role')
    if (action === 'remove') {
      const { error } = await root.from('admin_roles').update({ active: false, updated_at: new Date().toISOString() }).eq('user_id', target.id)
      if (error) return fail(error.message)
    } else {
      const roleName = String(body.role ?? 'staff')
      if (!['x_admin', 'staff'].includes(roleName)) return fail('Role must be x_admin or staff')
      const permissions = roleName === 'staff' ? { 'products.manage': true, 'orders.manage': true } : (body.permissions ?? {})
      const { error } = await root.from('admin_roles').upsert({ user_id: target.id, role: roleName, permissions, active: body.active !== false, created_by: user.id, updated_at: new Date().toISOString() })
      if (error) return fail(error.message)
    }
    await root.from('audit_logs').insert({ actor_id: user.id, action: action === 'remove' ? 'admin_access_revoked' : 'admin_access_granted', entity_type: 'admin_roles', entity_id: target.id, after_data: { email, role: body.role ?? null } })
    return new Response(JSON.stringify({ ok: true }), { headers: { ...cors, 'Content-Type': 'application/json' } })
  } catch (e) { return fail(String(e), 500) }
})
