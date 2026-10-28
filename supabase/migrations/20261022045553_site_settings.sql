-- Public CMS content edited exclusively by administrators with MFA AAL2.

create table if not exists public.site_settings (
  id text primary key default 'public',
  data jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users(id) on delete set null,
  constraint site_settings_singleton check (id = 'public'),
  constraint site_settings_data_object check (jsonb_typeof(data) = 'object')
);

comment on table public.site_settings is
  'Single public row containing editable storefront copy and business settings.';

insert into public.site_settings (id, data)
values ('public', '{}'::jsonb)
on conflict (id) do nothing;

drop trigger if exists site_settings_audit on public.site_settings;
create trigger site_settings_audit
before insert or update on public.site_settings
for each row execute function public.set_update_audit_fields();

create index if not exists site_settings_updated_by_idx
  on public.site_settings (updated_by);

alter table public.site_settings enable row level security;

revoke all on table public.site_settings from anon, authenticated;
grant select on table public.site_settings to anon, authenticated;
grant insert, update on table public.site_settings to authenticated;

drop policy if exists site_settings_public_read on public.site_settings;
create policy site_settings_public_read on public.site_settings
for select to anon, authenticated
using (id = 'public');

drop policy if exists site_settings_admin_write on public.site_settings;
drop policy if exists site_settings_admin_insert on public.site_settings;
drop policy if exists site_settings_admin_update on public.site_settings;
drop policy if exists site_settings_admin_delete on public.site_settings;
create policy site_settings_admin_insert on public.site_settings
for insert to authenticated
with check (id = 'public' and public.can_admin_write());
create policy site_settings_admin_update on public.site_settings
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
      and tablename = 'site_settings'
  ) then
    execute
      'alter publication supabase_realtime add table public.site_settings';
  end if;
end;
$$;
