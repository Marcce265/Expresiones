-- Run with `supabase test db` after applying the project migrations.
-- The transaction always rolls back its fixtures and catalog version bumps.

begin;

do $contract$
declare
  v_table text;
  v_index text;
  v_function_definition text;
begin
  if (select file_size_limit from storage.buckets where id = 'catalog')
      is distinct from 8388608::bigint then
    raise exception 'catalog bucket must accept exactly 8 MiB';
  end if;

  if has_function_privilege(
    'anon',
    'public.rls_auto_enable()',
    'EXECUTE'
  ) or has_function_privilege(
    'authenticated',
    'public.rls_auto_enable()',
    'EXECUTE'
  ) then
    raise exception 'rls_auto_enable must not be exposed through the Data API';
  end if;

  if has_function_privilege(
    'anon',
    'public.admin_save_catalog_family(jsonb)',
    'EXECUTE'
  ) or not has_function_privilege(
    'authenticated',
    'public.admin_save_catalog_family(jsonb)',
    'EXECUTE'
  ) then
    raise exception 'admin_save_catalog_family has an invalid execute grant';
  end if;

  select pg_get_functiondef(
    'public.admin_save_catalog_family(jsonb)'::regprocedure
  ) into v_function_definition;
  if position(
    'when payload ? ''imageUrl'' then excluded.cover_path'
    in v_function_definition
  ) = 0 or position(
    'when v_variant ? ''imageUrl'' then excluded.image_path'
    in v_function_definition
  ) = 0 then
    raise exception 'admin_save_catalog_family must preserve omitted imageUrl values';
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
      raise exception '% is missing from supabase_realtime', v_table;
    end if;
  end loop;

  if (
    select count(*)
    from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and policyname in (
        'catalog_admin_list',
        'catalog_admin_insert',
        'catalog_admin_update',
        'catalog_admin_delete'
      )
      and 'authenticated' = any(roles)
  ) <> 4 then
    raise exception 'catalog Storage CRUD policies are incomplete';
  end if;

  foreach v_table in array array[
    'categories',
    'families',
    'variants',
    'family_price_tiers',
    'variant_price_tiers',
    'availability'
  ]
  loop
    if exists (
      select 1
      from pg_policies
      where schemaname = 'public'
        and tablename = v_table
        and policyname = v_table || '_admin_write'
    ) then
      raise exception '% still has a FOR ALL admin policy', v_table;
    end if;

    if (
      select count(*)
      from pg_policies
      where schemaname = 'public'
        and tablename = v_table
        and policyname in (
          v_table || '_admin_insert',
          v_table || '_admin_update',
          v_table || '_admin_delete'
        )
    ) <> 3 then
      raise exception '% must have separate admin write policies', v_table;
    end if;
  end loop;

  foreach v_index in array array[
    'public.categories_created_by_idx',
    'public.categories_updated_by_idx',
    'public.families_created_by_idx',
    'public.families_updated_by_idx',
    'public.variants_created_by_idx',
    'public.variants_updated_by_idx',
    'public.family_price_tiers_created_by_idx',
    'public.family_price_tiers_updated_by_idx',
    'public.variant_price_tiers_created_by_idx',
    'public.variant_price_tiers_updated_by_idx',
    'public.admins_created_by_idx',
    'public.availability_updated_by_idx'
  ]
  loop
    if to_regclass(v_index) is null then
      raise exception 'missing foreign-key index %', v_index;
    end if;
  end loop;
end;
$contract$;

do $images$
declare
  v_category_id uuid;
  v_family_id uuid;
  v_variant_id uuid;
  v_path text;
  v_thumb text;
  v_detail text;
begin
  insert into public.categories (slug, name, kind)
  values ('contract-image-paths-20261022', 'Contract image paths', 'material')
  returning id into v_category_id;

  insert into public.families (
    slug,
    name,
    category_id,
    cover_path,
    cover_thumb_path,
    cover_detail_path
  ) values (
    'contract-image-family-20261022',
    'Contract image family',
    v_category_id,
    'images/original/source.webp',
    'images/original/thumb.webp',
    'images/original/detail.webp'
  ) returning id into v_family_id;

  update public.families
  set cover_path = 'products-contract/new.png'
  where id = v_family_id;

  select cover_path, cover_thumb_path, cover_detail_path
  into v_path, v_thumb, v_detail
  from public.families
  where id = v_family_id;
  if v_path <> 'products-contract/new.png'
      or v_thumb is not null
      or v_detail is not null then
    raise exception 'family image change did not invalidate stale derivatives';
  end if;

  update public.families
  set
    cover_path = 'https://example.supabase.co/storage/v1/object/public/catalog/products-contract/fresh.png',
    cover_thumb_path = 'products-contract/fresh-thumb.webp',
    cover_detail_path = 'products-contract/fresh-detail.webp'
  where id = v_family_id;

  select cover_path, cover_thumb_path, cover_detail_path
  into v_path, v_thumb, v_detail
  from public.families
  where id = v_family_id;
  if v_path <> 'products-contract/fresh.png'
      or v_thumb <> 'products-contract/fresh-thumb.webp'
      or v_detail <> 'products-contract/fresh-detail.webp' then
    raise exception 'family image paths were not normalized/preserved';
  end if;

  insert into public.variants (
    family_id,
    slug,
    name,
    image_path,
    thumb_path,
    detail_path
  ) values (
    v_family_id,
    'contract-variant',
    'Contract variant',
    'images/variant/source.webp',
    'images/variant/thumb.webp',
    'images/variant/detail.webp'
  ) returning id into v_variant_id;

  update public.variants
  set image_path = 'products-contract/variant-new.png'
  where id = v_variant_id;

  select image_path, thumb_path, detail_path
  into v_path, v_thumb, v_detail
  from public.variants
  where id = v_variant_id;
  if v_path <> 'products-contract/variant-new.png'
      or v_thumb is not null
      or v_detail is not null then
    raise exception 'variant image change did not invalidate stale derivatives';
  end if;
end;
$images$;

rollback;
