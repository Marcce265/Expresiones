# Expresiones

Aplicación Flutter para Android y web con catálogo, cálculo automático de
precios por volumen y generación de cotizaciones para WhatsApp.

## Funciones implementadas

- Inicio y catálogo responsive con materiales, ramos y regalos personalizados.
- Búsqueda por nombre, color, código y etiquetas.
- Variantes, cantidades, precios por volumen y subtotal automático.
- Carrito guardado localmente, sin registro de usuario.
- Recojo en Huancayo o envío nacional por Shalom.
- Selector de agencias Shalom con búsqueda, dirección y horarios, cargado sin conexión.
- Fecha solicitada, carga de producción y datos de coordinación.
- Revisión final, copia del mensaje y envío a WhatsApp `+51 956 744 914`.
- Capacidad real por día, carga reservada, cierres y fechas especiales.
- Catálogo Firestore en tiempo real con catálogo local de respaldo.
- Panel web `/admin/` protegido con Firebase Auth y permiso `admin` para
  editar productos, precios, stock, capacidad y revisar analítica.
- Métricas anónimas de búsquedas sin resultado, vistas, productos agregados,
  aperturas de WhatsApp y cotizaciones abandonadas.
- Exportación local de la cotización a PDF y Excel.
- Política de privacidad dentro de la app y en `/privacy.html`.
- Reglas, índices, scripts de importación y datos para Firestore.

## Ejecutar en Fedora

Abre en VS Code la carpeta de este repositorio, no su carpeta padre:

```text
/home/marcee/Expresiones/Expresiones
```

La configuración de VS Code localiza Flutter desde `PATH`, por lo que también
sigue siendo portable a Windows. Para iniciar el teléfono virtual:

```bash
flutter pub get
flutter emulators --launch Expresiones_API_36
flutter run -d emulator-5554 --dart-define-from-file=firebase_config.json
```

Para la versión web, elige **Expresiones Web** en VS Code o ejecuta:

```bash
flutter run -d chrome --dart-define-from-file=firebase_config.json
```

## Firestore local en Fedora

`firebase_config.json` no se publica en Git. La copia local preparada para
Fedora conecta Android y web con Firestore Emulator sin alterar el catálogo ni
los flujos de la aplicación.

Inicia Firestore desde la raíz de este repositorio:

```bash
firebase emulators:start --only firestore --project expresiones-local
```

En otra terminal carga el catálogo completo y verifica las reglas:

```bash
export FIRESTORE_EMULATOR_HOST=127.0.0.1:8080
export GCLOUD_PROJECT=expresiones-local
node scripts/seed_firestore.js
node scripts/verify_firestore_rules.js
```

La interfaz local queda disponible en `http://127.0.0.1:4000`. En Android el
bootstrap usa automáticamente `10.0.2.2`; en web usa `127.0.0.1`.

## Conectar un proyecto real de Firestore

La app funciona ahora con el catálogo local. Para leer desde tu proyecto de
Cloud Firestore:

1. Ejecuta `firebase login` con la cuenta propietaria.
2. Crea un proyecto en Firebase con el plan Spark y habilita Cloud Firestore.
3. Copia `firebase_config.example.json` como `firebase_config.json` y coloca los
   identificadores de la aplicación Android o web.
4. Despliega las reglas y el índice con `firebase deploy --only firestore`.
5. Ejecuta Flutter con el archivo de configuración:

```bash
flutter run -d emulator-5554 --dart-define-from-file=firebase_config.json
```

Si Firestore no está configurado, está vacío o no responde, el catálogo local
se usa automáticamente. Las cotizaciones y los datos personales no se escriben
en Firestore.

## Verificación

```bash
flutter analyze
flutter test
flutter build web
flutter build apk --debug
```

La estructura de datos está explicada en
[`docs/firestore_schema.md`](docs/firestore_schema.md).

La publicación web, el panel y Play Store están documentados en
[`docs/web_release.md`](docs/web_release.md),
[`docs/admin_portal.md`](docs/admin_portal.md) y
[`docs/play_store_release.md`](docs/play_store_release.md).

El listado de agencias Shalom y cómo actualizarlo están documentados en
[`docs/shalom_agencies_report.md`](docs/shalom_agencies_report.md).
