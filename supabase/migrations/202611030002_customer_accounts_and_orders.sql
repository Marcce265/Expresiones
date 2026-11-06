create table if not exists public.customer_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null check (char_length(trim(full_name)) between 2 and 100),
  phone text not null unique check (phone ~ '^[0-9]{9}$'),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.customer_orders (
  id text primary key,
  user_id uuid not null references auth.users(id) on delete restrict,
  status text not null default 'paid_simulated'
    check (status = 'paid_simulated'),
  total numeric(12, 2) not null check (total > 0),
  total_quantity integer not null check (total_quantity > 0),
  customer_name text not null,
  customer_phone text not null,
  delivery_method text not null check (delivery_method in ('pickup', 'shalom')),
  payment_reference text not null unique,
  payment_method text not null,
  snapshot jsonb not null check (jsonb_typeof(snapshot) = 'object'),
  created_at timestamptz not null default now()
);

create index if not exists customer_orders_user_created_idx
  on public.customer_orders (user_id, created_at desc);
create index if not exists customer_orders_created_idx
  on public.customer_orders (created_at desc);

alter table public.customer_profiles enable row level security;
alter table public.customer_orders enable row level security;

drop policy if exists customer_profiles_read_own on public.customer_profiles;
create policy customer_profiles_read_own
  on public.customer_profiles for select to authenticated
  using ((select auth.uid()) = user_id or public.can_admin_write());

drop policy if exists customer_profiles_update_own on public.customer_profiles;
create policy customer_profiles_update_own
  on public.customer_profiles for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

drop policy if exists customer_orders_read_own_or_admin on public.customer_orders;
create policy customer_orders_read_own_or_admin
  on public.customer_orders for select to authenticated
  using ((select auth.uid()) = user_id or public.can_admin_write());

drop policy if exists customer_orders_insert_own on public.customer_orders;
create policy customer_orders_insert_own
  on public.customer_orders for insert to authenticated
  with check ((select auth.uid()) = user_id);

create or replace function public.create_customer_profile()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.raw_user_meta_data ->> 'account_type' = 'customer' then
    insert into public.customer_profiles (user_id, full_name, phone)
    values (
      new.id,
      trim(new.raw_user_meta_data ->> 'full_name'),
      regexp_replace(coalesce(new.raw_user_meta_data ->> 'phone', ''), '\D', '', 'g')
    );
  end if;
  return new;
end;
$$;

drop trigger if exists create_customer_profile_after_signup on auth.users;
create trigger create_customer_profile_after_signup
  after insert on auth.users
  for each row execute function public.create_customer_profile();

revoke all on function public.create_customer_profile() from public, anon, authenticated;

grant select, update on public.customer_profiles to authenticated;
grant select, insert on public.customer_orders to authenticated;
