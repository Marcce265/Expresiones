# Supabase para Expresiones

Esta carpeta reemplaza la infraestructura prevista para Firestore sin cambiar
el catálogo ni el flujo de cotización. La aplicación pública solo lee datos;
las escrituras requieren una cuenta incluida en `public.admins` y una sesión
MFA TOTP con nivel `aal2`.

## Estado del catálogo fuente

La fuente única del seed es `scripts/catalog_seed.json`. El validador comprueba
estos valores antes de permitir una escritura:

| Dato | Cantidad |
| --- | ---: |
| Familias totales | 37 |
| Familias públicas | 31 |
| Variantes totales | 238 |
| Variantes de familias públicas | 223 |
| Tramos de familia | 29 |
| Tramos de variante | 0 |
| Imágenes distintas referenciadas | 221 |

Las 31 familias públicas corresponden a materiales. Las seis familias
inactivas son ramos y regalos que se podrán publicar después. Las 221 que antes
se contaron como “variantes” son en realidad imágenes distintas; el número
correcto de variantes públicas es 223.

Todos los precios del seed se guardan como definitivos
(`price_is_reference = false`), conforme a la decisión del negocio. El campo
`starting_at` se conserva: “Desde” y “precio referencial” son conceptos
diferentes.

## Archivos

- `supabase/migrations/202610200001_catalog_backend.sql`: esquema, funciones,
  RLS, bucket y RPC administrativas.
- `supabase/config.toml`: configuración del entorno local de Supabase; el
  registro público está deshabilitado.
- `scripts/seed_supabase.mjs`: validación, seed idempotente y carga opcional de
  imágenes optimizadas.

No existe un `supabase/seed.sql` duplicado. El JSON actual es grande y ya es la
fuente versionada; mantener una segunda copia SQL facilitaría que precios o
nombres quedaran desincronizados.

## Modelo que consume Flutter

`families.slug` conserva `CatalogProduct.id` y `variants.slug` conserva
`ProductVariant.id`. No se deben sustituir por los UUID internos en el carrito,
los enlaces ni `SharedPreferences`.

### Tablas principales

- `categories`: las tres categorías actuales y su `kind` estable.
- `families`: datos generales, precio base, stock, publicación, orden e imagen.
- `variants`: presentaciones/colores y sus sobrescrituras opcionales.
- `family_price_tiers`: tramos heredados por las variantes.
- `variant_price_tiers`: tramos que reemplazan los de la familia.
- `availability`: una fila `id = 'public'`; `data` conserva exactamente el
  formato camelCase de `ProductionCapacitySnapshot.toMap()`.
- `catalog_metadata`: versión y fecha para la actualización local primero.
- `admins`: lista cerrada de los dos UUID autorizados.

Los campos `cover_path`/`image_path` aceptan temporalmente el asset local. Al
usar `--upload-images`, pasan a contener rutas del bucket `catalog` y se llenan
también los campos `*_thumb_path` y `*_detail_path`. Son rutas de Storage, no
URLs completas; Flutter debe resolverlas con `getPublicUrl`.

Una consulta pública puede anidar las relaciones así:

```text
families(
  *,
  categories(*),
  family_price_tiers(*),
  variants(*, variant_price_tiers(*))
)
```

El adaptador convierte snake_case a los nombres camelCase de los modelos
actuales. Para `imageUrl`, debe preferir `detail_path`, después `image_path`; en
una lista debe preferir `thumb_path`.

## Crear el proyecto sin costo

1. Crear un proyecto Supabase Free y elegir una región cercana disponible.
2. No activar complementos pagados ni asociar la clave `service_role` al
   frontend.
3. En **Authentication > Providers > Email**, mantener correo/contraseña y
   desactivar el registro público. La creación de usuarios será manual.
4. Activar MFA TOTP. No usar SMS.
5. Instalar Supabase CLI para desarrollo local o vincular el repositorio al
   proyecto:

```bash
supabase login
supabase link --project-ref TU_PROJECT_REF
supabase db push
```

También se puede copiar la migración completa al SQL Editor una sola vez. No
se debe copiar allí ninguna clave de Flutter.

## Validar y cargar el catálogo

La simulación no requiere credenciales ni conexión:

```bash
node scripts/seed_supabase.mjs
```

Para el primer seed remoto, copiar la clave `service_role` solo a variables de
la terminal. `ALLOW_SUPABASE_SEED` debe coincidir exactamente con el host para
evitar escribir en el proyecto equivocado:

```bash
export SUPABASE_URL='https://TU_PROJECT_REF.supabase.co'
export SUPABASE_SERVICE_ROLE_KEY='CLAVE_SERVICE_ROLE'
export ALLOW_SUPABASE_SEED='TU_PROJECT_REF.supabase.co'

node scripts/seed_supabase.mjs --apply --upload-images
unset SUPABASE_SERVICE_ROLE_KEY
```

`--upload-images` usa ImageMagick para producir WebP de 400 px (calidad 75) y
1200 px (calidad 80), los sube al bucket `catalog` y enlaza las rutas. Los
archivos se deduplican por SHA-256. Sin ese indicador, el seed conserva las
rutas de assets locales y no se deben retirar todavía del paquete Flutter.

El script hace upsert; no elimina familias ni variantes remotas que no estén en
el JSON. El borrado normal desde el panel debe seguir siendo lógico
(`active = false`).

## Crear los dos administradores

Crear cada usuario manualmente en **Authentication > Users**, con correos y
contraseñas diferentes. Después copiar sus UUID y ejecutar en el SQL Editor:

```sql
insert into public.admins (user_id, display_name)
values
  ('UUID_ADMIN_1', 'Administrador 1'),
  ('UUID_ADMIN_2', 'Administradora 2')
on conflict (user_id) do update
set display_name = excluded.display_name;
```

No existe política que permita a la aplicación modificar `admins`. Solo el SQL
Editor/service role puede conceder o retirar ese acceso.

El flujo del panel es:

1. `signInWithPassword` deja la sesión en `aal1`.
2. Llamar `rpc('is_current_admin')`; funciona en `aal1` y solo confirma
   membresía.
3. Enrolar o verificar TOTP con la API MFA de Supabase.
4. Confirmar que el nivel siguiente/actual sea `aal2`.
5. Recién entonces habilitar las acciones de guardar.

La interfaz no es la barrera de seguridad. RLS y las RPC vuelven a exigir
`is_current_admin() AND is_aal2()` en el servidor.

## RPC para el panel actual

### `admin_save_catalog_family(payload jsonb)`

Acepta el mapa completo que hoy produce `CatalogProduct.toMap()`:

```json
{
  "id": "cinta-satinada-100m",
  "name": "Cinta satinada 100 m",
  "category": "materials",
  "description": "...",
  "sku": "",
  "unitLabel": "rollo",
  "basePrice": 29,
  "startingAt": false,
  "priceIsEstimate": false,
  "priceTiers": [],
  "variants": [],
  "stockStatus": "check_availability",
  "leadDays": 0,
  "productionPoints": 0,
  "isActive": true,
  "isFeatured": true,
  "sortOrder": 20,
  "imageUrl": "images/.../detail.webp",
  "tags": [],
  "attributes": {}
}
```

La operación es transaccional: actualiza la familia, reemplaza sus tramos,
hace upsert de todas las variantes y reemplaza sus tramos. Las variantes que
ya existían pero no llegan en el mapa completo se desactivan. Devuelve una fila
`{id: UUID, slug: TEXT}`.

### `admin_delete_catalog_family(family_slug text)`

Hace borrado físico en cascada y devuelve `true` si encontró la familia. Se
incluye para una acción excepcional con doble confirmación. La interfaz normal
debe llamar `admin_save_catalog_family` con `isActive = false`.

## Disponibilidad

La lectura pública es una sola fila:

```sql
select data from public.availability where id = 'public';
```

El panel guarda con un `upsert` de `{id: 'public', data: snapshot.toMap()}`.
RLS exige admin + AAL2 y el trigger asigna `updated_at`/`updated_by`.

## Pruebas de seguridad mínimas

Antes de publicar, comprobar con la clave `anon`:

- SELECT devuelve 31 familias y 223 variantes visibles.
- No devuelve las seis familias inactivas ni sus 15 variantes.
- No permite insertar, actualizar ni borrar.
- Los tramos de productos inactivos tampoco son públicos.
- Un usuario administrador en `aal1` puede obtener
  `is_current_admin() = true`, pero no escribir.
- El mismo usuario después de TOTP (`aal2`) sí puede guardar mediante la RPC.
- Un usuario autenticado que no está en `admins` no puede escribir ni en
  Postgres ni en Storage.

El bucket es público únicamente para descargar objetos por ruta. Listar,
subir, reemplazar o borrar objetos requiere las políticas administrativas; las
mutaciones exigen AAL2.

## Variables de Flutter

Solo estas dos variables públicas van en `--dart-define`:

```json
{
  "SUPABASE_URL": "https://TU_PROJECT_REF.supabase.co",
  "SUPABASE_ANON_KEY": "CLAVE_ANON_PUBLICA"
}
```

Nunca incluir `SUPABASE_SERVICE_ROLE_KEY`. Para desarrollo sin configuración,
el repositorio local debe continuar funcionando como respaldo.
