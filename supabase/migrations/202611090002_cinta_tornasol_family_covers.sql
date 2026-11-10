-- Editorial family covers for the two iridescent ribbon products.
--
-- The first cover already lives in the Flutter asset bundle; replacing the
-- asset updates it after deploy. The second family used a Storage path, so it
-- is pointed to the new bundled cover here as well. Both statements are
-- idempotent and only touch the cover columns.
update public.families
set cover_path = 'assets/images/module_covers/cinta-organza-tornasol.jpg',
    cover_thumb_path = 'assets/images/module_covers/cinta-organza-tornasol_thumb.jpg',
    cover_detail_path = 'assets/images/module_covers/cinta-organza-tornasol.jpg',
    updated_at = now()
where slug = 'cinta-tornasol-4cm-7m';

update public.families
set cover_path = 'assets/images/module_covers/cinta-tornasol-7m.jpg',
    cover_thumb_path = 'assets/images/module_covers/cinta-tornasol-7m_thumb.jpg',
    cover_detail_path = 'assets/images/module_covers/cinta-tornasol-7m.jpg',
    updated_at = now()
where slug = 'cinta-tornasol-7m';
