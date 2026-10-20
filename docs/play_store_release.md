# Preparación de Android y Play Store

> Alcance actual: se entregará un APK directo para el proyecto universitario y
> la versión de producción será la web en Cloudflare Pages. Este documento se
> conserva como referencia por si más adelante se decide publicar en Play Store.

El identificador Android de la aplicación es `pe.expresiones.expresiones`.
La versión se controla desde `pubspec.yaml` con el formato `version: nombre+código`.
Cada publicación en Play Store debe aumentar el código situado después de `+`.

## 1. Crear la clave privada de carga

La clave debe crearse una sola vez y guardarse también en una copia de seguridad
privada. No debe agregarse al repositorio.

En esta PC ya fue creada para Expresiones en:

```text
C:\Users\Marcial\.android\expresiones-upload-key.jks
```

La configuración privada usada por Gradle está en
`android/key.properties`. Ambos archivos deben respaldarse juntos antes de la
primera publicación; la contraseña generada está solamente en ese archivo.
Perder cualquiera de los dos complica futuras actualizaciones de la app.

```powershell
keytool -genkeypair -v -keystore C:\ruta\privada\expresiones-upload-key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias expresiones
```

## 2. Configurar la firma local

1. Copiar `android/key.properties.example` como `android/key.properties`.
2. Reemplazar las contraseñas y la ruta al archivo `.jks`.
3. Mantener ambos archivos fuera de Git. Las reglas actuales de `.gitignore` ya
   excluyen `key.properties`, `*.jks` y `*.keystore`.

Cuando `android/key.properties` existe, Gradle firma el build `release` con esa
clave. Cuando no existe, nunca reutiliza la clave de depuración como si fuera una
firma publicable.

## 3. Generar el archivo para Play Store

```powershell
flutter pub get
flutter analyze
flutter test
flutter build appbundle --release `
  --dart-define-from-file=supabase_config.json
```

El AAB firmado ya fue generado y verificado en:

```text
build/app/outputs/bundle/release/app-release.aab
```

Antes de subirlo se debe comprobar que el AAB esté firmado y completar en Play
Console la ficha, política de privacidad, clasificación de contenido, seguridad
de datos, capturas y prueba interna.

## 4. Ficha propuesta

**Nombre:** `Expresiones`

**Descripción breve:**

```text
Catálogo de materiales y cotizador para enviar tu pedido por WhatsApp.
```

**Descripción completa:**

```text
Encuentra materiales para rosas eternas y manualidades en el catálogo de
Expresiones. Revisa colores, presentaciones, precios y
disponibilidad desde tu celular.

Agrega los productos y cantidades que necesitas, elige recojo en Huancayo o
una agencia de Shalom y genera una cotización ordenada. Al terminar, la
aplicación prepara el mensaje para que tú decidas si deseas enviarlo por
WhatsApp y coordinar el pedido directamente con Expresiones.

La aplicación no procesa pagos. Los precios, el stock, el envío y la fecha se
confirman con Expresiones antes de convertir la cotización en un pedido.
```

Categoría sugerida: `Compras`. La aplicación no contiene anuncios ni exige una
cuenta al público. Falta proporcionar en Play Console el correo de soporte del
propietario, la gráfica destacada de 1024 × 500 y las capturas finales.

La URL de privacidad será:

```text
https://<proyecto>.pages.dev/privacy.html
```

Google exige que la URL esté activa y que la política también sea accesible
desde la aplicación.

## 5. Borrador para Seguridad de los datos

Este borrador describe el build actual; debe revisarse otra vez si se agrega un
SDK o cambia la telemetría antes de enviarlo a Google Play.

| Tema | Declaración preparada |
| --- | --- |
| Datos de contacto y coordinación | Se procesan localmente. La aplicación no los sube a Supabase. El usuario decide si los transfiere a WhatsApp. |
| Actividad en la aplicación | La analítica está desactivada en el MVP. No se envían búsquedas, vistas, productos agregados ni cotizaciones abandonadas. Revisar de nuevo este punto antes de la fase 9. |
| Vinculación con identidad | No existe cuenta pública ni identificador de usuario para clientes. |
| Datos compartidos | Supabase aloja el catálogo y Cloudflare distribuye la web. Confirmar en el formulario el tratamiento de la transferencia iniciada por el usuario hacia WhatsApp. |
| Cifrado | Supabase y Cloudflare Pages usan HTTPS durante la transferencia. |
| Pagos, ubicación y contactos del dispositivo | No se recopilan. La aplicación no procesa pagos ni solicita GPS o libreta de contactos. |
| Eliminación | El usuario puede borrar cotización y datos locales desde la aplicación. No se crean cuentas públicas. |

Play Console exige completar este formulario incluso para aplicaciones sin
datos de usuario. La declaración debe incluir el comportamiento de todos los
SDK usados en el AAB final.

Referencias oficiales:

- [Preparar una aplicación para revisión](https://support.google.com/googleplay/android-developer/answer/9859455)
- [Seguridad de los datos](https://support.google.com/googleplay/android-developer/answer/10787469)

## 6. Lista previa al envío

- Incrementar el código de versión en `pubspec.yaml`.
- Generar y respaldar la clave de carga.
- Crear el AAB firmado y subirlo primero a prueba interna.
- Publicar y verificar la política de privacidad.
- Completar anuncios, acceso, público objetivo, clasificación de contenido y
  seguridad de los datos.
- Subir ícono, gráfica destacada y capturas reales de teléfono.
- Probar catálogo, cotización, exportación y apertura de WhatsApp desde el AAB.

## 7. Generar la web

```powershell
.\scripts\build_web_release.ps1
```

El directorio publicable es `build/web` e incluye catálogo, portal
administrativo y política de privacidad.
