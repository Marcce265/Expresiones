-- Run with `supabase test db` after applying the project migrations.
-- This transaction always rolls back its temporary valid update.

begin;

do $contract$
declare
  v_data jsonb;
  v_invalid jsonb;
  v_method text;
begin
  select data into v_data
  from public.availability
  where id = 'public';

  if v_data #> '{deliveryWeekdays,pickup}'
      is distinct from '[1,2,3,4,5,6]'::jsonb then
    raise exception 'pickup weekdays must default to Monday through Saturday';
  end if;
  if v_data #> '{deliveryWeekdays,shalom}'
      is distinct from '[1,6]'::jsonb then
    raise exception 'Shalom weekdays must default to Monday and Saturday';
  end if;

  if not has_table_privilege('anon', 'public.availability', 'SELECT')
      or has_table_privilege('anon', 'public.availability', 'INSERT')
      or has_table_privilege('anon', 'public.availability', 'UPDATE')
      or has_table_privilege('anon', 'public.availability', 'DELETE') then
    raise exception 'anon availability grants must be read-only';
  end if;
  if not has_table_privilege('authenticated', 'public.availability', 'SELECT')
      or not has_table_privilege('authenticated', 'public.availability', 'INSERT')
      or not has_table_privilege('authenticated', 'public.availability', 'UPDATE')
      or has_table_privilege('authenticated', 'public.availability', 'DELETE') then
    raise exception 'authenticated availability grants are invalid';
  end if;

  if (
    select count(*)
    from pg_policies
    where schemaname = 'public'
      and tablename = 'availability'
      and policyname in (
        'availability_admin_insert',
        'availability_admin_update'
      )
      and position(
        'can_admin_write'
        in coalesce(qual, '') || coalesce(with_check, '')
      ) > 0
  ) <> 2 or exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'availability'
      and cmd = 'DELETE'
  ) then
    raise exception 'availability must allow admin insert/update without delete';
  end if;

  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'availability'
      and policyname = 'availability_public_read'
      and cmd = 'SELECT'
      and 'anon' = any(roles)
      and 'authenticated' = any(roles)
  ) then
    raise exception 'availability public read policy is missing';
  end if;

  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'availability'
  ) then
    raise exception 'availability is missing from supabase_realtime';
  end if;

  foreach v_method in array array['pickup', 'shalom']
  loop
    foreach v_invalid in array array[
      '[]'::jsonb,
      '[0]'::jsonb,
      '[8]'::jsonb,
      '[1.5]'::jsonb,
      '["1"]'::jsonb
    ]
    loop
      begin
        update public.availability
        set data = jsonb_set(
          data,
          array['deliveryWeekdays', v_method],
          v_invalid,
          false
        )
        where id = 'public';
        raise exception 'invalid % weekdays accepted: %', v_method, v_invalid;
      exception
        when check_violation then null;
      end;
    end loop;
  end loop;

  update public.availability
  set data = jsonb_set(
    data,
    '{deliveryWeekdays,shalom}',
    '[2,5]'::jsonb,
    false
  )
  where id = 'public';

  if (
    select data #> '{deliveryWeekdays,shalom}'
    from public.availability
    where id = 'public'
  ) is distinct from '[2,5]'::jsonb then
    raise exception 'valid editable Shalom weekdays were not persisted';
  end if;
end;
$contract$;

rollback;
