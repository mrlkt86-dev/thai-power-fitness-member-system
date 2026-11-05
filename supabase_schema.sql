-- MyMemberHub 2.0 schema for Supabase (PostgreSQL)
-- Run this in Supabase SQL Editor. Creates a fresh database structure; it does not import or modify the old HTML app.
create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default '',
  role text not null check (role in ('owner','staff')) default 'staff',
  created_at timestamptz not null default now()
);

create table if not exists public.members (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  phone text,
  category text not null default '成人',
  plan text not null default '月费',
  fee numeric(10,2) not null default 0 check (fee >= 0),
  sessions_total integer check (sessions_total is null or sessions_total >= 0),
  sessions_remaining integer check (sessions_remaining is null or sessions_remaining >= 0),
  start_date date not null default current_date,
  note text,
  status text not null default 'active' check (status in ('active','inactive')),
  created_at timestamptz not null default now()
);

create table if not exists public.payments (
  id uuid primary key default gen_random_uuid(),
  member_id uuid not null references public.members(id) on delete cascade,
  amount numeric(10,2) not null check (amount >= 0),
  plan text,
  confirmed_by uuid not null references public.profiles(id),
  paid_at timestamptz not null default now()
);

create table if not exists public.checkins (
  id uuid primary key default gen_random_uuid(),
  member_id uuid not null references public.members(id) on delete cascade,
  staff_id uuid not null references public.profiles(id),
  checked_at timestamptz not null default now()
);

alter table public.profiles enable row level security;
alter table public.members enable row level security;
alter table public.payments enable row level security;
alter table public.checkins enable row level security;

create or replace function public.current_app_role()
returns text language sql stable security definer set search_path = public
as $$ select role from public.profiles where id = auth.uid() $$;

-- Authenticated users can see profiles; only owner can create/change profiles.
drop policy if exists "profiles read authenticated" on public.profiles;
create policy "profiles read authenticated" on public.profiles for select to authenticated using (true);
drop policy if exists "profiles owner manage" on public.profiles;
create policy "profiles owner manage" on public.profiles for all to authenticated
using (public.current_app_role()='owner') with check (public.current_app_role()='owner');

-- All signed-in staff/owner can read members. Only owner can insert/update/delete.
drop policy if exists "members read authenticated" on public.members;
create policy "members read authenticated" on public.members for select to authenticated using (true);
drop policy if exists "members owner insert" on public.members;
create policy "members owner insert" on public.members for insert to authenticated with check (public.current_app_role()='owner');
drop policy if exists "members owner update" on public.members;
create policy "members owner update" on public.members for update to authenticated using (public.current_app_role()='owner') with check (public.current_app_role()='owner');
drop policy if exists "members owner delete" on public.members;
create policy "members owner delete" on public.members for delete to authenticated using (public.current_app_role()='owner');

-- Staff can register check-ins; they cannot edit member rows or payments.
drop policy if exists "checkins read authenticated" on public.checkins;
create policy "checkins read authenticated" on public.checkins for select to authenticated using (true);
drop policy if exists "checkins insert authenticated" on public.checkins;
create policy "checkins insert authenticated" on public.checkins for insert to authenticated
with check (staff_id=auth.uid() and public.current_app_role() in ('owner','staff'));

-- Only owner can read or write payment records.
drop policy if exists "payments owner read" on public.payments;
create policy "payments owner read" on public.payments for select to authenticated using (public.current_app_role()='owner');
drop policy if exists "payments owner insert" on public.payments;
create policy "payments owner insert" on public.payments for insert to authenticated
with check (confirmed_by=auth.uid() and public.current_app_role()='owner');
drop policy if exists "payments owner update" on public.payments;
create policy "payments owner update" on public.payments for update to authenticated
using (public.current_app_role()='owner') with check (public.current_app_role()='owner');
drop policy if exists "payments owner delete" on public.payments;
create policy "payments owner delete" on public.payments for delete to authenticated using (public.current_app_role()='owner');

-- Decrease remaining sessions atomically whenever a check-in is recorded.
create or replace function public.decrement_member_sessions()
returns trigger language plpgsql security definer set search_path = public
as $$
declare
  remaining integer;
begin
  select sessions_remaining into remaining
  from public.members where id = new.member_id for update;

  if not found then
    raise exception 'Member not found';
  end if;

  if remaining is not null then
    if remaining <= 0 then
      raise exception 'No sessions remaining';
    end if;
    update public.members
    set sessions_remaining = sessions_remaining - 1
    where id = new.member_id;
  end if;

  return new;
end $$;
drop trigger if exists checkin_decrement_sessions on public.checkins;
create trigger checkin_decrement_sessions after insert on public.checkins
for each row execute function public.decrement_member_sessions();

grant usage on schema public to authenticated;
grant select, insert, update, delete on public.profiles, public.members, public.payments, public.checkins to authenticated;

-- IMPORTANT: create the first owner account in Supabase Authentication first,
-- then insert/update its profile row as owner from SQL Editor:
-- insert into public.profiles(id, display_name, role)
-- values ('AUTH_USER_UUID_HERE', 'Thai Power Fitness Owner', 'owner')
-- on conflict (id) do update set role='owner', display_name=excluded.display_name;
-- For staff accounts, create Auth users then insert profiles with role='staff'.
