# Auditoría de calidad de imágenes del catálogo

Fecha de revisión: 14 de octubre de 2026.

## Resultado general

- El catálogo de materiales contiene **179 variantes** con índices del 001 al 179.
- Los **179 archivos referenciados existen y se pueden decodificar**.
- Solo hay **160 imágenes únicas**: 19 variantes reutilizan exactamente el mismo archivo que otra variante.
- **48 imágenes son críticamente pequeñas**. Cuarenta y siete tienen apenas entre 28 y 50 px por lado; la restante mide 225 × 225 px. Estas son las imágenes que se ven fuertemente pixeladas en la aplicación.
- **11 imágenes tienen entre 400 y 599 px** en el lado menor. Son utilizables en tarjetas pequeñas, pero pueden verse suaves en la vista de detalle.
- **55 imágenes tienen entre 600 y 799 px** en el lado menor. En general sirven para móvil, aunque no son ideales para ampliación.
- **65 imágenes tienen 800 px o más** en el lado menor.
- El render de Flutter usa `FilterQuality.high` y no limita `cacheWidth`; la pixelación crítica proviene de los archivos fuente, no del widget.

## Reemplazo urgente: 48 imágenes

| Familia | Índices | Dimensiones actuales |
|---|---|---|
| Cinta satinada 100 m | 070 | 28 × 50 |
| Coronitas decorativas | 065, 074, 075, 076 | 49 × 42 a 49 × 47 |
| Tul con perlas | 077, 078, 081, 082, 083 | 50 × 50 |
| Tarjetero acrílico | 084 | 46 × 49 |
| Papel leche cortado | 087–095 | 38 × 49 |
| Cinta tornasol 4 cm × 7 m | 096–101 | 37 × 49 |
| Cinta con corazones dorados | 116–121 | 37 × 49 |
| Cinta estampada de lujo | 122–124 | 37 × 49 |
| Brochetas | 137–139 | 33 × 50 |
| Luz hada | 141 | 50 × 37 |
| Mariposas decorativas | 148–154 | 37 × 49 |
| Frases en vinil | 175 | 49 × 37 |
| Máquina cortadora | 178 | 225 × 225 |

### Detalle por índice

- **065** Corona perlada plateada — 49 × 42 px.
- **070** Cinta satinada, amarillo tono 31C — 28 × 50 px.
- **074** Corona plateada 5 cm — 49 × 42 px.
- **075** Corona dorada perlada 5 cm — 49 × 46 px.
- **076** Corona dorada perlada 7 cm — 49 × 47 px.
- **077, 078, 081, 082, 083** Tul con perlas: blanco, rosa bebé, melón, rojo y beige — 50 × 50 px.
- **084** Tarjetero acrílico 23.3 cm — 46 × 49 px.
- **087–095** Papel leche: blanco, rojo, rosa bebé, negro, perla, verde agua, fucsia, lila y amarillo bebé — 38 × 49 px.
- **096–101** Cinta tornasol 4 cm × 7 m: perla, melón, rosa bebé, blanco, amarillo tornasol y rojo coral — 37 × 49 px.
- **116–121** Cinta con corazones dorados: rosa, negro, blanco, marfil, vino y rojo — 37 × 49 px.
- **122–124** Cinta estampada de lujo: rosa, negro y blanco — 37 × 49 px.
- **137–139** Brochetas: paquete múltiple 01, paquete múltiple 02 y paquete individual — 33 × 50 px.
- **141** Luz hada infinito blanca — 50 × 37 px.
- **148–154** Mariposas: fucsia con dorado, rosa dorado, dorado clásico, tornasol, dorado compacto, amarillo tornasol y verde con dorado — 37 × 49 px.
- **175** Frase en vinil, cumpleaños familiar — 49 × 37 px.
- **178** Máquina cortadora automática — 225 × 225 px.

## Imágenes suaves: 11 casos

Estas deberían reemplazarse después del grupo crítico si la vista de detalle aún se ve borrosa.

| Índice | Producto / variante | Dimensiones |
|---:|---|---:|
| 024, 049 | Cinta satinada, piel bebé | 576 × 1024 |
| 050 | Cinta satinada, piel | 576 × 1024 |
| 051 | Cinta satinada, amarillo pastel tono 31C | 576 × 1024 |
| 063, 072 | Coronitas dorada y plateada | 472 × 413 |
| 071 | Coronita dorada | 412 × 440 |
| 085 | Alambre floral | 554 × 554 |
| 086 | Ganchos para foto | 500 × 500 |
| 131 | Cinta doble contacto | 500 × 477 |
| 179 | Cautín 30 W | 447 × 447 |

## Duplicados exactos

Los siguientes grupos comparten los mismos bytes. Los casos llamados “segunda referencia” parecen duplicaciones deliberadas, pero varios nombres de color distintos también apuntan a una sola fotografía.

- 039 = 042.
- 018 = 043; 019 = 044; 020 = 045; 021 = 046; 022 = 047; 023 = 048; 024 = 049.
- 053 = 056; 055 = 058; 059 = 066; 063 = 072; 065 = 074.
- **054 = 057 = 060 = 061**: rosa pastel y rosa claro comparten una sola imagen.
- **062 = 067**: blanco y blanco perlado comparten una sola imagen.
- **064 = 068 = 073**: champagne, marfil y champagne uva comparten una sola imagen.

## Problema del manifiesto HD

`assets/images/catalog_hd/manifest.json` marca casi todas las miniaturas de 28–50 px como `isHighResolution: true`. Por eso ese campo no sirve como control de calidad. La validación debe abrir el archivo final y exigir dimensiones reales, por ejemplo un mínimo de 800 × 800 px o 1000 px en el lado mayor.

Los índices 053, 054, 055 y 060 no tienen recuperación HD propia en el manifiesto. En el catálogo actual se resolvieron reutilizando imágenes de otros índices, lo cual explica parte de los duplicados.

## Otros productos sin fotografía

Fuera de los 179 materiales, hay 15 variantes de ramos y regalos sin `imageUrl`. Flutter muestra el recurso visual genérico en esos casos. Corresponden a:

- Ramo clásico de 6 rosas: 3 variantes.
- Ramo especial de 12 rosas: 3 variantes.
- Ramo premium de 24 rosas: 3 variantes.
- Rosas eternas con peluche: 2 variantes.
- Ramo con Hot Wheels: 2 variantes.
- Caja decorativa personalizada: 2 variantes.

## Acción recomendada

1. Recuperar o reemplazar las 48 imágenes críticas con fuentes reales de al menos 800 px por lado, conservando cada color y producto correcto.
2. Evitar ampliar las miniaturas actuales: un reescalado no recuperará detalle y seguirá viéndose pixelado.
3. Corregir los grupos duplicados que representan colores distintos.
4. Mantener el recorte de etiquetas de las cintas satinadas, pero partir de una fotografía de alta resolución sin rótulos incrustados cuando esté disponible.
5. Validar automáticamente dimensiones y decodificación del archivo final antes de marcar una imagen como HD.

El inventario técnico completo, con ruta, dimensiones, bytes, hash y métricas de cada variante, está en `docs/catalog_image_audit.json`.
