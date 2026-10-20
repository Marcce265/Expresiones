# Expresiones

Aplicación Flutter para Android y web con catálogo de materiales, cálculo de
precios por volumen y generación de cotizaciones para WhatsApp.

## Funciones principales

- Inicio y catálogo adaptable a celular y computadora.
- Búsqueda por nombre, color, código y etiquetas.
- Variantes, cantidades, precios por volumen y subtotal automático.
- Carrito guardado localmente, sin cuenta para el público.
- Recojo en Huancayo o envío nacional por Shalom.
- Directorio de agencias disponible sin conexión.
- Revisión final, exportación a PDF o Excel y envío voluntario a WhatsApp.
- Catálogo y capacidad pública desde Supabase, con respaldo local cuando no hay
  conexión.
- Panel web `/admin/` separado del APK, protegido por correo, contraseña, TOTP
  y políticas RLS de Supabase.
- Política de privacidad dentro de la app y en `/privacy.html`.

La analítica comercial no forma parte del MVP. Se mantiene desactivada hasta la
fase 9 y no debe habilitarse sin revisar primero la política de privacidad.

## Configuración local

Abre en VS Code la carpeta de este repositorio, no su carpeta padre:

```text
/home/marcee/Expresiones/Expresiones
```

Crea la configuración local a partir del ejemplo:

```bash
cp supabase_config.example.json supabase_config.json
```

Completa únicamente `SUPABASE_URL` y `SUPABASE_PUBLISHABLE_KEY` con los valores
públicos de **Project Settings > API** en Supabase. `supabase_config.json` está
ignorado por Git. Nunca coloques `service_role`, contraseñas ni secretos dentro
de este archivo o de la aplicación Flutter.

## Ejecutar en Fedora

```bash
flutter pub get
flutter emulators --launch Expresiones_API_36
flutter run -d emulator-5554 \
  --dart-define-from-file=supabase_config.json
```

Para la versión web pública:

```bash
flutter run -d chrome \
  --dart-define-from-file=supabase_config.json
```

Para el panel administrativo:

```bash
flutter run -d chrome \
  -t lib/admin_main.dart \
  --dart-define-from-file=supabase_config.json
```

Sin configuración remota, el catálogo público puede usar el respaldo local; el
panel administrativo requiere una conexión válida con Supabase.

## Supabase

La base usa Postgres, Auth, Storage y Row Level Security. El público solo puede
leer el catálogo activo. Las dos cuentas administrativas se crean manualmente y
toda escritura exige una sesión administradora con segundo factor TOTP
(`aal2`). SMS no se usa porque agrega costo y dependencia de un proveedor.

Las migraciones, la carga inicial y la creación segura de administradores están
documentadas en [`docs/SUPABASE.md`](docs/SUPABASE.md). El modelo anterior de
Firestore se conserva únicamente como referencia histórica; no es parte del
flujo nuevo.

## Verificación

```bash
flutter analyze
flutter test
flutter build apk --debug \
  --dart-define-from-file=supabase_config.json
bash scripts/build_web_release.sh
```

El APK se usa para la entrega académica. La versión de producción se publica
como web estática en Cloudflare Pages, sin dominio propio, usando la dirección
gratuita `*.pages.dev`.

## Documentación

- [`docs/SUPABASE.md`](docs/SUPABASE.md): base, seguridad, Storage y carga
  inicial.
- [`docs/web_release.md`](docs/web_release.md): build público + administrador y
  publicación en Cloudflare Pages.
- [`docs/admin_portal.md`](docs/admin_portal.md): cuentas administrativas y
  operación del panel.
- [`docs/play_store_release.md`](docs/play_store_release.md): referencia de
  empaquetado Android; el alcance actual solo requiere APK.
- [`docs/shalom_agencies_report.md`](docs/shalom_agencies_report.md): fuente y
  actualización del directorio de Shalom.

## Archivos heredados de Firebase

`firebase.json`, las reglas de Firestore y los scripts con nombres
`*_firestore*` se mantienen temporalmente para conservar la historia técnica y
comparar la migración. No deben ejecutarse ni desplegarse en el flujo de
producción Supabase + Cloudflare. Consulta
[`docs/legacy_firebase.md`](docs/legacy_firebase.md).
