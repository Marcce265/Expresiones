-- Keep the catalog image columns coherent across every write path.
--
-- The admin uploads the original first and then saves the complete product
-- through admin_save_catalog_family().  The upload and the RPC are separate
-- HTTP requests, but every relational change made by the RPC remains atomic.

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
    cover_path = case
      when payload ? 'imageUrl' then excluded.cover_path
      else f.cover_path
    end,
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
      image_path = case
        when v_variant ? 'imageUrl' then excluded.image_path
        else v.image_path
      end,
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

revoke all on function public.admin_save_catalog_family(jsonb)
  from public, anon, authenticated;
grant execute on function public.admin_save_catalog_family(jsonb) to authenticated;

create or replace function public.keep_family_image_paths_consistent()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_old_cover_path text;
  v_old_thumb_path text;
  v_old_detail_path text;
begin
  if tg_op = 'UPDATE' then
    v_old_cover_path := case
      when old.cover_path ~* '^https?://[^/]+/storage/v1/object/public/catalog/'
        then regexp_replace(
          btrim(old.cover_path),
          '^https?://[^/]+/storage/v1/object/public/catalog/',
          '',
          'i'
        )
      else nullif(btrim(old.cover_path), '')
    end;
    v_old_thumb_path := case
      when old.cover_thumb_path ~* '^https?://[^/]+/storage/v1/object/public/catalog/'
        then regexp_replace(
          btrim(old.cover_thumb_path),
          '^https?://[^/]+/storage/v1/object/public/catalog/',
          '',
          'i'
        )
      else nullif(btrim(old.cover_thumb_path), '')
    end;
    v_old_detail_path := case
      when old.cover_detail_path ~* '^https?://[^/]+/storage/v1/object/public/catalog/'
        then regexp_replace(
          btrim(old.cover_detail_path),
          '^https?://[^/]+/storage/v1/object/public/catalog/',
          '',
          'i'
        )
      else nullif(btrim(old.cover_detail_path), '')
    end;
  end if;

  new.cover_path := case
    when new.cover_path ~* '^https?://[^/]+/storage/v1/object/public/catalog/'
      then regexp_replace(
        btrim(new.cover_path),
        '^https?://[^/]+/storage/v1/object/public/catalog/',
        '',
        'i'
      )
    else nullif(btrim(new.cover_path), '')
  end;
  new.cover_thumb_path := case
    when new.cover_thumb_path ~* '^https?://[^/]+/storage/v1/object/public/catalog/'
      then regexp_replace(
        btrim(new.cover_thumb_path),
        '^https?://[^/]+/storage/v1/object/public/catalog/',
        '',
        'i'
      )
    else nullif(btrim(new.cover_thumb_path), '')
  end;
  new.cover_detail_path := case
    when new.cover_detail_path ~* '^https?://[^/]+/storage/v1/object/public/catalog/'
      then regexp_replace(
        btrim(new.cover_detail_path),
        '^https?://[^/]+/storage/v1/object/public/catalog/',
        '',
        'i'
      )
    else nullif(btrim(new.cover_detail_path), '')
  end;

  if tg_op = 'UPDATE' and new.cover_path is distinct from v_old_cover_path then
    if new.cover_thumb_path is not distinct from v_old_thumb_path then
      new.cover_thumb_path := null;
    end if;
    if new.cover_detail_path is not distinct from v_old_detail_path then
      new.cover_detail_path := null;
    end if;
  end if;
  return new;
end;
$$;

create or replace function public.keep_variant_image_paths_consistent()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_old_image_path text;
  v_old_thumb_path text;
  v_old_detail_path text;
begin
  if tg_op = 'UPDATE' then
    v_old_image_path := case
      when old.image_path ~* '^https?://[^/]+/storage/v1/object/public/catalog/'
        then regexp_replace(
          btrim(old.image_path),
          '^https?://[^/]+/storage/v1/object/public/catalog/',
          '',
          'i'
        )
      else nullif(btrim(old.image_path), '')
    end;
    v_old_thumb_path := case
      when old.thumb_path ~* '^https?://[^/]+/storage/v1/object/public/catalog/'
        then regexp_replace(
          btrim(old.thumb_path),
          '^https?://[^/]+/storage/v1/object/public/catalog/',
          '',
          'i'
        )
      else nullif(btrim(old.thumb_path), '')
    end;
    v_old_detail_path := case
      when old.detail_path ~* '^https?://[^/]+/storage/v1/object/public/catalog/'
        then regexp_replace(
          btrim(old.detail_path),
          '^https?://[^/]+/storage/v1/object/public/catalog/',
          '',
          'i'
        )
      else nullif(btrim(old.detail_path), '')
    end;
  end if;

  new.image_path := case
    when new.image_path ~* '^https?://[^/]+/storage/v1/object/public/catalog/'
      then regexp_replace(
        btrim(new.image_path),
        '^https?://[^/]+/storage/v1/object/public/catalog/',
        '',
        'i'
      )
    else nullif(btrim(new.image_path), '')
  end;
  new.thumb_path := case
    when new.thumb_path ~* '^https?://[^/]+/storage/v1/object/public/catalog/'
      then regexp_replace(
        btrim(new.thumb_path),
        '^https?://[^/]+/storage/v1/object/public/catalog/',
        '',
        'i'
      )
    else nullif(btrim(new.thumb_path), '')
  end;
  new.detail_path := case
    when new.detail_path ~* '^https?://[^/]+/storage/v1/object/public/catalog/'
      then regexp_replace(
        btrim(new.detail_path),
        '^https?://[^/]+/storage/v1/object/public/catalog/',
        '',
        'i'
      )
    else nullif(btrim(new.detail_path), '')
  end;

  if tg_op = 'UPDATE' and new.image_path is distinct from v_old_image_path then
    if new.thumb_path is not distinct from v_old_thumb_path then
      new.thumb_path := null;
    end if;
    if new.detail_path is not distinct from v_old_detail_path then
      new.detail_path := null;
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists families_image_paths_consistent on public.families;
create trigger families_image_paths_consistent
before insert or update on public.families
for each row execute function public.keep_family_image_paths_consistent();

drop trigger if exists variants_image_paths_consistent on public.variants;
create trigger variants_image_paths_consistent
before insert or update on public.variants
for each row execute function public.keep_variant_image_paths_consistent();

revoke all on function public.keep_family_image_paths_consistent()
  from public, anon, authenticated;
revoke all on function public.keep_variant_image_paths_consistent()
  from public, anon, authenticated;

-- Separate write policies avoid evaluating a second permissive policy for
-- authenticated SELECTs while preserving the same admin+AAL2 write access.
drop policy if exists categories_admin_write on public.categories;
drop policy if exists categories_admin_insert on public.categories;
drop policy if exists categories_admin_update on public.categories;
drop policy if exists categories_admin_delete on public.categories;
create policy categories_admin_insert on public.categories
for insert to authenticated
with check (public.can_admin_write());
create policy categories_admin_update on public.categories
for update to authenticated
using (public.can_admin_write())
with check (public.can_admin_write());
create policy categories_admin_delete on public.categories
for delete to authenticated
using (public.can_admin_write());

drop policy if exists families_admin_write on public.families;
drop policy if exists families_admin_insert on public.families;
drop policy if exists families_admin_update on public.families;
drop policy if exists families_admin_delete on public.families;
create policy families_admin_insert on public.families
for insert to authenticated
with check (public.can_admin_write());
create policy families_admin_update on public.families
for update to authenticated
using (public.can_admin_write())
with check (public.can_admin_write());
create policy families_admin_delete on public.families
for delete to authenticated
using (public.can_admin_write());

drop policy if exists variants_admin_write on public.variants;
drop policy if exists variants_admin_insert on public.variants;
drop policy if exists variants_admin_update on public.variants;
drop policy if exists variants_admin_delete on public.variants;
create policy variants_admin_insert on public.variants
for insert to authenticated
with check (public.can_admin_write());
create policy variants_admin_update on public.variants
for update to authenticated
using (public.can_admin_write())
with check (public.can_admin_write());
create policy variants_admin_delete on public.variants
for delete to authenticated
using (public.can_admin_write());

drop policy if exists family_price_tiers_admin_write
  on public.family_price_tiers;
drop policy if exists family_price_tiers_admin_insert
  on public.family_price_tiers;
drop policy if exists family_price_tiers_admin_update
  on public.family_price_tiers;
drop policy if exists family_price_tiers_admin_delete
  on public.family_price_tiers;
create policy family_price_tiers_admin_insert on public.family_price_tiers
for insert to authenticated
with check (public.can_admin_write());
create policy family_price_tiers_admin_update on public.family_price_tiers
for update to authenticated
using (public.can_admin_write())
with check (public.can_admin_write());
create policy family_price_tiers_admin_delete on public.family_price_tiers
for delete to authenticated
using (public.can_admin_write());

drop policy if exists variant_price_tiers_admin_write
  on public.variant_price_tiers;
drop policy if exists variant_price_tiers_admin_insert
  on public.variant_price_tiers;
drop policy if exists variant_price_tiers_admin_update
  on public.variant_price_tiers;
drop policy if exists variant_price_tiers_admin_delete
  on public.variant_price_tiers;
create policy variant_price_tiers_admin_insert on public.variant_price_tiers
for insert to authenticated
with check (public.can_admin_write());
create policy variant_price_tiers_admin_update on public.variant_price_tiers
for update to authenticated
using (public.can_admin_write())
with check (public.can_admin_write());
create policy variant_price_tiers_admin_delete on public.variant_price_tiers
for delete to authenticated
using (public.can_admin_write());

drop policy if exists availability_admin_write on public.availability;
drop policy if exists availability_admin_insert on public.availability;
drop policy if exists availability_admin_update on public.availability;
drop policy if exists availability_admin_delete on public.availability;
create policy availability_admin_insert on public.availability
for insert to authenticated
with check (id = 'public' and public.can_admin_write());
create policy availability_admin_update on public.availability
for update to authenticated
using (id = 'public' and public.can_admin_write())
with check (id = 'public' and public.can_admin_write());
create policy availability_admin_delete on public.availability
for delete to authenticated
using (id = 'public' and public.can_admin_write());

-- Every audit foreign key gets an index so user deletion and FK validation do
-- not scan the complete catalog tables.
create index if not exists categories_created_by_idx
  on public.categories (created_by);
create index if not exists categories_updated_by_idx
  on public.categories (updated_by);
create index if not exists families_created_by_idx
  on public.families (created_by);
create index if not exists families_updated_by_idx
  on public.families (updated_by);
create index if not exists variants_created_by_idx
  on public.variants (created_by);
create index if not exists variants_updated_by_idx
  on public.variants (updated_by);
create index if not exists family_price_tiers_created_by_idx
  on public.family_price_tiers (created_by);
create index if not exists family_price_tiers_updated_by_idx
  on public.family_price_tiers (updated_by);
create index if not exists variant_price_tiers_created_by_idx
  on public.variant_price_tiers (created_by);
create index if not exists variant_price_tiers_updated_by_idx
  on public.variant_price_tiers (updated_by);
create index if not exists admins_created_by_idx
  on public.admins (created_by);
create index if not exists availability_updated_by_idx
  on public.availability (updated_by);

-- Existing optimized derivatives are intentionally left untouched. The
-- triggers only invalidate a derivative when its principal image changes.

-- The UI accepts files up to 8 MB; Storage must enforce the same contract.
update storage.buckets
set file_size_limit = 8388608
where id = 'catalog';

-- The Flutter repository subscribes to these four normalized tables. Without
-- publication membership it receives the initial snapshot but never refreshes
-- after an update or delete.
do $$
declare
  v_table text;
begin
  if not exists (
    select 1 from pg_publication where pubname = 'supabase_realtime'
  ) then
    execute 'create publication supabase_realtime';
  end if;

  foreach v_table in array array[
    'families',
    'variants',
    'family_price_tiers',
    'variant_price_tiers'
  ]
  loop
    if not exists (
      select 1
      from pg_publication_tables
      where pubname = 'supabase_realtime'
        and schemaname = 'public'
        and tablename = v_table
    ) then
      execute format(
        'alter publication supabase_realtime add table %I.%I',
        'public',
        v_table
      );
    end if;
  end loop;
end;
$$;

-- This event-trigger helper is internal infrastructure and must not be an RPC.
do $$
begin
  if to_regprocedure('public.rls_auto_enable()') is not null then
    execute
      'revoke all on function public.rls_auto_enable() from public, anon, authenticated';
  end if;
end;
$$;
