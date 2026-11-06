-- Serialize writes only when they target the same catalog product. This keeps
-- simultaneous administrators from colliding while unrelated products still
-- save in parallel. The transaction-scoped lock adds no polling or extra rows.

create or replace function public.serialize_catalog_family_write()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_slug text;
begin
  v_slug := case when tg_op = 'DELETE' then old.slug else new.slug end;
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(v_slug, 0)
  );
  return case when tg_op = 'DELETE' then old else new end;
end;
$$;

drop trigger if exists families_serialize_writes on public.families;
create trigger families_serialize_writes
before insert or update or delete on public.families
for each row execute function public.serialize_catalog_family_write();

revoke all on function public.serialize_catalog_family_write()
  from public, anon, authenticated;

comment on function public.serialize_catalog_family_write() is
  'Queues concurrent mutations per family slug with a transaction advisory lock.';
