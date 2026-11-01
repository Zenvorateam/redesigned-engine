-- Supabase > SQL Editor me poora paste karke RUN karo.
-- Phir niche wali line me apna admin email daalna.

create table if not exists public.admins (email text primary key);
-- insert into public.admins (email) values ('you@example.com');   -- <- apna email (config.dart wala same)

create or replace function public.is_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.admins where lower(email) = lower(coalesce(auth.jwt() ->> 'email', '')));
$$;

-- ORDERS
create table if not exists public.orders (
  id text primary key,
  user_id uuid references auth.users(id) on delete set null,
  user_email text,
  status text not null default 'Placed',
  data jsonb not null,
  created_at timestamptz not null default now()
);
alter table public.orders enable row level security;
drop policy if exists orders_select on public.orders;
drop policy if exists orders_insert on public.orders;
drop policy if exists orders_update on public.orders;
create policy orders_select on public.orders for select using (user_id = auth.uid() or public.is_admin());
create policy orders_insert on public.orders for insert with check (user_id = auth.uid());
create policy orders_update on public.orders for update
  using (public.is_admin() or (user_id = auth.uid() and status in ('Placed','Confirmed')))
  with check (public.is_admin() or (user_id = auth.uid() and status = 'Cancelled'));

-- REVIEWS (sirf wahi user jisne product order kiya ho)
create table if not exists public.reviews (
  id bigint generated always as identity primary key,
  product_id int not null,
  user_id uuid not null references auth.users(id) on delete cascade,
  name text,
  rating int not null check (rating between 1 and 5),
  body text default '',
  created_at timestamptz not null default now(),
  unique (product_id, user_id)
);
alter table public.reviews enable row level security;
drop policy if exists reviews_select on public.reviews;
drop policy if exists reviews_insert on public.reviews;
create policy reviews_select on public.reviews for select using (true);
create policy reviews_insert on public.reviews for insert with check (
  user_id = auth.uid()
  and exists (
    select 1 from public.orders o
    where o.user_id = auth.uid()
      and o.status <> 'Cancelled'
      and o.data -> 'items' @> jsonb_build_array(jsonb_build_object('pid', reviews.product_id))
  )
);

-- MEMBERSHIP
create table if not exists public.memberships (
  user_id uuid primary key references auth.users(id) on delete cascade,
  active_until timestamptz not null,
  payment_id text
);
alter table public.memberships enable row level security;
drop policy if exists mem_select on public.memberships;
drop policy if exists mem_insert on public.memberships;
drop policy if exists mem_update on public.memberships;
create policy mem_select on public.memberships for select using (user_id = auth.uid() or public.is_admin());
create policy mem_insert on public.memberships for insert with check (user_id = auth.uid());
create policy mem_update on public.memberships for update using (user_id = auth.uid()) with check (user_id = auth.uid());

-- STORE DATA (products, banners, coupons, settings) - sab customers padhenge, sirf admin likhega
create table if not exists public.app_data (
  key text primary key,
  data jsonb not null,
  updated_at timestamptz not null default now()
);
alter table public.app_data enable row level security;
drop policy if exists app_select on public.app_data;
drop policy if exists app_write on public.app_data;
create policy app_select on public.app_data for select using (true);
create policy app_write on public.app_data for all using (public.is_admin()) with check (public.is_admin());


-- FCM device registrations (one token per user/device).
create table if not exists public.device_tokens (
  id bigint generated always as identity primary key,
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  token text not null unique,
  platform text not null default 'android',
  updated_at timestamptz not null default now()
);
alter table public.device_tokens enable row level security;
drop policy if exists device_tokens_owner_all on public.device_tokens;
create policy device_tokens_owner_all on public.device_tokens
  for all using (user_id = auth.uid() or public.is_admin())
  with check (user_id = auth.uid() or public.is_admin());
