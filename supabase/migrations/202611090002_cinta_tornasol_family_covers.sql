-- Obsolete: the CINTA TORNASOL cover is managed from the admin portal and
-- stored in Supabase Storage. Re-applying the old bundled-cover update would
-- overwrite the image the user uploaded, so this migration intentionally does
-- nothing. It is kept as a no-op so the migration version remains tracked.
select 1;
