-- Backfill the Cache-Control metadata of catalog images uploaded before the
-- admin portal started sending `cacheControl: 31536000`.
--
-- On current Supabase Storage the served `Cache-Control` header comes from the
-- object's S3 metadata. Updating this JSONB keeps the Storage API metadata and
-- the `/object/info` endpoint in sync, but changing the header itself requires
-- a server-side copy through the Storage API. That copy was applied to the
-- production project on 2026-11-10 for all catalog objects.
--
-- Object names include a timestamp or content hash, so a one-year cache is
-- safe. This statement is idempotent.
update storage.objects
set metadata = jsonb_set(
  coalesce(metadata, '{}'::jsonb),
  '{cacheControl}',
  to_jsonb('max-age=31536000'::text)
)
where bucket_id = 'catalog'
  and coalesce(metadata->>'cacheControl', '') not in (
    'max-age=31536000',
    'public, max-age=31536000, immutable'
  );

-- Verify with:
-- select coalesce(metadata->>'cacheControl', '(null)'), count(*)
-- from storage.objects
-- where bucket_id = 'catalog'
-- group by 1;
