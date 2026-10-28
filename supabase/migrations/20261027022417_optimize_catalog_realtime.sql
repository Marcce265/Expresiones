-- The storefront only needs a tiny version signal in Realtime. It fetches the
-- normalized catalog once when that version changes, instead of subscribing to
-- four full catalog tables and receiving their initial snapshots separately.
do $$
declare
  v_table text;
begin
  if not exists (
    select 1
    from pg_publication
    where pubname = 'supabase_realtime'
  ) then
    execute 'create publication supabase_realtime';
  end if;

  foreach v_table in array array[
    'catalog_metadata',
    'availability',
    'site_settings'
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

  foreach v_table in array array[
    'families',
    'variants',
    'family_price_tiers',
    'variant_price_tiers'
  ]
  loop
    if exists (
      select 1
      from pg_publication_tables
      where pubname = 'supabase_realtime'
        and schemaname = 'public'
        and tablename = v_table
    ) then
      execute format(
        'alter publication supabase_realtime drop table %I.%I',
        'public',
        v_table
      );
    end if;
  end loop;
end;
$$;
