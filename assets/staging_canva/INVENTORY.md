# Inventario de imágenes del catálogo

## Cobertura integrada

- Catálogo: **34 familias** (28 materiales, 3 ramos y 3 regalos personalizados).
- Materiales: **179 tarjetas** ordenadas por familia, una por cada referencia recuperada de Canva.
- Limpiapipas: **35 referencias visibles** con nombre y código de catálogo.
- Limpiapipas: **33 PNG con fondo transparente** y la fotografía completa indicada para **Piel · XS-27**.
- Cinta satinada: **34 referencias** con sus colores y fotografías del Canva.
- Cintas especiales: **32 referencias**; envolturas: **16**; accesorios: **35**; herramientas: **6**; frases: **21**.
- Referencias de imagen inválidas: **0**.

## Archivos de Canva conservados

- `assets/images/canva_raw/`: 179 recursos recuperados de las páginas del catálogo.
- `assets/images/canva_raw/manifest.json`: trazabilidad por índice y página.
- `docs/asset_contact_sheets/`: hojas de contacto para revisar las imágenes por página.
- `high_resolution/`: 8 fuentes originales de limpiapipas a 600 × 800 px.
- `raw_recovered/`: portada, hero y miniaturas recuperadas.

## Tratamiento aplicado

- Los recortes transparentes se aplican solo a limpiapipas; **Piel · XS-27** usa la fotografía completa solicitada.
- Cintas, coronas, tul, papel, herramientas y accesorios usan las fotografías originales del Canva y conservan su fondo.
- La interfaz usa `contain` para limpiapipas y `cover` para los demás materiales, sin márgenes vacíos en catálogo, detalle ni cotización.
- Los archivos originales de Canva se mantienen intactos en `assets/images/canva_raw/`.

## Productos sin foto en el catálogo de materiales

El Canva revisado contiene materiales y herramientas. No aporta fotografías para las familias creadas como ejemplo de productos hechos a pedido:

- Ramo clásico de 6 rosas.
- Ramo especial de 12 rosas.
- Ramo premium de 24 rosas.
- Rosas eternas con peluche.
- Ramo con Hot Wheels.
- Caja decorativa personalizada.

La app conserva el marcador visual para esas seis familias hasta contar con fotografías reales de Expresiones.

## Sincronización

- `lib/data/seed_catalog.dart`: catálogo local de Flutter.
- `scripts/catalog_seed.json`: semilla equivalente para el emulador de Firestore.
- Ambas fuentes contienen las mismas **179 referencias** de materiales.
- `scripts/build_complete_catalog.py` regenera ambas fuentes y comprueba que los índices 1–179 aparezcan exactamente una vez.
