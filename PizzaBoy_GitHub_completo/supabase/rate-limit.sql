-- Eseguire in Supabase SQL Editor insieme a supabase-setup.sql
create table if not exists public.pb_public_rate_limits (
  ip_hash text primary key,
  window_start timestamptz not null,
  hits integer not null default 1
);
alter table public.pb_public_rate_limits enable row level security;
revoke all on public.pb_public_rate_limits from anon, authenticated;
create or replace function public.pb_consume_public_rate_limit(p_ip text)
returns boolean language plpgsql security definer set search_path=pg_catalog,public as $$
declare h text; ok boolean;
begin
  h := encode(digest(coalesce(p_ip,'unknown') || coalesce(current_setting('app.settings.rate_salt',true),'pizza-boy-rate-limit-v1'), 'sha256'),'hex');
  insert into public.pb_public_rate_limits(ip_hash,window_start,hits) values(h,now(),1)
  on conflict(ip_hash) do update set
    hits=case when public.pb_public_rate_limits.window_start < now()-interval '10 minutes' then 1 else public.pb_public_rate_limits.hits+1 end,
    window_start=case when public.pb_public_rate_limits.window_start < now()-interval '10 minutes' then now() else public.pb_public_rate_limits.window_start end;
  select hits <= 8 into ok from public.pb_public_rate_limits where ip_hash=h;
  return coalesce(ok,false);
end; $$;
revoke all on function public.pb_consume_public_rate_limit(text) from public,anon,authenticated;
grant execute on function public.pb_consume_public_rate_limit(text) to service_role;
