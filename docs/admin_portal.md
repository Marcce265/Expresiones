# Panel administrativo de Expresiones

El panel permite administrar el catálogo de Firestore desde el navegador sin
dar permisos de escritura a la aplicación pública. Tiene un punto de entrada
independiente en `lib/admin_main.dart` para poder publicarlo en una URL privada
o en un segundo sitio de Firebase Hosting.

## Funciones incluidas

- Inicio de sesión con correo y contraseña mediante Firebase Authentication.
- Segunda verificación mediante el custom claim `admin: true`.
- Resumen de productos publicados, precios por revisar y stock bajo.
- Búsqueda por nombre, código o variante.
- Creación de productos.
- Edición de nombre, descripción, categoría, unidad, precio base, stock,
  disponibilidad, plazo de preparación, puntos de producción y orden.
- Edición de precio, stock, disponibilidad y publicación de cada variante.
- Publicación u ocultamiento inmediato de un producto.
- Edición de la capacidad semanal del taller, reservas agregadas, cierres y
  capacidad excepcional por fecha.
- Resumen anónimo de vistas, productos agregados, búsquedas sin resultado,
  aperturas de WhatsApp y cotizaciones abandonadas.

## Configuración inicial en Firebase

1. Crear el proyecto en Firebase Console y habilitar Cloud Firestore.
2. En **Authentication > Sign-in method**, habilitar correo y contraseña.
3. Crear manualmente la cuenta del administrador en **Authentication > Users**.
4. Copiar `firebase_config.example.json` como `firebase_config.json` y colocar
   los valores públicos de la aplicación web de Firebase.
5. Desplegar las reglas e índices:

```powershell
firebase use TU_PROJECT_ID
firebase deploy --only firestore:rules,firestore:indexes
```

Los valores de `firebase_config.json` identifican la aplicación web y no son
una contraseña. El archivo se mantiene fuera de Git para evitar mezclar
entornos.

## Asignar el permiso administrador

Los scripts administrativos usan una cuenta de servicio fuera del repositorio.
Instala primero sus dependencias:

```powershell
cd D:\Expresiones\scripts
npm install
```

Después define las variables y concede el permiso:

```powershell
$env:FIREBASE_PROJECT_ID = 'TU_PROJECT_ID'
$env:GOOGLE_APPLICATION_CREDENTIALS = 'C:\ruta-segura\service-account.json'
node .\set_admin_claim.js administrador@dominio.com
```

Para retirar el acceso:

```powershell
node .\set_admin_claim.js administrador@dominio.com --remove
```

La cuenta debe cerrar sesión y volver a entrar para recibir el token nuevo.

## Capacidad de producción

El botón de calendario del panel abre `availability/public`. Allí se define la
capacidad máxima de lunes a domingo y se pueden agregar fechas especiales con:

- puntos de pedidos ya confirmados;
- cierre del taller;
- capacidad distinta para ese día;
- motivo visible para el equipo.

Este documento guarda únicamente cifras agregadas. No contiene nombres,
teléfonos, direcciones ni códigos de pedidos.

## Métricas comerciales

El botón de actividad consulta los últimos 30 días, con un límite de 1000
eventos para controlar lecturas. Presenta totales y rankings de productos
vistos, agregados y términos que no devolvieron resultados.

La pantalla no reconstruye sesiones ni perfiles de clientes. Los eventos usan
rangos de cantidades y montos, y omiten cualquier dato de coordinación.

## Cargar el catálogo real

El importador valida primero sin escribir:

```powershell
node .\import_catalog_firestore.js
```

Para ejecutar la carga se exige una confirmación con el ID exacto:

```powershell
$env:ALLOW_PRODUCTION_CATALOG_WRITE = $env:FIREBASE_PROJECT_ID
node .\import_catalog_firestore.js --apply
```

El importador fusiona los documentos por ID y no elimina automáticamente los
productos que ya existan en Firestore.

## Ejecutar el panel

```powershell
C:\src\flutter\bin\flutter.bat run -d chrome `
  -t lib\admin_main.dart `
  --dart-define-from-file=firebase_config.json
```

Para compilarlo:

```powershell
C:\src\flutter\bin\flutter.bat build web `
  -t lib\admin_main.dart `
  --dart-define-from-file=firebase_config.json
```

## Seguridad

La URL del panel no funciona como protección. `firestore.rules` exige que el
token autenticado contenga `admin: true` antes de leer productos ocultos o
escribir cualquier cambio. Además valida tipos, límites de precios, stock,
plazos y tamaño de las listas de variantes.

No se deben guardar cuentas de servicio, claves privadas ni contraseñas dentro
de Flutter, Firebase Hosting o este repositorio.
