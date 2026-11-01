-- Run with `supabase test db` after applying the project migrations.

begin;

do $contract$
declare
  v_trigger_count integer;
begin
  if to_regclass('public.admin_audit_logs') is null then
    raise exception 'admin_audit_logs table is missing';
  end if;

  if not (
    select c.relrowsecurity
    from pg_class c
    where c.oid = 'public.admin_audit_logs'::regclass
  ) then
    raise exception 'admin_audit_logs must have RLS enabled';
  end if;

  if has_table_privilege('anon', 'public.admin_audit_logs', 'SELECT')
      or not has_table_privilege(
        'authenticated', 'public.admin_audit_logs', 'SELECT'
      )
      or has_table_privilege(
        'authenticated', 'public.admin_audit_logs', 'INSERT,UPDATE,DELETE'
      ) then
    raise exception 'admin_audit_logs grants are not read-only admin compatible';
  end if;

  if (
    select count(*)
    from pg_policies
    where schemaname = 'public'
      and tablename = 'admin_audit_logs'
      and policyname = 'admin_audit_logs_admin_read'
      and cmd = 'SELECT'
      and 'authenticated' = any(roles)
  ) <> 1 then
    raise exception 'admin audit read policy is missing';
  end if;

  if exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'admin_audit_logs'
  ) then
    raise exception 'admin audit history must not use Realtime';
  end if;

  select count(distinct trigger_name) into v_trigger_count
  from information_schema.triggers
  where trigger_schema = 'public'
    and trigger_name in (
      'families_admin_activity',
      'site_settings_admin_activity',
      'availability_admin_activity'
    );
  if v_trigger_count <> 3 then
    raise exception 'exactly three logical audit triggers are required';
  end if;

  if exists (
    select 1
    from information_schema.triggers
    where trigger_schema = 'public'
      and event_object_table in (
        'variants', 'family_price_tiers', 'variant_price_tiers'
      )
      and trigger_name like '%admin%activity%'
  ) then
    raise exception 'variant and tier rows must not create noisy audit events';
  end if;

  if has_function_privilege(
    'authenticated',
    'audit_private.capture_family_admin_action()',
    'EXECUTE'
  ) or has_function_privilege(
    'anon',
    'audit_private.capture_settings_admin_action()',
    'EXECUTE'
  ) then
    raise exception 'audit trigger functions must not be directly executable';
  end if;
end;
$contract$;

rollback;

