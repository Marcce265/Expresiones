-- Run with `supabase test db` after applying the project migrations.

begin;

do $contract$
begin
  if to_regclass('public.product_popularity') is null then
    raise exception 'public.product_popularity is missing';
  end if;

  if not exists (
    select 1
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public'
      and c.relname = 'product_popularity'
      and c.relrowsecurity
  ) then
    raise exception 'product_popularity must have RLS enabled';
  end if;

  if not has_table_privilege('anon', 'public.product_popularity', 'SELECT')
      or has_table_privilege('anon', 'public.product_popularity', 'INSERT')
      or has_table_privilege('anon', 'public.product_popularity', 'UPDATE')
      or has_table_privilege('anon', 'public.product_popularity', 'DELETE') then
    raise exception 'anon product_popularity grants must be read-only';
  end if;

  if not has_table_privilege(
    'authenticated',
    'public.product_popularity',
    'SELECT'
  ) or has_table_privilege(
    'authenticated',
    'public.product_popularity',
    'INSERT'
  ) or has_table_privilege(
    'authenticated',
    'public.product_popularity',
    'UPDATE'
  ) or has_table_privilege(
    'authenticated',
    'public.product_popularity',
    'DELETE'
  ) then
    raise exception 'authenticated product_popularity grants must be read-only';
  end if;

  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'product_popularity'
      and policyname = 'product_popularity_public_read'
      and cmd = 'SELECT'
      and 'anon' = any(roles)
      and 'authenticated' = any(roles)
  ) then
    raise exception 'product popularity public read policy is missing';
  end if;

  if exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    cross join lateral aclexplode(
      coalesce(p.proacl, acldefault('f', p.proowner))
    ) privilege
    where n.nspname = 'public'
      and p.proname = 'record_product_popularity'
      and privilege.grantee = 0
      and privilege.privilege_type = 'EXECUTE'
  ) or not has_function_privilege(
    'anon',
    'public.record_product_popularity(text,text,integer)',
    'EXECUTE'
  ) or not has_function_privilege(
    'authenticated',
    'public.record_product_popularity(text,text,integer)',
    'EXECUTE'
  ) then
    raise exception 'record_product_popularity execute grants are invalid';
  end if;

  if not exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'metrics_private'
      and p.proname = 'record_product_popularity_internal'
      and p.prosecdef
      and p.proconfig @> array['search_path=']
  ) then
    raise exception 'private popularity writer must pin an empty search_path';
  end if;

  if exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname = 'record_product_popularity'
      and p.prosecdef
  ) then
    raise exception 'public popularity RPC must be SECURITY INVOKER';
  end if;

  if exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    cross join lateral aclexplode(
      coalesce(p.proacl, acldefault('f', p.proowner))
    ) privilege
    where n.nspname = 'metrics_private'
      and p.proname = 'record_product_popularity_internal'
      and privilege.grantee = 0
      and privilege.privilege_type = 'EXECUTE'
  ) or not has_function_privilege(
    'anon',
    'metrics_private.record_product_popularity_internal(text,text,integer)',
    'EXECUTE'
  ) or not has_function_privilege(
    'authenticated',
    'metrics_private.record_product_popularity_internal(text,text,integer)',
    'EXECUTE'
  ) then
    raise exception 'private popularity writer execute grants are invalid';
  end if;
end;
$contract$;

rollback;
