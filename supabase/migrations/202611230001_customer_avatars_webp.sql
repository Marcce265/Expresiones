-- Keep JPEG compatibility for previously installed APKs while the new APK
-- uploads WebP. The bucket remains private and uses the existing owner policies.
update storage.buckets
set allowed_mime_types = array['image/jpeg', 'image/webp']::text[]
where id = 'customer-avatars';
