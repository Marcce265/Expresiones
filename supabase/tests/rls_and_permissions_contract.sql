-- Contrato de auditoría de RLS y permisos por rol en todas las tablas de public.
-- Verifica que ninguna tabla quede sin RLS y que anon/authenticated tengan
-- únicamente los privilegios estrictamente necesarios.

begin;

do $rls_contract$
declare
  v_table text;
  v_all_tables text[] := array[
    'categories',
    'families',
    'variants',
    'family_price_tiers',
    'variant_price_tiers',
    'admins',
    'catalog_metadata',
    'availability',
    'site_settings',
    'product_popularity',
    'admin_audit_logs',
    'customer_profiles',
    'customer_orders'
  ];
  v_private_tables_for_anon text[] := array[
    'admins',
    'admin_audit_logs',
    'customer_profiles',
    'customer_orders'
  ];
begin
  -- 1. Verificar que absolutamente todas las tablas de public tengan RLS habilitado
  foreach v_table in array v_all_tables loop
    if not exists (
      select 1
      from pg_class c
      join pg_namespace n on n.oid = c.relnamespace
      where n.nspname = 'public'
        and c.relname = v_table
        and c.relrowsecurity = true
    ) then
      raise exception 'RLS is NOT enabled on public.%', v_table;
    end if;

    -- 2. Verificar que anon NUNCA tenga permisos de escritura directa en ninguna tabla
    if has_table_privilege('anon', format('public.%I', v_table), 'INSERT')
       or has_table_privilege('anon', format('public.%I', v_table), 'UPDATE')
       or has_table_privilege('anon', format('public.%I', v_table), 'DELETE')
       or has_table_privilege('anon', format('public.%I', v_table), 'TRUNCATE') then
      raise exception 'anon must not have write privileges on public.%', v_table;
    end if;
  end loop;

  -- 3. Verificar que anon NO tenga permiso SELECT en tablas sensibles/privadas
  foreach v_table in array v_private_tables_for_anon loop
    if has_table_privilege('anon', format('public.%I', v_table), 'SELECT') then
      raise exception 'anon must not have SELECT privilege on public.%', v_table;
    end if;
  end loop;

  -- 4. Verificar que nadie pueda borrar pedidos ni logs de auditoría
  if has_table_privilege('authenticated', 'public.customer_orders', 'DELETE')
     or has_table_privilege('authenticated', 'public.customer_orders', 'UPDATE') then
    raise exception 'authenticated must not be able to UPDATE or DELETE customer_orders';
  end if;

  if has_table_privilege('authenticated', 'public.admin_audit_logs', 'INSERT')
     or has_table_privilege('authenticated', 'public.admin_audit_logs', 'UPDATE')
     or has_table_privilege('authenticated', 'public.admin_audit_logs', 'DELETE') then
    raise exception 'authenticated must not be able to mutate admin_audit_logs';
  end if;

  -- 5. Verificar que los triggers de rate-limiting y sanitización estén activos
  if not exists (
    select 1
    from pg_trigger
    where tgrelid = 'public.customer_orders'::regclass
      and tgname = 'trg_enforce_customer_order_security'
      and not tgisinternal
  ) then
    raise exception 'trg_enforce_customer_order_security is missing on public.customer_orders';
  end if;

  if not exists (
    select 1
    from pg_trigger
    where tgrelid = 'public.customer_profiles'::regclass
      and tgname = 'trg_enforce_customer_profile_security'
      and not tgisinternal
  ) then
    raise exception 'trg_enforce_customer_profile_security is missing on public.customer_profiles';
  end if;
end;
$rls_contract$;

rollback;
