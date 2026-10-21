# Esquema de Cloud Firestore

Expresiones usa **Cloud Firestore** como catálogo remoto. La cotización, los
datos del cliente y la selección actual permanecen en el dispositivo; solo se
comparten cuando la persona pulsa el botón de WhatsApp.

El panel web administrativo usa Firebase Authentication. Solo una cuenta cuyo
token tenga el custom claim `admin: true` puede leer productos ocultos o
crear, modificar y eliminar documentos del catálogo.

## `products/{productId}`

Cada documento representa un producto y puede contener variantes de color o
presentación.

| Campo | Tipo | Descripción |
| --- | --- | --- |
| `name` | string | Nombre comercial. |
| `category` | string | `materials`, `bouquets` o `personalized_gifts`. |
| `description` | string | Descripción pública. |
| `sku` | string | Código general opcional. |
| `unitLabel` | string | `paquete`, `rollo`, `ramo`, etc. |
| `basePrice` | number | Precio unitario en soles. |
| `startingAt` | bool | Muestra el prefijo “Desde”. |
| `priceIsEstimate` | bool | Indica que el precio requiere confirmación. |
| `priceTiers` | array | Tramos `{minQuantity, unitPrice, label}`. |
| `variants` | array | Color/presentación, código, imagen y precios propios. |
| `stockStatus` | string | Disponibilidad pública. |
| `leadDays` | number | Días mínimos de preparación. |
| `productionPoints` | number | Carga de trabajo estimada. |
| `isActive` | bool | Solo los documentos `true` son públicos. |
| `isFeatured` | bool | Aparece entre los más consultados. |
| `sortOrder` | number | Orden ascendente del catálogo. |
| `imageUrl` | string | Asset local o URL HTTPS. |
| `tags` | array | Términos de búsqueda. |
| `attributes` | map | Datos como medida o contenido. |

La consulta usada por Flutter es:

```dart
FirebaseFirestore.instance
    .collection('products')
    .where('isActive', isEqualTo: true)
    .orderBy('sortOrder');
```

El índice necesario ya está declarado en `firestore.indexes.json` y las reglas
de `firestore.rules` permiten leer únicamente productos activos. Todas las
escrituras desde la aplicación pública quedan bloqueadas.

## Documentos públicos opcionales

- `settings/public`: nombre comercial, WhatsApp, ciudad de recojo y textos.
- `availability/public`: ventana pública de fechas y aviso de capacidad.
- `categories/{id}`: datos editoriales de categorías activas.

La versión actual calcula la fecha mínima con los días de preparación y los
puntos de producción del producto. Expresiones confirma la capacidad real por
WhatsApp.

## Catálogo inicial

`scripts/catalog_seed.json` contiene los mismos 30 productos que usa el modo
local de Flutter. `scripts/seed_firestore.js` carga ese archivo solamente en el
emulador local y se niega a escribir en hosts remotos.

```powershell
$env:JAVA_HOME = 'C:\Program Files\Android\Android Studio\jbr'
$env:Path = "$env:JAVA_HOME\bin;$env:Path"
firebase emulators:start --only firestore --project expresiones-local
```

En otra terminal:

```powershell
$env:FIRESTORE_EMULATOR_HOST = '127.0.0.1:8080'
$env:GCLOUD_PROJECT = 'expresiones-local'
node .\scripts\seed_firestore.js
```

Este diseño evita cuentas de cliente, carritos remotos, pagos y escrituras por
cada toque. Así reduce lecturas y mantiene el MVP dentro del plan gratuito
Spark mientras el tráfico sea moderado.

## Administración del catálogo real

El punto de entrada `lib/admin_main.dart` carga el panel independiente. Las
instrucciones para crear la cuenta, asignar el claim, importar el catálogo y
compilar la web están en `docs/admin_portal.md`.

Las reglas validan, además de la autorización, los tipos y rangos principales:

- precio entre S/ 0 y S/ 1 000 000;
- stock entero no negativo;
- máximo 250 variantes por producto;
- plazo de preparación entre 0 y 365 días;
- identificadores de disponibilidad admitidos por Flutter.
