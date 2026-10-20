-- Expresiones: catalog, administration, capacity and Storage foundation.
-- The public application is read-only. Every administrative write requires
-- both membership in public.admins and a Supabase MFA session at AAL2.

create extension if not exists pgcrypto with schema extensions;

do $$
begin
  create type public.product_kind as enum ('material', 'bouquet', 'gift');
exception
  when duplicate_object then null;
end
$$;

do $$
begin
  create type public.catalog_stock_status as enum (
    'in_stock',
    'low_stock',
    'out_of_stock',
    'made_to_order',
    'check_availability'
  );
exception
  when duplicate_object then null;
end
$$;

create table if not exists public.categories (
  id uuid primary key default gen_random_uuid(),
  slug text not null,
  name text not null,
  kind public.product_kind not null,
  description text not null default '',
  active boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  created_by uuid references auth.users(id) on delete set null,
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users(id) on delete set null,
  constraint categories_slug_unique unique (slug),
  constraint categories_slug_format check (slug ~ '^[a-z0-9]+(?:[_-][a-z0-9]+)*$'),
  constraint categories_name_length check (char_length(btrim(name)) between 1 and 120),
  constraint categories_description_length check (char_length(description) <= 1500),
  constraint categories_sort_order_range check (sort_order between 0 and 1000000)
);

create table if not exists public.families (
  id uuid primary key default gen_random_uuid(),
  slug text not null,
  name text not null,
  category_id uuid not null references public.categories(id) on delete restrict,
  kind public.product_kind not null default 'material',
  description text not null default '',
  sku text,
  sale_unit text not null default 'unidad',
  base_price numeric(12,2) not null default 0,
  starting_at boolean not null default false,
  price_is_reference boolean not null default false,
  stock_count integer,
  stock_status public.catalog_stock_status not null default 'check_availability',
  prep_days integer not null default 0,
  production_points integer not null default 0,
  tags text[] not null default '{}',
  attributes jsonb not null default '{}'::jsonb,
  cover_path text,
  cover_thumb_path text,
  cover_detail_path text,
  active boolean not null default true,
  featured boolean not null default false,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  created_by uuid references auth.users(id) on delete set null,
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users(id) on delete set null,
  constraint families_slug_unique unique (slug),
  constraint families_slug_format check (slug ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$'),
  constraint families_name_length check (char_length(btrim(name)) between 1 and 160),
  constraint families_description_length check (char_length(description) <= 3000),
  constraint families_sku_length check (sku is null or char_length(sku) between 1 and 100),
  constraint families_sale_unit_length check (char_length(btrim(sale_unit)) between 1 and 40),
  constraint families_base_price_range check (base_price between 0 and 1000000000),
  constraint families_stock_count_range check (stock_count is null or stock_count between 0 and 100000000),
  constraint families_prep_days_range check (prep_days between 0 and 365),
  constraint families_production_points_range check (production_points between 0 and 1000000),
  constraint families_sort_order_range check (sort_order between 0 and 1000000),
  constraint families_attributes_object check (jsonb_typeof(attributes) = 'object')
);

create unique index if not exists families_sku_unique
  on public.families (lower(sku))
  where sku is not null and btrim(sku) <> '';
create index if not exists families_public_order_idx
  on public.families (active, sort_order, name);
create index if not exists families_category_idx
  on public.families (category_id);

create table if not exists public.variants (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.families(id) on delete cascade,
  slug text not null,
  name text not null,
  sku text,
  color_hex text,
  attributes jsonb not null default '{}'::jsonb,
  base_price numeric(12,2),
  price_is_reference boolean not null default false,
  stock_count integer,
  stock_status public.catalog_stock_status not null default 'check_availability',
  prep_days integer,
  production_points integer,
  image_path text,
  thumb_path text,
  detail_path text,
  active boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  created_by uuid references auth.users(id) on delete set null,
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users(id) on delete set null,
  constraint variants_family_slug_unique unique (family_id, slug),
  constraint variants_slug_format check (slug ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$'),
  constraint variants_name_length check (char_length(btrim(name)) between 1 and 160),
  constraint variants_sku_length check (sku is null or char_length(sku) between 1 and 100),
  constraint variants_color_hex_format check (color_hex is null or color_hex ~ '^#[0-9A-Fa-f]{6}$'),
  constraint variants_base_price_range check (base_price is null or base_price between 0 and 1000000000),
  constraint variants_stock_count_range check (stock_count is null or stock_count between 0 and 100000000),
  constraint variants_prep_days_range check (prep_days is null or prep_days between 0 and 365),
  constraint variants_production_points_range check (production_points is null or production_points between 0 and 1000000),
  constraint variants_sort_order_range check (sort_order between 0 and 1000000),
  constraint variants_attributes_object check (jsonb_typeof(attributes) = 'object')
);

create unique index if not exists variants_sku_unique
  on public.variants (lower(sku))
  where sku is not null and btrim(sku) <> '';
create index if not exists variants_family_order_idx
  on public.variants (family_id, active, sort_order, name);

create table if not exists public.family_price_tiers (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.families(id) on delete cascade,
  min_qty integer not null,
  unit_price numeric(12,2) not null,
  label text,
  created_at timestamptz not null default now(),
  created_by uuid references auth.users(id) on delete set null,
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users(id) on delete set null,
  constraint family_price_tiers_owner_qty_unique unique (family_id, min_qty),
  constraint family_price_tiers_min_qty_range check (min_qty between 1 and 100000000),
  constraint family_price_tiers_unit_price_range check (unit_price between 0 and 1000000000),
  constraint family_price_tiers_label_length check (label is null or char_length(label) <= 100)
);

create table if not exists public.variant_price_tiers (
  id uuid primary key default gen_random_uuid(),
  variant_id uuid not null references public.variants(id) on delete cascade,
  min_qty integer not null,
  unit_price numeric(12,2) not null,
  label text,
  created_at timestamptz not null default now(),
  created_by uuid references auth.users(id) on delete set null,
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users(id) on delete set null,
  constraint variant_price_tiers_owner_qty_unique unique (variant_id, min_qty),
  constraint variant_price_tiers_min_qty_range check (min_qty between 1 and 100000000),
  constraint variant_price_tiers_unit_price_range check (unit_price between 0 and 1000000000),
  constraint variant_price_tiers_label_length check (label is null or char_length(label) <= 100)
);

create table if not exists public.admins (
  user_id uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  created_at timestamptz not null default now(),
  created_by uuid references auth.users(id) on delete set null,
  constraint admins_display_name_length check (display_name is null or char_length(display_name) <= 120)
);

create table if not exists public.catalog_metadata (
  id text primary key default 'public',
  version bigint not null default 1,
  updated_at timestamptz not null default now(),
  constraint catalog_metadata_singleton check (id = 'public'),
  constraint catalog_metadata_version_positive check (version >= 1)
);

create table if not exists public.availability (
  id text primary key default 'public',
  data jsonb not null,
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users(id) on delete set null,
  constraint availability_singleton check (id = 'public'),
  constraint availability_data_object check (jsonb_typeof(data) = 'object')
);

insert into public.catalog_metadata (id, version)
values ('public', 1)
on conflict (id) do nothing;

insert into public.categories (slug, name, kind, sort_order)
values
  ('materials', 'Materiales', 'material', 10),
  ('bouquets', 'Ramos', 'bouquet', 20),
  ('personalized_gifts', 'Regalos personalizados', 'gift', 30)
on conflict (slug) do update
set name = excluded.name,
    kind = excluded.kind,
    sort_order = excluded.sort_order;

insert into public.availability (id, data)
values (
  'public',
  jsonb_build_object(
    'timezone', 'America/Lima',
    'horizonDays', 120,
    'weeklyCapacityPoints', jsonb_build_object(
      '1', 24, '2', 24, '3', 24, '4', 24, '5', 24, '6', 12, '7', 0
    ),
    'reservedPointsByDate', '{}'::jsonb,
    'overridesByDate', '{}'::jsonb
  )
)
on conflict (id) do nothing;

create or replace function public.is_current_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select (select auth.uid()) is not null
     and exists (
       select 1
       from public.admins a
       where a.user_id = (select auth.uid())
     );
$$;

create or replace function public.is_aal2()
returns boolean
language sql
stable
set search_path = ''
as $$
  select coalesce((select auth.jwt() ->> 'aal'), '') = 'aal2';
$$;

create or replace function public.can_admin_write()
returns boolean
language sql
stable
set search_path = ''
as $$
  select public.is_current_admin() and public.is_aal2();
$$;

create or replace function public.is_family_public(target_family_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.families f
    join public.categories c on c.id = f.category_id
    where f.id = target_family_id
      and f.active
      and c.active
  );
$$;

create or replace function public.is_variant_public(target_variant_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.variants v
    where v.id = target_variant_id
      and v.active
      and public.is_family_public(v.family_id)
  );
$$;

create or replace function public.set_catalog_audit_fields()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := now();
  new.updated_by := (select auth.uid());
  if tg_op = 'INSERT' then
    new.created_at := coalesce(new.created_at, now());
    new.created_by := coalesce(new.created_by, (select auth.uid()));
  end if;
  return new;
end;
$$;

create or replace function public.set_update_audit_fields()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := now();
  new.updated_by := (select auth.uid());
  return new;
end;
$$;

create or replace function public.bump_catalog_version()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.catalog_metadata (id, version, updated_at)
  values ('public', 1, now())
  on conflict (id) do update
  set version = public.catalog_metadata.version + 1,
      updated_at = now();
  return null;
end;
$$;

drop trigger if exists categories_audit on public.categories;
create trigger categories_audit
before insert or update on public.categories
for each row execute function public.set_catalog_audit_fields();
drop trigger if exists families_audit on public.families;
create trigger families_audit
before insert or update on public.families
for each row execute function public.set_catalog_audit_fields();
drop trigger if exists variants_audit on public.variants;
create trigger variants_audit
before insert or update on public.variants
for each row execute function public.set_catalog_audit_fields();
drop trigger if exists family_price_tiers_audit on public.family_price_tiers;
create trigger family_price_tiers_audit
before insert or update on public.family_price_tiers
for each row execute function public.set_catalog_audit_fields();
drop trigger if exists variant_price_tiers_audit on public.variant_price_tiers;
create trigger variant_price_tiers_audit
before insert or update on public.variant_price_tiers
for each row execute function public.set_catalog_audit_fields();
drop trigger if exists availability_audit on public.availability;
create trigger availability_audit
before insert or update on public.availability
for each row execute function public.set_update_audit_fields();

drop trigger if exists categories_bump_catalog on public.categories;
create trigger categories_bump_catalog
after insert or update or delete on public.categories
for each statement execute function public.bump_catalog_version();
drop trigger if exists families_bump_catalog on public.families;
create trigger families_bump_catalog
after insert or update or delete on public.families
for each statement execute function public.bump_catalog_version();
drop trigger if exists variants_bump_catalog on public.variants;
create trigger variants_bump_catalog
after insert or update or delete on public.variants
for each statement execute function public.bump_catalog_version();
drop trigger if exists family_price_tiers_bump_catalog on public.family_price_tiers;
create trigger family_price_tiers_bump_catalog
after insert or update or delete on public.family_price_tiers
for each statement execute function public.bump_catalog_version();
drop trigger if exists variant_price_tiers_bump_catalog on public.variant_price_tiers;
create trigger variant_price_tiers_bump_catalog
after insert or update or delete on public.variant_price_tiers
for each statement execute function public.bump_catalog_version();

alter table public.categories enable row level security;
alter table public.families enable row level security;
alter table public.variants enable row level security;
alter table public.family_price_tiers enable row level security;
alter table public.variant_price_tiers enable row level security;
alter table public.admins enable row level security;
alter table public.catalog_metadata enable row level security;
alter table public.availability enable row level security;

drop policy if exists categories_public_read on public.categories;
create policy categories_public_read on public.categories
for select to anon, authenticated
using (active or public.is_current_admin());
drop policy if exists categories_admin_write on public.categories;
create policy categories_admin_write on public.categories
for all to authenticated
using (public.can_admin_write())
with check (public.can_admin_write());

drop policy if exists families_public_read on public.families;
create policy families_public_read on public.families
for select to anon, authenticated
using (public.is_family_public(id) or public.is_current_admin());
drop policy if exists families_admin_write on public.families;
create policy families_admin_write on public.families
for all to authenticated
using (public.can_admin_write())
with check (public.can_admin_write());

drop policy if exists variants_public_read on public.variants;
create policy variants_public_read on public.variants
for select to anon, authenticated
using (
  (active and public.is_family_public(family_id))
  or public.is_current_admin()
);
drop policy if exists variants_admin_write on public.variants;
create policy variants_admin_write on public.variants
for all to authenticated
using (public.can_admin_write())
with check (public.can_admin_write());

drop policy if exists family_price_tiers_public_read on public.family_price_tiers;
create policy family_price_tiers_public_read on public.family_price_tiers
for select to anon, authenticated
using (public.is_current_admin() or public.is_family_public(family_id));
drop policy if exists family_price_tiers_admin_write on public.family_price_tiers;
create policy family_price_tiers_admin_write on public.family_price_tiers
for all to authenticated
using (public.can_admin_write())
with check (public.can_admin_write());

drop policy if exists variant_price_tiers_public_read on public.variant_price_tiers;
create policy variant_price_tiers_public_read on public.variant_price_tiers
for select to anon, authenticated
using (public.is_current_admin() or public.is_variant_public(variant_id));
drop policy if exists variant_price_tiers_admin_write on public.variant_price_tiers;
create policy variant_price_tiers_admin_write on public.variant_price_tiers
for all to authenticated
using (public.can_admin_write())
with check (public.can_admin_write());

drop policy if exists catalog_metadata_public_read on public.catalog_metadata;
create policy catalog_metadata_public_read on public.catalog_metadata
for select to anon, authenticated
using (id = 'public');

drop policy if exists availability_public_read on public.availability;
create policy availability_public_read on public.availability
for select to anon, authenticated
using (id = 'public');
drop policy if exists availability_admin_write on public.availability;
create policy availability_admin_write on public.availability
for all to authenticated
using (id = 'public' and public.can_admin_write())
with check (id = 'public' and public.can_admin_write());

revoke all on table public.admins from anon, authenticated;
grant select on table public.categories, public.families, public.variants,
  public.family_price_tiers, public.variant_price_tiers,
  public.catalog_metadata, public.availability
to anon, authenticated;
grant insert, update, delete on table public.categories, public.families,
  public.variants, public.family_price_tiers, public.variant_price_tiers,
  public.availability
to authenticated;

revoke all on function public.is_current_admin() from public;
revoke all on function public.is_aal2() from public;
revoke all on function public.can_admin_write() from public;
revoke all on function public.is_family_public(uuid) from public;
revoke all on function public.is_variant_public(uuid) from public;
grant execute on function public.is_current_admin() to anon, authenticated;
grant execute on function public.is_aal2() to authenticated;
grant execute on function public.can_admin_write() to authenticated;
grant execute on function public.is_family_public(uuid) to anon, authenticated;
grant execute on function public.is_variant_public(uuid) to anon, authenticated;

-- Atomic adapter for the current CatalogProduct camelCase payload. This lets
-- Flutter move off Firestore without flattening variants or tiers in the UI.
create or replace function public.admin_save_catalog_family(payload jsonb)
returns table (id uuid, slug text)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_family_id uuid;
  v_family_slug text;
  v_category_slug text;
  v_category_id uuid;
  v_kind public.product_kind;
  v_base_price numeric(12,2);
  v_stock_status public.catalog_stock_status;
  v_tags text[];
  v_attributes jsonb;
  v_tiers jsonb;
  v_variants jsonb;
  v_tier jsonb;
  v_variant jsonb;
  v_variant_id uuid;
  v_variant_slug text;
  v_variant_status public.catalog_stock_status;
  v_variant_ids uuid[] := '{}'::uuid[];
  v_min_qty integer;
  v_unit_price numeric(12,2);
  v_index integer := 0;
begin
  if not public.can_admin_write() then
    raise exception using
      errcode = '42501',
      message = 'Se requiere una cuenta administradora con MFA AAL2.';
  end if;
  if payload is null or jsonb_typeof(payload) <> 'object' then
    raise exception using errcode = '22023', message = 'El producto debe ser un objeto JSON.';
  end if;

  v_family_slug := btrim(coalesce(payload ->> 'id', ''));
  if v_family_slug !~ '^[a-z0-9]+(?:-[a-z0-9]+)*$' then
    raise exception using errcode = '22023', message = 'El id/slug del producto no es válido.';
  end if;
  if char_length(btrim(coalesce(payload ->> 'name', ''))) not between 1 and 160 then
    raise exception using errcode = '22023', message = 'El producto necesita un nombre válido.';
  end if;

  v_category_slug := btrim(coalesce(payload ->> 'category', 'materials'));
  select c.id, c.kind into v_category_id, v_kind
  from public.categories c
  where c.slug = v_category_slug;
  if v_category_id is null then
    raise exception using errcode = '22023', message = 'La categoría no existe.';
  end if;

  v_base_price := coalesce(nullif(payload ->> 'basePrice', '')::numeric, 0);
  if v_base_price < 0 or v_base_price > 1000000000 then
    raise exception using errcode = '22023', message = 'El precio base está fuera de rango.';
  end if;
  v_stock_status := coalesce(nullif(payload ->> 'stockStatus', ''), 'check_availability')::public.catalog_stock_status;
  v_attributes := coalesce(payload -> 'attributes', '{}'::jsonb);
  if jsonb_typeof(v_attributes) <> 'object' then
    raise exception using errcode = '22023', message = 'attributes debe ser un objeto.';
  end if;
  if payload ? 'tags' and jsonb_typeof(payload -> 'tags') <> 'array' then
    raise exception using errcode = '22023', message = 'tags debe ser una lista.';
  end if;
  select coalesce(array_agg(t.value), '{}'::text[]) into v_tags
  from jsonb_array_elements_text(coalesce(payload -> 'tags', '[]'::jsonb)) as t(value);

  insert into public.families as f (
    slug, name, category_id, kind, description, sku, sale_unit, base_price,
    starting_at, price_is_reference, stock_count, stock_status, prep_days,
    production_points, tags, attributes, cover_path, active, featured, sort_order
  ) values (
    v_family_slug,
    btrim(payload ->> 'name'),
    v_category_id,
    v_kind,
    coalesce(payload ->> 'description', ''),
    nullif(btrim(coalesce(payload ->> 'sku', '')), ''),
    coalesce(nullif(btrim(payload ->> 'unitLabel'), ''), 'unidad'),
    v_base_price,
    coalesce((payload ->> 'startingAt')::boolean, false),
    coalesce((payload ->> 'priceIsEstimate')::boolean, false),
    nullif(payload ->> 'stock', '')::integer,
    v_stock_status,
    coalesce(nullif(payload ->> 'leadDays', '')::integer, 0),
    coalesce(nullif(payload ->> 'productionPoints', '')::integer, 0),
    v_tags,
    v_attributes,
    nullif(btrim(coalesce(payload ->> 'imageUrl', '')), ''),
    coalesce((payload ->> 'isActive')::boolean, true),
    coalesce((payload ->> 'isFeatured')::boolean, false),
    coalesce(nullif(payload ->> 'sortOrder', '')::integer, 0)
  )
  on conflict on constraint families_slug_unique do update set
    name = excluded.name,
    category_id = excluded.category_id,
    kind = excluded.kind,
    description = excluded.description,
    sku = excluded.sku,
    sale_unit = excluded.sale_unit,
    base_price = excluded.base_price,
    starting_at = excluded.starting_at,
    price_is_reference = excluded.price_is_reference,
    stock_count = excluded.stock_count,
    stock_status = excluded.stock_status,
    prep_days = excluded.prep_days,
    production_points = excluded.production_points,
    tags = excluded.tags,
    attributes = excluded.attributes,
    cover_path = excluded.cover_path,
    active = excluded.active,
    featured = excluded.featured,
    sort_order = excluded.sort_order
  returning f.id into v_family_id;

  v_tiers := coalesce(payload -> 'priceTiers', '[]'::jsonb);
  if jsonb_typeof(v_tiers) <> 'array' then
    raise exception using errcode = '22023', message = 'priceTiers debe ser una lista.';
  end if;
  delete from public.family_price_tiers pt where pt.family_id = v_family_id;
  for v_tier in select value from jsonb_array_elements(v_tiers) as tier(value)
  loop
    v_min_qty := coalesce(nullif(v_tier ->> 'minQuantity', '')::integer, 0);
    v_unit_price := coalesce(nullif(v_tier ->> 'unitPrice', '')::numeric, -1);
    if v_min_qty < 1 or v_unit_price < 0 then
      raise exception using errcode = '22023', message = 'Existe un tramo de precio inválido.';
    end if;
    insert into public.family_price_tiers (family_id, min_qty, unit_price, label)
    values (v_family_id, v_min_qty, v_unit_price, nullif(btrim(coalesce(v_tier ->> 'label', '')), ''));
  end loop;

  v_variants := coalesce(payload -> 'variants', '[]'::jsonb);
  if jsonb_typeof(v_variants) <> 'array' then
    raise exception using errcode = '22023', message = 'variants debe ser una lista.';
  end if;
  for v_variant in select value from jsonb_array_elements(v_variants) as item(value)
  loop
    v_variant_slug := btrim(coalesce(v_variant ->> 'id', ''));
    if v_variant_slug !~ '^[a-z0-9]+(?:-[a-z0-9]+)*$' then
      raise exception using errcode = '22023', message = 'Una variante tiene id/slug inválido.';
    end if;
    if char_length(btrim(coalesce(v_variant ->> 'name', ''))) not between 1 and 160 then
      raise exception using errcode = '22023', message = 'Una variante no tiene nombre válido.';
    end if;
    v_variant_status := coalesce(nullif(v_variant ->> 'stockStatus', ''), 'check_availability')::public.catalog_stock_status;

    insert into public.variants as v (
      family_id, slug, name, sku, color_hex, attributes, base_price,
      price_is_reference, stock_count, stock_status, prep_days,
      production_points, image_path, active, sort_order
    ) values (
      v_family_id,
      v_variant_slug,
      btrim(v_variant ->> 'name'),
      nullif(btrim(coalesce(v_variant ->> 'sku', '')), ''),
      nullif(btrim(coalesce(v_variant ->> 'colorHex', '')), ''),
      coalesce(v_variant -> 'attributes', '{}'::jsonb),
      nullif(v_variant ->> 'priceOverride', '')::numeric,
      coalesce((v_variant ->> 'priceIsEstimate')::boolean, false),
      nullif(v_variant ->> 'stock', '')::integer,
      v_variant_status,
      nullif(v_variant ->> 'leadDays', '')::integer,
      nullif(v_variant ->> 'productionPoints', '')::integer,
      nullif(btrim(coalesce(v_variant ->> 'imageUrl', '')), ''),
      coalesce((v_variant ->> 'isActive')::boolean, true),
      v_index
    )
    on conflict on constraint variants_family_slug_unique do update set
      name = excluded.name,
      sku = excluded.sku,
      color_hex = excluded.color_hex,
      attributes = excluded.attributes,
      base_price = excluded.base_price,
      price_is_reference = excluded.price_is_reference,
      stock_count = excluded.stock_count,
      stock_status = excluded.stock_status,
      prep_days = excluded.prep_days,
      production_points = excluded.production_points,
      image_path = excluded.image_path,
      active = excluded.active,
      sort_order = excluded.sort_order
    returning v.id into v_variant_id;

    v_variant_ids := array_append(v_variant_ids, v_variant_id);
    delete from public.variant_price_tiers pt where pt.variant_id = v_variant_id;
    v_tiers := coalesce(v_variant -> 'priceTiers', '[]'::jsonb);
    if jsonb_typeof(v_tiers) <> 'array' then
      raise exception using errcode = '22023', message = 'priceTiers de variante debe ser una lista.';
    end if;
    for v_tier in select value from jsonb_array_elements(v_tiers) as tier(value)
    loop
      v_min_qty := coalesce(nullif(v_tier ->> 'minQuantity', '')::integer, 0);
      v_unit_price := coalesce(nullif(v_tier ->> 'unitPrice', '')::numeric, -1);
      if v_min_qty < 1 or v_unit_price < 0 then
        raise exception using errcode = '22023', message = 'Existe un tramo de variante inválido.';
      end if;
      insert into public.variant_price_tiers (variant_id, min_qty, unit_price, label)
      values (v_variant_id, v_min_qty, v_unit_price, nullif(btrim(coalesce(v_tier ->> 'label', '')), ''));
    end loop;
    v_index := v_index + 1;
  end loop;

  update public.variants v
  set active = false
  where v.family_id = v_family_id
    and not (v.id = any(v_variant_ids));

  return query select v_family_id, v_family_slug;
end;
$$;

create or replace function public.admin_delete_catalog_family(family_slug text)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_deleted uuid;
begin
  if not public.can_admin_write() then
    raise exception using
      errcode = '42501',
      message = 'Se requiere una cuenta administradora con MFA AAL2.';
  end if;
  delete from public.families f
  where f.slug = btrim(family_slug)
  returning f.id into v_deleted;
  return v_deleted is not null;
end;
$$;

revoke all on function public.admin_save_catalog_family(jsonb) from public;
revoke all on function public.admin_delete_catalog_family(text) from public;
grant execute on function public.admin_save_catalog_family(jsonb) to authenticated;
grant execute on function public.admin_delete_catalog_family(text) to authenticated;

-- Public bucket: object downloads are public; object listing and every mutation
-- remain protected by Storage RLS. Admin upserts need SELECT plus INSERT/UPDATE.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'catalog',
  'catalog',
  true,
  5242880,
  array['image/webp', 'image/jpeg', 'image/png']
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists catalog_admin_list on storage.objects;
create policy catalog_admin_list on storage.objects
for select to authenticated
using (bucket_id = 'catalog' and public.is_current_admin());
drop policy if exists catalog_admin_insert on storage.objects;
create policy catalog_admin_insert on storage.objects
for insert to authenticated
with check (bucket_id = 'catalog' and public.can_admin_write());
drop policy if exists catalog_admin_update on storage.objects;
create policy catalog_admin_update on storage.objects
for update to authenticated
using (bucket_id = 'catalog' and public.can_admin_write())
with check (bucket_id = 'catalog' and public.can_admin_write());
drop policy if exists catalog_admin_delete on storage.objects;
create policy catalog_admin_delete on storage.objects
for delete to authenticated
using (bucket_id = 'catalog' and public.can_admin_write());

comment on table public.families is
  'Catalog family. slug is the stable public ID used by Flutter carts and links.';
comment on table public.variants is
  'Catalog variant. (family_id, slug) is the stable Flutter variant ID.';
comment on table public.availability is
  'Single public row whose data matches ProductionCapacitySnapshot.toMap().';
comment on function public.admin_save_catalog_family(jsonb) is
  'Atomic upsert adapter for the current camelCase CatalogProduct payload; requires admin+AAL2.';
