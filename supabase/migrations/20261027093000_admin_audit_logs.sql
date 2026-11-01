-- Compact and immutable administration history.
-- Only logical resources are audited, never every variant or price row. A
-- product with 80 colours therefore still creates a single audit entry.

create table if not exists public.admin_audit_logs (
  id bigint generated always as identity primary key,
  action text not null,
  resource_type text not null,
  resource_id text not null,
  resource_label text not null default '',
  actor_id uuid not null,
  actor_email text,
  changed_sections text[] not null default '{}'::text[],
  created_at timestamptz not null default now(),
  constraint admin_audit_logs_action_check
    check (action in ('create', 'update', 'delete')),
  constraint admin_audit_logs_resource_type_check
    check (resource_type in ('catalog_product', 'site_settings', 'availability'))
);

comment on table public.admin_audit_logs is
  'Immutable compact history of administrator actions; one row per logical resource change.';

create index if not exists admin_audit_logs_created_at_idx
  on public.admin_audit_logs (created_at desc);

alter table public.admin_audit_logs enable row level security;

revoke all on table public.admin_audit_logs from public, anon, authenticated;
revoke all on sequence public.admin_audit_logs_id_seq
  from public, anon, authenticated;
grant select on table public.admin_audit_logs to authenticated;

drop policy if exists admin_audit_logs_admin_read on public.admin_audit_logs;
create policy admin_audit_logs_admin_read on public.admin_audit_logs
for select to authenticated
using (public.can_admin_write());

create schema if not exists audit_private;
revoke all on schema audit_private from public, anon, authenticated;

create or replace function audit_private.capture_family_admin_action()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor_id uuid := auth.uid();
  v_action text;
  v_row public.families%rowtype;
  v_sections text[] := '{}'::text[];
begin
  if v_actor_id is null or not public.can_admin_write() then
    return null;
  end if;

  if tg_op = 'DELETE' then
    v_action := 'delete';
    v_row := old;
    v_sections := array['producto completo'];
  elsif tg_op = 'INSERT' then
    v_action := 'create';
    v_row := new;
    v_sections := array['datos del producto'];
  else
    v_action := 'update';
    v_row := new;

    if row(new.name, new.description, new.sku, new.category_id,
           new.sale_unit, new.tags, new.attributes, new.sort_order)
       is distinct from
       row(old.name, old.description, old.sku, old.category_id,
           old.sale_unit, old.tags, old.attributes, old.sort_order) then
      v_sections := array_append(v_sections, 'datos del producto');
    end if;
    if row(new.base_price, new.stock_count, new.stock_status)
       is distinct from
       row(old.base_price, old.stock_count, old.stock_status) then
      v_sections := array_append(v_sections, 'precio y disponibilidad');
    end if;
    if row(new.prep_days, new.production_points)
       is distinct from
       row(old.prep_days, old.production_points) then
      v_sections := array_append(v_sections, 'preparación');
    end if;
    if row(new.cover_path, new.cover_thumb_path, new.cover_detail_path)
       is distinct from
       row(old.cover_path, old.cover_thumb_path, old.cover_detail_path) then
      v_sections := array_append(v_sections, 'imagen principal');
    end if;
    if row(new.active, new.featured)
       is distinct from row(old.active, old.featured) then
      v_sections := array_append(v_sections, 'visibilidad');
    end if;

    -- admin_save_catalog_family always updates the family row. If none of its
    -- own columns changed, the administrator edited variants or price tiers.
    if cardinality(v_sections) = 0 then
      v_sections := array['variantes o precios'];
    end if;
  end if;

  insert into public.admin_audit_logs (
    action,
    resource_type,
    resource_id,
    resource_label,
    actor_id,
    actor_email,
    changed_sections
  ) values (
    v_action,
    'catalog_product',
    v_row.id::text,
    v_row.name,
    v_actor_id,
    nullif(auth.jwt() ->> 'email', ''),
    v_sections
  );
  return null;
end;
$$;

create or replace function audit_private.capture_settings_admin_action()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor_id uuid := auth.uid();
  v_resource_type text;
  v_resource_label text;
  v_sections text[];
begin
  if v_actor_id is null or not public.can_admin_write() then
    return null;
  end if;

  if tg_table_name = 'site_settings' then
    v_resource_type := 'site_settings';
    v_resource_label := 'Contenido y formulario de la tienda';
    v_sections := array['configuración de la tienda'];
  else
    v_resource_type := 'availability';
    v_resource_label := 'Fechas y días de entrega';
    v_sections := array['calendario de entregas'];
  end if;

  insert into public.admin_audit_logs (
    action,
    resource_type,
    resource_id,
    resource_label,
    actor_id,
    actor_email,
    changed_sections
  ) values (
    case when tg_op = 'INSERT' then 'create' else 'update' end,
    v_resource_type,
    'public',
    v_resource_label,
    v_actor_id,
    nullif(auth.jwt() ->> 'email', ''),
    v_sections
  );
  return null;
end;
$$;

drop trigger if exists families_admin_activity on public.families;
create trigger families_admin_activity
after insert or update or delete on public.families
for each row execute function audit_private.capture_family_admin_action();

drop trigger if exists site_settings_admin_activity on public.site_settings;
create trigger site_settings_admin_activity
after insert or update on public.site_settings
for each row execute function audit_private.capture_settings_admin_action();

drop trigger if exists availability_admin_activity on public.availability;
create trigger availability_admin_activity
after insert or update on public.availability
for each row execute function audit_private.capture_settings_admin_action();

revoke all on all functions in schema audit_private
  from public, anon, authenticated;

