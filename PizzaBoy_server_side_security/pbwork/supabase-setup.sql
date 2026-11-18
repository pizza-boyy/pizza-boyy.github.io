-- PIZZA BOY — schema e policy di sicurezza Supabase
-- Puoi rieseguire questo script: le policy vengono ricreate in modo idempotente.
create extension if not exists pgcrypto;

create table if not exists public.pb_admin_users (
  user_id uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);
create table if not exists public.pb_orders (
  id uuid primary key default gen_random_uuid(),
  payload jsonb not null check (
    jsonb_typeof(payload) = 'object'
    and octet_length(payload::text) <= 16000
    and coalesce(length(payload->>'customer'),0) between 1 and 120
  ),
  status text not null default 'Nuovo' check (status in ('Nuovo','In preparazione','Pronto','Completato','Annullato')),
  created_at timestamptz not null default now()
);
create table if not exists public.pb_bookings (
  id uuid primary key default gen_random_uuid(),
  payload jsonb not null check (
    jsonb_typeof(payload) = 'object'
    and octet_length(payload::text) <= 10000
    and coalesce(length(payload->>'name'),0) between 1 and 120
  ),
  status text not null default 'In attesa' check (status in ('In attesa','Confermata','Completata','Annullata')),
  created_at timestamptz not null default now()
);

-- Aggiunge anche ai database già creati i vincoli più stretti.
do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'pb_orders_payload_guard' and conrelid = 'public.pb_orders'::regclass) then
    alter table public.pb_orders add constraint pb_orders_payload_guard check (
      jsonb_typeof(payload) = 'object' and octet_length(payload::text) <= 16000
      and coalesce(length(payload->>'customer'),0) between 1 and 120
    );
  end if;
  if not exists (select 1 from pg_constraint where conname = 'pb_orders_status_guard' and conrelid = 'public.pb_orders'::regclass) then
    alter table public.pb_orders add constraint pb_orders_status_guard check (status in ('Nuovo','In preparazione','Pronto','Completato','Annullato'));
  end if;
  if not exists (select 1 from pg_constraint where conname = 'pb_bookings_payload_guard' and conrelid = 'public.pb_bookings'::regclass) then
    alter table public.pb_bookings add constraint pb_bookings_payload_guard check (
      jsonb_typeof(payload) = 'object' and octet_length(payload::text) <= 10000
      and coalesce(length(payload->>'name'),0) between 1 and 120
    );
  end if;
  if not exists (select 1 from pg_constraint where conname = 'pb_bookings_status_guard' and conrelid = 'public.pb_bookings'::regclass) then
    alter table public.pb_bookings add constraint pb_bookings_status_guard check (status in ('In attesa','Confermata','Completata','Annullata'));
  end if;
end $$;

-- Controllo amministratore: funzione con search_path fisso per evitare object shadowing.
create or replace function public.pb_is_admin()
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select exists (
    select 1 from public.pb_admin_users a where a.user_id = auth.uid()
  );
$$;
revoke all on function public.pb_is_admin() from public;
grant execute on function public.pb_is_admin() to authenticated;

alter table public.pb_admin_users enable row level security;
alter table public.pb_orders enable row level security;
alter table public.pb_bookings enable row level security;

-- Nessun visitatore anonimo può leggere dati o modificare record esistenti.
drop policy if exists "public can submit orders" on public.pb_orders;
create policy "public can submit orders" on public.pb_orders
  for insert to anon, authenticated
  with check (
    jsonb_typeof(payload) = 'object'
    and octet_length(payload::text) <= 16000
    and coalesce(length(payload->>'customer'),0) between 1 and 120
  );
drop policy if exists "public can submit bookings" on public.pb_bookings;
create policy "public can submit bookings" on public.pb_bookings
  for insert to anon, authenticated
  with check (
    jsonb_typeof(payload) = 'object'
    and octet_length(payload::text) <= 10000
    and coalesce(length(payload->>'name'),0) between 1 and 120
  );

-- Solo amministratori esplicitamente autorizzati possono leggere i dati.
drop policy if exists "admins read orders" on public.pb_orders;
create policy "admins read orders" on public.pb_orders
  for select to authenticated using (public.pb_is_admin());
drop policy if exists "admins update orders" on public.pb_orders;
create policy "admins update orders" on public.pb_orders
  for update to authenticated using (public.pb_is_admin()) with check (public.pb_is_admin());
drop policy if exists "admins read bookings" on public.pb_bookings;
create policy "admins read bookings" on public.pb_bookings
  for select to authenticated using (public.pb_is_admin());
drop policy if exists "admins update bookings" on public.pb_bookings;
create policy "admins update bookings" on public.pb_bookings
  for update to authenticated using (public.pb_is_admin()) with check (public.pb_is_admin());
drop policy if exists "admins see own admin record" on public.pb_admin_users;
create policy "admins see own admin record" on public.pb_admin_users
  for select to authenticated using (user_id = auth.uid());

-- Privilegi minimi: il client pubblico può solo inviare; l'admin può cambiare SOLO status.
revoke all on public.pb_admin_users from anon, authenticated;
revoke all on public.pb_orders from anon, authenticated;
revoke all on public.pb_bookings from anon, authenticated;
grant select on public.pb_admin_users to authenticated;
grant insert on public.pb_orders, public.pb_bookings to anon, authenticated;
grant select on public.pb_orders, public.pb_bookings to authenticated;
grant update (status) on public.pb_orders, public.pb_bookings to authenticated;

-- Gli invii pubblici passano esclusivamente dalla Edge Function con service role.
revoke insert on public.pb_orders, public.pb_bookings from anon, authenticated;
