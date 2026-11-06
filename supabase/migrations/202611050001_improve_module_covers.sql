-- High-quality family covers composed from each module's real variants.
-- Detail images remain crisp in the family page; lightweight thumbnails keep
-- catalog browsing inexpensive. Variant photos are intentionally unchanged.
update public.families as family
set
  cover_path = cover.detail_path,
  cover_detail_path = cover.detail_path,
  cover_thumb_path = cover.thumb_path,
  updated_at = now()
from (
  values
    ('tul-con-perlas', 'assets/images/module_covers/tul-con-perlas.jpg', 'assets/images/module_covers/tul-con-perlas_thumb.jpg'),
    ('alambre-floral', 'assets/images/module_covers/alambre-floral.jpg', 'assets/images/module_covers/alambre-floral_thumb.jpg'),
    ('papel-leche-cortado', 'assets/images/module_covers/papel-leche-cortado.jpg', 'assets/images/module_covers/papel-leche-cortado_thumb.jpg'),
    ('cinta-tornasol-4cm-7m', 'assets/images/module_covers/cinta-organza-tornasol.jpg', 'assets/images/module_covers/cinta-organza-tornasol_thumb.jpg'),
    ('cinta-organza-con-perlas', 'assets/images/module_covers/cinta-organza-con-perlas.jpg', 'assets/images/module_covers/cinta-organza-con-perlas_thumb.jpg'),
    ('cinta-corazones-dorados', 'assets/images/module_covers/cinta-corazones-dorados.jpg', 'assets/images/module_covers/cinta-corazones-dorados_thumb.jpg'),
    ('cinta-estampada-lujo', 'assets/images/module_covers/cinta-estampada-lujo.jpg', 'assets/images/module_covers/cinta-estampada-lujo_thumb.jpg'),
    ('cinta-eternal-love', 'assets/images/module_covers/cinta-eternal-love.jpg', 'assets/images/module_covers/cinta-eternal-love_thumb.jpg'),
    ('perlas-decorativas', 'assets/images/module_covers/perlas-decorativas.jpg', 'assets/images/module_covers/perlas-decorativas_thumb.jpg'),
    ('floratape', 'assets/images/module_covers/floratape.jpg', 'assets/images/module_covers/floratape_thumb.jpg'),
    ('brochetas', 'assets/images/module_covers/brochetas.jpg', 'assets/images/module_covers/brochetas_thumb.jpg'),
    ('luz-hada', 'assets/images/module_covers/luz-hada.jpg', 'assets/images/module_covers/luz-hada_thumb.jpg'),
    ('mariposas-decorativas', 'assets/images/module_covers/mariposas-decorativas.jpg', 'assets/images/module_covers/mariposas-decorativas_thumb.jpg'),
    ('frases-en-vinil', 'assets/images/module_covers/frases-en-vinil.jpg', 'assets/images/module_covers/frases-en-vinil_thumb.jpg')
) as cover(slug, detail_path, thumb_path)
where family.slug = cover.slug;
