-- Editable delivery calendar used by the public quote flow.
-- Weekdays follow Dart's DateTime.weekday: 1 = Monday, 7 = Sunday.

update public.availability
set data = jsonb_set(
  data,
  '{deliveryWeekdays}',
  coalesce(data -> 'deliveryWeekdays', '{}'::jsonb) || jsonb_build_object(
    'pickup', coalesce(
      data #> '{deliveryWeekdays,pickup}',
      '[1,2,3,4,5,6]'::jsonb
    ),
    'shalom', coalesce(
      data #> '{deliveryWeekdays,shalom}',
      '[1,6]'::jsonb
    )
  ),
  true
)
where id = 'public';

alter table public.availability
  drop constraint if exists availability_delivery_weekdays_valid;
alter table public.availability
  add constraint availability_delivery_weekdays_valid
  check (
    case
      when jsonb_typeof(data #> '{deliveryWeekdays,pickup}') = 'array'
        and jsonb_typeof(data #> '{deliveryWeekdays,shalom}') = 'array'
      then
        jsonb_array_length(data #> '{deliveryWeekdays,pickup}') between 1 and 7
        and jsonb_array_length(data #> '{deliveryWeekdays,shalom}') between 1 and 7
        and (data #> '{deliveryWeekdays,pickup}')
          <@ '[1,2,3,4,5,6,7]'::jsonb
        and (data #> '{deliveryWeekdays,shalom}')
          <@ '[1,2,3,4,5,6,7]'::jsonb
      else false
    end
  );

-- Keep the public row readable without exposing mutation privileges.
revoke all on table public.availability from anon, authenticated;
grant select on table public.availability to anon, authenticated;
grant insert, update on table public.availability to authenticated;

drop policy if exists availability_public_read on public.availability;
create policy availability_public_read on public.availability
for select to anon, authenticated
using (id = 'public');

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

do $$
begin
  if not exists (
    select 1 from pg_publication where pubname = 'supabase_realtime'
  ) then
    execute 'create publication supabase_realtime';
  end if;

  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'availability'
  ) then
    execute
      'alter publication supabase_realtime add table public.availability';
  end if;
end;
$$;
