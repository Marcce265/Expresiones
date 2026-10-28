-- Run with `supabase test db` after applying the project migrations.

begin;

do $contract$
declare
  v_data jsonb;
begin
  if to_regclass('public.site_settings') is null then
    raise exception 'public.site_settings is missing';
  end if;

  if not exists (
    select 1
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public'
      and c.relname = 'site_settings'
      and c.relrowsecurity
  ) then
    raise exception 'site_settings must have RLS enabled';
  end if;

  if (
    select count(*)
    from public.site_settings
    where id = 'public'
  ) <> 1 then
    raise exception 'site_settings must contain the public singleton row';
  end if;

  select data into v_data
  from public.site_settings
  where id = 'public';
  if jsonb_typeof(v_data) <> 'object' then
    raise exception 'site_settings.data must be a JSON object';
  end if;

  if not has_table_privilege('anon', 'public.site_settings', 'SELECT')
      or has_table_privilege('anon', 'public.site_settings', 'INSERT')
      or has_table_privilege('anon', 'public.site_settings', 'UPDATE')
      or has_table_privilege('anon', 'public.site_settings', 'DELETE') then
    raise exception 'anon site_settings grants must be read-only';
  end if;
  if not has_table_privilege('authenticated', 'public.site_settings', 'SELECT')
      or not has_table_privilege('authenticated', 'public.site_settings', 'INSERT')
      or not has_table_privilege('authenticated', 'public.site_settings', 'UPDATE')
      or has_table_privilege('authenticated', 'public.site_settings', 'DELETE') then
    raise exception 'authenticated site_settings grants are invalid';
  end if;

  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'site_settings'
      and policyname = 'site_settings_public_read'
      and cmd = 'SELECT'
      and 'anon' = any(roles)
      and 'authenticated' = any(roles)
  ) then
    raise exception 'site_settings public read policy is missing';
  end if;

  if (
    select count(*)
    from pg_policies
    where schemaname = 'public'
      and tablename = 'site_settings'
      and policyname in (
        'site_settings_admin_insert',
        'site_settings_admin_update'
      )
      and 'authenticated' = any(roles)
      and position(
        'can_admin_write'
        in coalesce(qual, '') || coalesce(with_check, '')
      ) > 0
  ) <> 2 or exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'site_settings'
      and cmd = 'DELETE'
  ) then
    raise exception 'site_settings must allow admin insert/update without delete';
  end if;

  if not exists (
    select 1
    from pg_trigger
    where tgrelid = 'public.site_settings'::regclass
      and tgname = 'site_settings_audit'
      and not tgisinternal
  ) then
    raise exception 'site_settings audit trigger is missing';
  end if;

  if to_regclass('public.site_settings_updated_by_idx') is null then
    raise exception 'site_settings updated_by index is missing';
  end if;

  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'site_settings'
  ) then
    raise exception 'site_settings is missing from supabase_realtime';
  end if;
end;
$contract$;

rollback;
