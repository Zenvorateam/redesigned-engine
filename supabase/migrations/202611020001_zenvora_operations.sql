-- Zenvora Mart operational backend foundation.
-- Run AFTER supabase/setup.sql in Supabase SQL Editor.
-- Never expose SUPABASE_SERVICE_ROLE_KEY or Razorpay secrets in the Flutter app.

create extension if not exists pgcrypto;

-- Admin identity and permissions. Existing public.admins email allow-list remains the
-- bootstrap source for the original Super Admin account.
create table if not exists public.admin_roles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  role text not null check (role in ('super_admin','x_admin','staff')),
  permissions jsonb not null default '{}'::jsonb,
  active boolean not null default true,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

insert into public.admin_roles(user_id, role, permissions)
select u.id, 'super_admin', '{"*":true}'::jsonb
from auth.users u
join public.admins a on lower(a.email) = lower(u.email)
on conflict (user_id) do nothing;

create or replace function public.is_admin()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.admin_roles ar
    where ar.user_id = auth.uid() and ar.active = true
  ) or exists (
    select 1 from public.admins a
    where lower(a.email) = lower(coalesce(auth.jwt() ->> 'email',''))
  );
$$;

create or replace function public.has_permission(permission_key text)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.admin_roles ar
    where ar.user_id = auth.uid() and ar.active = true
      and (ar.role = 'super_admin' or coalesce((ar.permissions ->> permission_key)::boolean,false)
           or coalesce((ar.permissions ->> '*')::boolean,false))
  ) or exists (
    select 1 from public.admins a
    where lower(a.email) = lower(coalesce(auth.jwt() ->> 'email',''))
  );
$$;

alter table public.admins enable row level security;
drop policy if exists admins_read_self on public.admins;
create policy admins_read_self on public.admins for select to authenticated
  using (lower(email) = lower(coalesce(auth.jwt() ->> 'email','')));
-- No client INSERT/UPDATE/DELETE policy: role grants are backend-only.

alter table public.admin_roles enable row level security;
drop policy if exists admin_roles_read_self on public.admin_roles;
create policy admin_roles_read_self on public.admin_roles for select to authenticated
  using (user_id = auth.uid() or public.is_admin());
-- No client write policy. Provision X-admin/staff via trusted service-role workflow.

-- Extend existing order rows without breaking the current app's JSON data shape.
alter table public.orders add column if not exists payment_status text not null default 'pending';
alter table public.orders add column if not exists payment_order_id text;
alter table public.orders add column if not exists payment_id text;
alter table public.orders add column if not exists amount_paise bigint;
alter table public.orders add column if not exists receipt_number text unique;
alter table public.orders add column if not exists updated_at timestamptz not null default now();
alter table public.orders add column if not exists refund_status text not null default 'not_requested';
create index if not exists orders_user_created_idx on public.orders(user_id, created_at desc);
create index if not exists orders_payment_order_idx on public.orders(payment_order_id);

create table if not exists public.payment_attempts (
  id uuid primary key default gen_random_uuid(),
  order_id text references public.orders(id) on delete set null,
  user_id uuid not null references auth.users(id) on delete cascade,
  provider text not null default 'razorpay',
  provider_order_id text unique,
  provider_payment_id text unique,
  amount_paise bigint not null check (amount_paise > 0),
  currency text not null default 'INR',
  status text not null default 'created' check (status in ('created','authorized','captured','failed','refunded')),
  provider_payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.payment_receipts (
  id uuid primary key default gen_random_uuid(),
  receipt_number text not null unique,
  order_id text not null references public.orders(id) on delete restrict,
  user_id uuid not null references auth.users(id) on delete cascade,
  payment_attempt_id uuid references public.payment_attempts(id),
  amount_paise bigint not null check (amount_paise >= 0),
  currency text not null default 'INR',
  payment_method text,
  transaction_reference text,
  paid_at timestamptz not null default now(),
  receipt_data jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists public.customer_addresses (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  label text not null default 'Home',
  recipient_name text not null,
  phone text not null,
  address_line text not null,
  city text not null,
  state text not null,
  pincode char(6) not null,
  is_default boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.product_policies (
  product_id bigint primary key,
  policy_type text not null default 'return' check (policy_type in ('return','replacement_only','no_return')),
  return_days integer not null default 7 check (return_days between 0 and 90),
  policy_text text not null default '',
  updated_by uuid references auth.users(id),
  updated_at timestamptz not null default now()
);

create table if not exists public.return_requests (
  id uuid primary key default gen_random_uuid(),
  order_id text not null references public.orders(id) on delete restrict,
  user_id uuid not null references auth.users(id) on delete cascade,
  status text not null default 'requested' check (status in ('requested','approved','rejected','pickup_scheduled','item_received','inspected','refund_open','closed')),
  reason text not null,
  customer_note text not null default '',
  evidence_urls jsonb not null default '[]'::jsonb,
  admin_note text not null default '',
  requested_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  reviewed_by uuid references auth.users(id)
);

-- Sensitive payout details are visible only to the customer and authorized refund admins.
create table if not exists public.refund_payout_details (
  id uuid primary key default gen_random_uuid(),
  return_request_id uuid not null references public.return_requests(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  payout_type text not null check (payout_type in ('upi_id','upi_qr')),
  upi_id text,
  qr_storage_path text,
  submitted_at timestamptz not null default now(),
  reviewed_at timestamptz,
  reviewed_by uuid references auth.users(id)
);

create table if not exists public.refund_records (
  id uuid primary key default gen_random_uuid(),
  return_request_id uuid not null references public.return_requests(id) on delete restrict,
  order_id text not null references public.orders(id) on delete restrict,
  user_id uuid not null references auth.users(id) on delete cascade,
  amount_paise bigint not null check (amount_paise >= 0),
  payout_method text not null check (payout_method in ('original_method','upi','bank_transfer','cash_manual')),
  status text not null default 'pending_admin_approval' check (status in ('pending_admin_approval','approved','processing','paid','rejected')),
  transaction_reference text,
  admin_note text not null default '',
  approved_by uuid references auth.users(id),
  paid_by uuid references auth.users(id),
  paid_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists public.loyalty_ledger (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  order_id text references public.orders(id) on delete set null,
  entry_type text not null check (entry_type in ('earned','redeemed','reversed','adjustment','expired')),
  points integer not null check (points <> 0),
  rupee_value_paise bigint not null default 0,
  note text not null default '',
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now()
);

create table if not exists public.membership_plans (
  id text primary key check (id in ('silver','gold','platinum')),
  title text not null,
  active boolean not null default false,
  price_paise bigint not null default 0 check (price_paise >= 0),
  duration_days integer not null default 30 check (duration_days > 0),
  benefits jsonb not null default '[]'::jsonb,
  updated_by uuid references auth.users(id),
  updated_at timestamptz not null default now()
);
insert into public.membership_plans(id,title,active) values
('silver','Silver',false),('gold','Gold',true),('platinum','Platinum',false)
on conflict (id) do nothing;

create table if not exists public.support_tickets (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  order_id text references public.orders(id) on delete set null,
  category text not null default 'general',
  subject text not null,
  status text not null default 'open' check (status in ('open','in_progress','waiting_customer','resolved','closed')),
  priority text not null default 'normal' check (priority in ('low','normal','high')),
  assigned_to uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table if not exists public.support_messages (
  id uuid primary key default gen_random_uuid(),
  ticket_id uuid not null references public.support_tickets(id) on delete cascade,
  sender_id uuid not null references auth.users(id) on delete cascade,
  body text not null,
  attachment_urls jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists public.suppliers (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  contact_name text,
  email text,
  phone text,
  notes text not null default '',
  active boolean not null default true,
  created_at timestamptz not null default now()
);
create table if not exists public.supplier_order_lines (
  id uuid primary key default gen_random_uuid(),
  supplier_id uuid not null references public.suppliers(id),
  order_id text not null references public.orders(id) on delete cascade,
  product_id bigint not null,
  quantity integer not null check (quantity > 0),
  unit_cost_paise bigint not null default 0,
  status text not null default 'assigned',
  tracking_reference text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table if not exists public.supplier_payments (
  id uuid primary key default gen_random_uuid(),
  supplier_id uuid not null references public.suppliers(id),
  order_id text references public.orders(id) on delete set null,
  amount_paise bigint not null check (amount_paise >= 0),
  status text not null default 'pending' check (status in ('pending','confirmed','void')),
  reference text,
  note text not null default '',
  confirmed_by uuid references auth.users(id),
  confirmed_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists public.admin_messages (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  body text not null,
  audience text not null default 'customers' check (audience in ('customers','staff','x_admins','all')),
  logo_url text,
  image_url text,
  scheduled_at timestamptz,
  sent_at timestamptz,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now()
);
create table if not exists public.user_notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  title text not null,
  body text not null,
  category text not null default 'general',
  payload jsonb not null default '{}'::jsonb,
  read_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists public.audit_logs (
  id bigint generated always as identity primary key,
  actor_id uuid references auth.users(id),
  action text not null,
  entity_type text not null,
  entity_id text,
  before_data jsonb,
  after_data jsonb,
  created_at timestamptz not null default now()
);
create table if not exists public.app_remote_config (
  key text primary key,
  value jsonb not null,
  updated_by uuid references auth.users(id),
  updated_at timestamptz not null default now()
);

-- RLS defaults: private records are owner-only; Admin access is server role/permission checked.
do $$ declare t text; begin
  foreach t in array array['payment_attempts','payment_receipts','customer_addresses','return_requests','refund_payout_details','refund_records','loyalty_ledger','support_tickets','support_messages','user_notifications'] loop
    execute format('alter table public.%I enable row level security', t);
  end loop;
end $$;

-- Drop/recreate named policies so the migration is safe to re-run.
drop policy if exists payment_attempts_read on public.payment_attempts;
create policy payment_attempts_read on public.payment_attempts for select to authenticated using (user_id = auth.uid() or public.has_permission('payments.view'));
drop policy if exists payment_receipts_read on public.payment_receipts;
create policy payment_receipts_read on public.payment_receipts for select to authenticated using (user_id = auth.uid() or public.has_permission('receipts.view'));
drop policy if exists addresses_owner_all on public.customer_addresses;
create policy addresses_owner_all on public.customer_addresses for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
drop policy if exists returns_owner_read on public.return_requests;
create policy returns_owner_read on public.return_requests for select to authenticated using (user_id = auth.uid() or public.has_permission('returns.manage'));
drop policy if exists returns_owner_insert on public.return_requests;
create policy returns_owner_insert on public.return_requests for insert to authenticated with check (user_id = auth.uid());
drop policy if exists payout_details_owner_read on public.refund_payout_details;
create policy payout_details_owner_read on public.refund_payout_details for select to authenticated using (user_id = auth.uid() or public.has_permission('refunds.manage'));
drop policy if exists loyalty_owner_read on public.loyalty_ledger;
create policy loyalty_owner_read on public.loyalty_ledger for select to authenticated using (user_id = auth.uid() or public.has_permission('loyalty.manage'));
drop policy if exists support_ticket_owner_all on public.support_tickets;
create policy support_ticket_owner_all on public.support_tickets for select to authenticated using (user_id = auth.uid() or public.has_permission('support.manage'));
drop policy if exists support_ticket_owner_insert on public.support_tickets;
create policy support_ticket_owner_insert on public.support_tickets for insert to authenticated with check (user_id = auth.uid());
drop policy if exists support_messages_read on public.support_messages;
create policy support_messages_read on public.support_messages for select to authenticated using (
  sender_id = auth.uid() or exists(select 1 from public.support_tickets t where t.id = ticket_id and t.user_id = auth.uid()) or public.has_permission('support.manage')
);
drop policy if exists support_messages_insert on public.support_messages;
create policy support_messages_insert on public.support_messages for insert to authenticated with check (
  sender_id = auth.uid() and (exists(select 1 from public.support_tickets t where t.id = ticket_id and t.user_id = auth.uid()) or public.has_permission('support.manage'))
);
drop policy if exists notifications_owner_read on public.user_notifications;
create policy notifications_owner_read on public.user_notifications for select to authenticated using (user_id = auth.uid() or public.is_admin());

-- Admin-only operational tables; writes must pass server role checks.
do $$ declare t text; begin
  foreach t in array array['product_policies','membership_plans','suppliers','supplier_order_lines','supplier_payments','admin_messages','audit_logs','app_remote_config'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('drop policy if exists %I on public.%I', t || '_admin_all', t);
    execute format('create policy %I on public.%I for all to authenticated using (public.is_admin()) with check (public.is_admin())', t || '_admin_all', t);
  end loop;
end $$;

-- Keep sensitive tables unwriteable from ordinary clients. Trusted Edge Functions use service role.
revoke insert, update, delete on public.payment_attempts from anon, authenticated;
revoke insert, update, delete on public.payment_receipts from anon, authenticated;
revoke insert, update, delete on public.refund_records from anon, authenticated;
revoke insert, update, delete on public.refund_payout_details from anon, authenticated;
revoke insert, update, delete on public.loyalty_ledger from anon, authenticated;
revoke insert, update, delete on public.audit_logs from anon, authenticated;
revoke insert, update, delete on public.admin_roles from anon, authenticated;

-- Receipt numbering is assigned only by trusted backend after verified capture.
create or replace function public.make_receipt_number()
returns text language sql volatile as $$
  select 'ZMR-' || to_char(now() at time zone 'Asia/Kolkata','YYYYMMDD') || '-' || upper(substr(replace(gen_random_uuid()::text,'-',''),1,8));
$$;

-- Admin activity helper: call only from trusted backend/service role.
create or replace function public.write_audit_log(p_actor uuid,p_action text,p_entity text,p_entity_id text,p_before jsonb,p_after jsonb)
returns void language plpgsql security definer set search_path = public as $$
begin
  insert into public.audit_logs(actor_id,action,entity_type,entity_id,before_data,after_data)
  values(p_actor,p_action,p_entity,p_entity_id,p_before,p_after);
end; $$;
revoke all on function public.write_audit_log(uuid,text,text,text,jsonb,jsonb) from public, anon, authenticated;

-- Atomic stock reservation against the single catalog JSON row. Only service role may call.
create or replace function public.reserve_catalog_stock(p_items jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_catalog jsonb;
  v_products jsonb := '[]'::jsonb;
  v_product jsonb;
  v_item jsonb;
  v_pid bigint;
  v_qty integer;
  v_stock integer;
  v_found boolean;
begin
  select data into v_catalog from public.app_data where key = 'catalog' for update;
  if v_catalog is null then raise exception 'Catalog is not configured'; end if;
  for v_item in select value from jsonb_array_elements(p_items) loop
    v_pid := (v_item->>'pid')::bigint;
    v_qty := (v_item->>'qty')::integer;
    if v_qty < 1 or v_qty > 20 then raise exception 'Invalid quantity'; end if;
    select coalesce((p->>'stock')::integer,0) into v_stock
      from jsonb_array_elements(v_catalog->'products') p where (p->>'id')::bigint = v_pid and coalesce((p->>'active')::boolean,true);
    if not found then raise exception 'Product % is unavailable', v_pid; end if;
    if v_stock < (select coalesce(sum((x->>'qty')::integer),0) from jsonb_array_elements(p_items) x where (x->>'pid')::bigint = v_pid) then
      raise exception 'Insufficient stock for product %', v_pid;
    end if;
  end loop;
  for v_product in select value from jsonb_array_elements(v_catalog->'products') loop
    v_pid := (v_product->>'id')::bigint;
    select coalesce(sum((x->>'qty')::integer),0) into v_qty from jsonb_array_elements(p_items) x where (x->>'pid')::bigint = v_pid;
    if v_qty > 0 then
      v_product := jsonb_set(v_product, '{stock}', to_jsonb(greatest(0, coalesce((v_product->>'stock')::integer,0) - v_qty)), true);
    end if;
    v_products := v_products || jsonb_build_array(v_product);
  end loop;
  v_catalog := jsonb_set(v_catalog, '{products}', v_products, true);
  update public.app_data set data = v_catalog, updated_at = now() where key = 'catalog';
  return jsonb_build_object('reserved', true);
end; $$;

create or replace function public.release_catalog_stock(p_items jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_catalog jsonb;
  v_products jsonb := '[]'::jsonb;
  v_product jsonb;
  v_pid bigint;
  v_qty integer;
begin
  select data into v_catalog from public.app_data where key = 'catalog' for update;
  if v_catalog is null then raise exception 'Catalog is not configured'; end if;
  for v_product in select value from jsonb_array_elements(v_catalog->'products') loop
    v_pid := (v_product->>'id')::bigint;
    select coalesce(sum((x->>'qty')::integer),0) into v_qty from jsonb_array_elements(p_items) x where (x->>'pid')::bigint = v_pid;
    if v_qty > 0 then
      v_product := jsonb_set(v_product, '{stock}', to_jsonb(coalesce((v_product->>'stock')::integer,0) + v_qty), true);
    end if;
    v_products := v_products || jsonb_build_array(v_product);
  end loop;
  v_catalog := jsonb_set(v_catalog, '{products}', v_products, true);
  update public.app_data set data = v_catalog, updated_at = now() where key = 'catalog';
  return jsonb_build_object('released', true);
end; $$;
revoke all on function public.reserve_catalog_stock(jsonb) from public, anon, authenticated;
revoke all on function public.release_catalog_stock(jsonb) from public, anon, authenticated;
grant execute on function public.reserve_catalog_stock(jsonb) to service_role;
grant execute on function public.release_catalog_stock(jsonb) to service_role;

-- Close client-side privilege-escalation paths inherited from the first schema.
drop policy if exists orders_insert on public.orders;
drop policy if exists orders_update on public.orders;
drop policy if exists app_write on public.app_data;
create policy app_write on public.app_data for all to authenticated
  using (public.has_permission('catalog.manage'))
  with check (public.has_permission('catalog.manage'));
create policy orders_update on public.orders for update to authenticated
  using (public.has_permission('orders.manage'))
  with check (public.has_permission('orders.manage'));
revoke insert on public.orders from anon, authenticated;

-- Membership entitlements must be granted by verified server-side payment workflows.
drop policy if exists mem_insert on public.memberships;
drop policy if exists mem_update on public.memberships;
revoke insert, update, delete on public.memberships from anon, authenticated;

-- The old app allowed any signed-in customer to insert an order with arbitrary totals.
-- New order creation is exclusively through razorpay-checkout Edge Function/service role.

-- Permission-scoped reads for staff/X-admins.
drop policy if exists orders_select on public.orders;
create policy orders_select on public.orders for select to authenticated
  using (user_id = auth.uid() or public.has_permission('orders.view'));
drop policy if exists admin_roles_read_self on public.admin_roles;
create policy admin_roles_read_self on public.admin_roles for select to authenticated
  using (user_id = auth.uid() or public.has_permission('admins.manage'));
drop policy if exists mem_select on public.memberships;
create policy mem_select on public.memberships for select to authenticated
  using (user_id = auth.uid() or public.has_permission('memberships.view'));

-- Replace broad admin policies with capability-specific policies.
do $$ declare t text; begin
  foreach t in array array['product_policies','membership_plans','suppliers','supplier_order_lines','supplier_payments','admin_messages','audit_logs','app_remote_config'] loop
    execute format('drop policy if exists %I on public.%I', t || '_admin_all', t);
  end loop;
end $$;
create policy product_policies_manage on public.product_policies for all to authenticated
  using (public.has_permission('catalog.manage')) with check (public.has_permission('catalog.manage'));
create policy membership_plans_manage on public.membership_plans for all to authenticated
  using (public.has_permission('memberships.manage')) with check (public.has_permission('memberships.manage'));
create policy suppliers_manage on public.suppliers for all to authenticated
  using (public.has_permission('suppliers.manage')) with check (public.has_permission('suppliers.manage'));
create policy supplier_order_lines_manage on public.supplier_order_lines for all to authenticated
  using (public.has_permission('suppliers.manage')) with check (public.has_permission('suppliers.manage'));
create policy supplier_payments_manage on public.supplier_payments for all to authenticated
  using (public.has_permission('suppliers.pay')) with check (public.has_permission('suppliers.pay'));
create policy admin_messages_manage on public.admin_messages for all to authenticated
  using (public.has_permission('notifications.manage')) with check (public.has_permission('notifications.manage'));
create policy audit_logs_read on public.audit_logs for select to authenticated
  using (public.has_permission('audit.view'));
create policy app_remote_config_manage on public.app_remote_config for all to authenticated
  using (public.has_permission('settings.manage')) with check (public.has_permission('settings.manage'));
revoke insert, update, delete on public.audit_logs from anon, authenticated;

-- Customer-readable product policy and active membership plan catalogue.
drop policy if exists product_policies_customer_read on public.product_policies;
create policy product_policies_customer_read on public.product_policies for select to authenticated
  using (true);
drop policy if exists membership_plans_customer_read on public.membership_plans;
create policy membership_plans_customer_read on public.membership_plans for select to authenticated
  using (active = true or public.has_permission('memberships.manage'));
drop policy if exists return_requests_admin_manage on public.return_requests;
create policy return_requests_admin_manage on public.return_requests for update to authenticated
  using (public.has_permission('returns.manage')) with check (public.has_permission('returns.manage'));
drop policy if exists refund_records_owner_read on public.refund_records;
create policy refund_records_owner_read on public.refund_records for select to authenticated
  using (user_id = auth.uid() or public.has_permission('refunds.manage'));
drop policy if exists refund_payout_admin_read on public.refund_payout_details;
create policy refund_payout_admin_read on public.refund_payout_details for select to authenticated
  using (user_id = auth.uid() or public.has_permission('refunds.manage'));
drop policy if exists support_ticket_admin_manage on public.support_tickets;
create policy support_ticket_admin_manage on public.support_tickets for update to authenticated
  using (public.has_permission('support.manage')) with check (public.has_permission('support.manage'));
drop policy if exists support_messages_admin_insert on public.support_messages;
create policy support_messages_admin_insert on public.support_messages for insert to authenticated
  with check (sender_id = auth.uid() and public.has_permission('support.manage'));


insert into public.app_remote_config(key,value) values
('loyalty.earning_percent','3.5'::jsonb),
('loyalty.point_value_rupees','1'::jsonb),
('loyalty.default_redeem_min_cart','500'::jsonb),
('loyalty.default_redeem_cap_percent','20'::jsonb),
('delivery.fixed_fee_rupees','69'::jsonb),
('delivery.free_above_rupees','999'::jsonb),
('returns.default_window_days','7'::jsonb),
('branding.logo_url','""'::jsonb),
('maintenance.enabled','false'::jsonb)
on conflict (key) do nothing;

create unique index if not exists payment_receipts_one_per_order on public.payment_receipts(order_id);
create unique index if not exists orders_payment_id_unique on public.orders(payment_id) where payment_id is not null;

-- Serialize capture/webhook/client-callback processing so a single order gets one receipt.
create or replace function public.confirm_razorpay_payment(
  p_order_id text,
  p_payment_id text,
  p_receipt_data jsonb
) returns text language plpgsql security definer set search_path = public as $$
declare
  v_order public.orders%rowtype;
  v_receipt text;
  v_data jsonb;
  v_attempt uuid;
begin
  select * into v_order from public.orders where id = p_order_id for update;
  if not found then raise exception 'Order not found'; end if;
  if v_order.payment_status = 'captured' then return coalesce(v_order.receipt_number,''); end if;
  v_receipt := coalesce(v_order.receipt_number, public.make_receipt_number());
  v_data := coalesce(v_order.data,'{}'::jsonb) || coalesce(p_receipt_data,'{}'::jsonb);
  v_data := jsonb_set(v_data, '{receiptNumber}', to_jsonb(v_receipt), true);
  v_data := jsonb_set(v_data, '{paymentId}', to_jsonb(p_payment_id), true);
  v_data := jsonb_set(v_data, '{payment}', to_jsonb('Online (Paid)'::text), true);
  v_data := jsonb_set(v_data, '{status}', to_jsonb('Placed'::text), true);
  update public.orders set status='Placed', data=v_data, payment_status='captured',
    payment_id=p_payment_id, receipt_number=v_receipt, updated_at=now() where id=p_order_id;
  select id into v_attempt from public.payment_attempts where provider_order_id = v_order.payment_order_id limit 1;
  insert into public.payment_receipts(receipt_number,order_id,user_id,payment_attempt_id,amount_paise,payment_method,transaction_reference,receipt_data)
  values(v_receipt,p_order_id,v_order.user_id,v_attempt,coalesce(v_order.amount_paise,0),'Razorpay',p_payment_id,v_data)
  on conflict (order_id) do nothing;
  update public.payment_attempts set provider_payment_id=p_payment_id,status='captured',updated_at=now()
    where provider_order_id=v_order.payment_order_id;
  return v_receipt;
end; $$;
revoke all on function public.confirm_razorpay_payment(text,text,jsonb) from public, anon, authenticated;
grant execute on function public.confirm_razorpay_payment(text,text,jsonb) to service_role;

-- Restrict device-token administration and customer-submitted references to owned records.
drop policy if exists device_tokens_owner_all on public.device_tokens;
create policy device_tokens_owner_all on public.device_tokens for all to authenticated
  using (user_id = auth.uid() or public.has_permission('notifications.manage'))
  with check (user_id = auth.uid() or public.has_permission('notifications.manage'));
drop policy if exists reviews_insert on public.reviews;
create policy reviews_insert on public.reviews for insert to authenticated with check (
  user_id = auth.uid() and exists (
    select 1 from public.orders o
    where o.user_id = auth.uid() and o.status = 'Delivered'
      and o.data -> 'items' @> jsonb_build_array(jsonb_build_object('pid', reviews.product_id))
  )
);
drop policy if exists returns_owner_insert on public.return_requests;
create policy returns_owner_insert on public.return_requests for insert to authenticated with check (
  user_id = auth.uid() and exists (
    select 1 from public.orders o where o.id = order_id and o.user_id = auth.uid() and o.status = 'Delivered'
  )
);
drop policy if exists support_ticket_owner_insert on public.support_tickets;
create policy support_ticket_owner_insert on public.support_tickets for insert to authenticated with check (
  user_id = auth.uid() and (order_id is null or exists (
    select 1 from public.orders o where o.id = order_id and o.user_id = auth.uid()
  ))
);

alter table public.orders add column if not exists checkout_request_id text;
create unique index if not exists orders_user_checkout_request_unique
  on public.orders(user_id, checkout_request_id) where checkout_request_id is not null;

-- Fine-grained admin permissions for operational tables.
drop policy if exists product_policies_admin_all on public.product_policies;
create policy product_policies_admin_all on public.product_policies for all to authenticated using (public.has_permission('products.manage')) with check (public.has_permission('products.manage'));
drop policy if exists membership_plans_admin_all on public.membership_plans;
create policy membership_plans_admin_all on public.membership_plans for all to authenticated using (public.has_permission('membership.manage')) with check (public.has_permission('membership.manage'));
drop policy if exists suppliers_admin_all on public.suppliers;
create policy suppliers_admin_all on public.suppliers for all to authenticated using (public.has_permission('suppliers.manage')) with check (public.has_permission('suppliers.manage'));
drop policy if exists supplier_order_lines_admin_all on public.supplier_order_lines;
create policy supplier_order_lines_admin_all on public.supplier_order_lines for all to authenticated using (public.has_permission('suppliers.manage')) with check (public.has_permission('suppliers.manage'));
drop policy if exists supplier_payments_admin_all on public.supplier_payments;
create policy supplier_payments_admin_all on public.supplier_payments for all to authenticated using (public.has_permission('suppliers.manage')) with check (public.has_permission('suppliers.manage'));
drop policy if exists admin_messages_admin_all on public.admin_messages;
create policy admin_messages_admin_all on public.admin_messages for all to authenticated using (public.has_permission('messages.send')) with check (public.has_permission('messages.send'));
drop policy if exists audit_logs_admin_all on public.audit_logs;
create policy audit_logs_admin_read on public.audit_logs for select to authenticated using (public.has_permission('audit.view'));
drop policy if exists app_remote_config_admin_all on public.app_remote_config;
create policy app_remote_config_admin_all on public.app_remote_config for all to authenticated using (public.has_permission('settings.manage')) with check (public.has_permission('settings.manage'));

-- Operational data access is explicitly permission-scoped.
drop policy if exists returns_owner_read on public.return_requests;
create policy returns_owner_read on public.return_requests for select to authenticated using (user_id = auth.uid() or public.has_permission('returns.manage'));
drop policy if exists return_requests_admin_manage on public.return_requests;
create policy return_requests_admin_manage on public.return_requests for update to authenticated using (public.has_permission('returns.manage')) with check (public.has_permission('returns.manage'));
drop policy if exists support_ticket_admin_manage on public.support_tickets;
create policy support_ticket_admin_manage on public.support_tickets for update to authenticated using (public.has_permission('support.manage')) with check (public.has_permission('support.manage'));

-- Compatibility aliases plus a separate order-update capability (Staff is read-only).
create or replace function public.has_permission(permission_key text)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.admin_roles ar
    where ar.user_id = auth.uid() and ar.active = true
      and (ar.role = 'super_admin' or coalesce((ar.permissions ->> permission_key)::boolean,false)
        or coalesce((ar.permissions ->> '*')::boolean,false)
        or (permission_key = 'catalog.manage' and coalesce((ar.permissions ->> 'products.manage')::boolean,false))
        or (permission_key = 'orders.view' and coalesce((ar.permissions ->> 'orders.manage')::boolean,false)))
  ) or exists (
    select 1 from public.admins a
    where lower(a.email) = lower(coalesce(auth.jwt() ->> 'email',''))
  );
$$;
drop policy if exists orders_update on public.orders;
create policy orders_update on public.orders for update to authenticated
  using (public.has_permission('orders.update'))
  with check (public.has_permission('orders.update'));
