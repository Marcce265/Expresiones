-- Anonymous, aggregate-only product popularity used by the public home page.
-- No visitor identifier, IP address, cart contents, or other personal data is
-- stored. Public clients may read the aggregate ranking and can only increment
-- counters through the narrowly-scoped RPC below.

create table if not exists public.product_popularity (
  product_slug text primary key
    references public.families(slug) on update cascade on delete cascade,
  views bigint not null default 0,
  units_added bigint not null default 0,
  units_completed bigint not null default 0,
  score bigint generated always as (
    views + (units_added * 2) + (units_completed * 5)
  ) stored,
  updated_at timestamptz not null default now(),
  constraint product_popularity_slug_format
    check (product_slug ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$'),
  constraint product_popularity_views_nonnegative check (views >= 0),
  constraint product_popularity_units_added_nonnegative
    check (units_added >= 0),
  constraint product_popularity_units_completed_nonnegative
    check (units_completed >= 0)
);

create index if not exists product_popularity_rank_idx
  on public.product_popularity (
    score desc,
    units_completed desc,
    units_added desc,
    views desc,
    updated_at desc
  );

alter table public.product_popularity enable row level security;

drop policy if exists product_popularity_public_read
  on public.product_popularity;
create policy product_popularity_public_read
on public.product_popularity
for select
to anon, authenticated
using (
  exists (
    select 1
    from public.families family
    join public.categories category on category.id = family.category_id
    where family.slug = product_popularity.product_slug
      and family.active
      and category.active
  )
);

revoke all on table public.product_popularity from public, anon, authenticated;
grant select on table public.product_popularity to anon, authenticated;

create schema if not exists metrics_private;
revoke all on schema metrics_private from public;
grant usage on schema metrics_private to anon, authenticated;

create or replace function metrics_private.record_product_popularity_internal(
  p_product_slug text,
  p_action text,
  p_quantity integer default 1
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  normalized_slug text := btrim(coalesce(p_product_slug, ''));
  normalized_action text := lower(btrim(coalesce(p_action, '')));
begin
  if normalized_slug = ''
      or normalized_slug !~ '^[a-z0-9]+(?:-[a-z0-9]+)*$' then
    raise exception using
      errcode = '22023',
      message = 'Invalid product slug.';
  end if;

  if normalized_action not in ('view', 'add', 'complete') then
    raise exception using
      errcode = '22023',
      message = 'Invalid popularity action.';
  end if;

  if p_quantity is null or p_quantity < 1 or p_quantity > 10000 then
    raise exception using
      errcode = '22023',
      message = 'Popularity quantity must be between 1 and 10000.';
  end if;

  insert into public.product_popularity (
    product_slug,
    views,
    units_added,
    units_completed,
    updated_at
  )
  select
    family.slug,
    case when normalized_action = 'view' then 1 else 0 end,
    case when normalized_action = 'add' then p_quantity else 0 end,
    case when normalized_action = 'complete' then p_quantity else 0 end,
    now()
  from public.families family
  join public.categories category on category.id = family.category_id
  where family.slug = normalized_slug
    and family.active
    and category.active
  on conflict (product_slug) do update
  set views = public.product_popularity.views
        + case when normalized_action = 'view' then 1 else 0 end,
      units_added = public.product_popularity.units_added
        + case when normalized_action = 'add' then p_quantity else 0 end,
      units_completed = public.product_popularity.units_completed
        + case when normalized_action = 'complete' then p_quantity else 0 end,
      updated_at = now();
end;
$$;

-- Keep the privileged implementation outside exposed schemas. The public RPC
-- is an invoker-rights wrapper, so Supabase's Data API can reach it without
-- exposing a SECURITY DEFINER function in public.
revoke all on function metrics_private.record_product_popularity_internal(
  text,
  text,
  integer
)
  from public, anon, authenticated;
grant execute
  on function metrics_private.record_product_popularity_internal(
    text,
    text,
    integer
  )
  to anon, authenticated;

create or replace function public.record_product_popularity(
  p_product_slug text,
  p_action text,
  p_quantity integer default 1
)
returns void
language sql
security invoker
set search_path = ''
as $$
  select metrics_private.record_product_popularity_internal(
    p_product_slug,
    p_action,
    p_quantity
  );
$$;

revoke all on function public.record_product_popularity(text, text, integer)
  from public, anon, authenticated;
grant execute
  on function public.record_product_popularity(text, text, integer)
  to anon, authenticated;
