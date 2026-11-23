-- Replace legacy bundled-asset family cover paths ('assets/images/...') with
-- each family's first active variant image stored in Supabase Storage.
-- All dynamic product, variant, and cover images are served exclusively from
-- Supabase Storage so the app bundle only ships static UI assets.
with first_variant as (
  select distinct on (v.family_id)
    v.family_id,
    v.image_path,
    v.thumb_path,
    v.detail_path
  from public.variants v
  where v.active is true
    and v.image_path is not null
    and btrim(v.image_path) <> ''
    and v.image_path not like 'assets/%'
  order by v.family_id, v.sort_order asc, v.created_at asc
)
update public.families f
set
  cover_path = fv.image_path,
  cover_thumb_path = coalesce(nullif(btrim(fv.thumb_path), ''), fv.image_path),
  cover_detail_path = coalesce(nullif(btrim(fv.detail_path), ''), fv.image_path),
  updated_at = now()
from first_variant fv
where f.id = fv.family_id
  and (
    f.cover_path is null
    or btrim(f.cover_path) = ''
    or f.cover_path like 'assets/%'
  );
