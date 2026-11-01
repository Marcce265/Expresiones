# Guía de instalación — Expresiones

## 1. Entrega disponible

| Dato | Valor |
| --- | --- |
| Aplicación | Expresiones |
| Versión | 1.0.0 (código 1) |
| Paquete Android | `pe.expresiones.expresiones` |
| APK comercial | [`release/Expresiones-1.0.0.apk`](release/Expresiones-1.0.0.apk) |
| Tamaño comercial | 63.72 MB |
| APK académico | [`release/Expresiones-Demo-Universidad-1.0.0.apk`](release/Expresiones-Demo-Universidad-1.0.0.apk) |
| Tamaño académico | 64.05 MB |
| Android mínimo | Android 7.0 (API 24) |
| SHA-256 comercial | `D70F9F38B0BA2926F386266B6453AA38D17C5234580AF20F18B94349601DD70E` |
| SHA-256 académico | `B6865115B8324EE77F1E78C0C9C745488B9BBDDCCDD5A062A6537A50B948D3F7` |

El APK está firmado como versión de lanzamiento. La firma fue verificada con
APK Signature Scheme v2.

## 2. ¿Qué necesita instalar el profesor?

Para evaluar todo el flujo universitario, incluido el pago simulado, el
profesor debe instalar **`Expresiones-Demo-Universidad-1.0.0.apk`**. Para usar
la aplicación comercial se instala **`Expresiones-1.0.0.apk`**, que oculta el
pago de demostración. No necesita instalar:

- Flutter ni Dart.
- Android Studio ni Java.
- Supabase, PostgreSQL o una base de datos local.
- Cloudflare ni un servidor local.
- Crear una cuenta o iniciar sesión para usar el catálogo y el carrito.

Requisitos del celular:

- Android 7.0 o una versión posterior.
- Aproximadamente 100 MB libres para descargar e instalar.
- Conexión a Internet para cargar el catálogo, imágenes, agencias y mapas.
- WhatsApp es opcional y solo se utiliza para probar el envío voluntario de la
  cotización.

La aplicación únicamente declara el permiso de **Internet**. No solicita GPS,
cámara, contactos ni acceso general al almacenamiento.

## 3. Instalación en Android

1. Copiar `Expresiones-1.0.0.apk` al celular mediante USB, Drive, correo u otro
   medio.
2. Abrir el archivo desde **Archivos** o **Descargas**.
3. Si Android muestra el aviso *No se permiten aplicaciones de esta fuente*,
   pulsar **Configuración** y activar temporalmente **Permitir desde esta
   fuente** para la aplicación desde la que se abrió el APK.
4. Regresar a la instalación y pulsar **Instalar**.
5. Al finalizar, pulsar **Abrir**.
6. Opcionalmente, desactivar otra vez **Permitir desde esta fuente**.

Google Play Protect puede analizar el archivo porque la instalación se realiza
fuera de Play Store. No es necesario desactivar Play Protect.

## 4. Prueba rápida sugerida

1. Abrir **Expresiones** y comprobar que aparezca la pantalla de inicio.
2. Entrar en **Catálogo** y abrir un material.
3. Elegir una variante, indicar una cantidad y agregarla al carrito.
4. Entrar en **Carrito** y completar los datos de coordinación.
5. Elegir recojo en Huancayo o envío por Shalom.
6. Comprobar que recojo en Huancayo solicite obligatoriamente nombre, teléfono,
   fecha y un horario de atención disponible.
7. Comprobar que Shalom solicite obligatoriamente nombre completo, teléfono,
   DNI, agencia y fecha. No debe solicitar fecha de nacimiento ni mostrar un
   selector de hora. Junto al DNI se informa que los datos serán utilizados
   para entregar el envío y que el documento debe pertenecer a una persona
   mayor de edad.
8. Revisar la cotización. En el APK académico, continuar al pago de demostración y
   confirmar que se genere el comprobante simulado. En el APK comercial se
   continúa directamente por WhatsApp.
9. Probar la exportación a PDF o Excel y, opcionalmente, la apertura de
   WhatsApp.

El pago es una **simulación académica**: no solicita una tarjeta ni realiza
cobros reales.

## 5. Sitios web relacionados

- Catálogo público: <https://expresiones.pages.dev/>
- Panel administrativo: <https://expresiones.pages.dev/admin/>
- Política de privacidad: <https://expresiones.pages.dev/privacy.html>

El catálogo público no requiere cuenta. El panel administrativo sí requiere
una cuenta autorizada, contraseña y verificación TOTP; sus credenciales no se
incluyen en esta guía.

## 6. Solución de problemas

### Android muestra “Aplicación no instalada”

- Comprobar que exista espacio libre suficiente.
- Si ya hay otra compilación de Expresiones firmada con una clave diferente,
  desinstalarla y volver a instalar este APK. Desinstalar elimina el carrito y
  otros datos guardados localmente.
- Descargar o copiar nuevamente el APK si el archivo quedó incompleto.

### Android muestra “Error al analizar el paquete”

Verificar que el dispositivo tenga Android 7.0 o posterior y que el APK conserve
la extensión `.apk`.

### No aparecen productos o imágenes

Comprobar la conexión a Internet y volver a abrir la aplicación. No se necesita
instalar Supabase: la aplicación se conecta al servicio remoto mediante HTTPS.

### No se abre WhatsApp

WhatsApp es opcional. Instalarlo o utilizar el catálogo y las exportaciones sin
esa función.

## 7. Compilar desde el código fuente

Esta sección es únicamente para un desarrollador. No es necesaria para instalar
el APK entregado.

### Herramientas

- Flutter estable 3.47.7, que incluye Dart 3.13.5.
- Android Studio con Android SDK Platform 36 y Build Tools 36.
- JDK compatible con Gradle; el proyecto compila código Java/Kotlin con nivel 17.
- Git, si el proyecto se obtiene desde un repositorio.

### Configuración pública de Supabase

Desde la raíz del proyecto en PowerShell:

```powershell
Copy-Item supabase_config.example.json supabase_config.json
```

Completar únicamente `SUPABASE_URL` y `SUPABASE_PUBLISHABLE_KEY` en
`supabase_config.json`. Nunca colocar allí `service_role`, contraseñas ni la
clave privada de firma. El archivo está excluido de Git.

### Verificación y compilación

```powershell
flutter doctor -v
flutter pub get
flutter analyze
flutter test
flutter build apk --release --dart-define-from-file=supabase_config.json
flutter build apk --release --dart-define-from-file=supabase_config.json --dart-define=ENABLE_DEMO_PAYMENT=true
```

El primer comando genera la aplicación comercial. El segundo genera la versión
académica con el pago simulado visible. Ambos APK usan el mismo identificador de
paquete, por lo que no se instalan simultáneamente como aplicaciones separadas.

El resultado se genera en:

```text
build\app\outputs\flutter-apk\app-release.apk
```

Para producir actualizaciones oficiales también se necesita la clave privada de
firma y `android/key.properties`. Estos archivos son secretos, no forman parte
del repositorio y **no son necesarios para instalar el APK ya entregado**.

