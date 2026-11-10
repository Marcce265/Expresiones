-- Backfill the Cache-Control metadata of catalog images uploaded before the
-- admin portal started sending `cacheControl: 31536000`.
--
-- This only changes object metadata; the files themselves are untouched.
-- Supabase Storage will serve the new header on the next request. Object paths
-- already include a timestamp/hash, so a one-year cache is safe.
update storage.objects
set cache_control = 'max-age=31536000'
where bucket_id = 'catalog'
  and (cache_control is null or cache_control <> 'max-age=31536000');

-- Verify with:
-- select cache_control, count(*)
-- from storage.objects
-- where bucket_id = 'catalog'
-- group by 1;
