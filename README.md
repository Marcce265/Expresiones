# Expresiones

Aplicación Flutter para Android y web con catálogo, cálculo automático de
precios por volumen y generación de cotizaciones para WhatsApp.

## Funciones implementadas

- Inicio y catálogo responsive con materiales, ramos y regalos personalizados.
- Búsqueda por nombre, color, código y etiquetas.
- Variantes, cantidades, precios por volumen y subtotal automático.
- Carrito guardado localmente, sin registro de usuario.
- Recojo en Huancayo o envío nacional por Shalom.
- Fecha solicitada, carga de producción y datos de coordinación.
- Revisión final, copia del mensaje y envío a WhatsApp `+51 956 744 914`.
- Cloud Firestore de solo lectura con catálogo local de respaldo.
- Reglas, índices, esquema y datos para el emulador de Firestore.

## Ejecutar en el celular virtual

El proyecto ya incluye las extensiones de Dart y Flutter para VS Code y apunta
al SDK ubicado en `C:\src\flutter`.

1. Abre `D:\Expresiones` en VS Code.
2. Mantén abierto el Pixel virtual de Android Studio.
3. Ve a **Ejecutar y depurar**.
4. Elige **Expresiones Android** y presiona **F5**.

También puedes usar la terminal:

```powershell
C:\src\flutter\bin\flutter.bat run -d emulator-5554
```

Para la versión web, elige **Expresiones Web** en VS Code o ejecuta:

```powershell
C:\src\flutter\bin\flutter.bat run -d edge
```

## Conectar un proyecto real de Firestore

La app funciona ahora con el catálogo local. Para leer desde tu proyecto de
Cloud Firestore:

1. Ejecuta `firebase login` con la cuenta propietaria.
2. Crea un proyecto en Firebase con el plan Spark y habilita Cloud Firestore.
3. Copia `firebase_config.example.json` como `firebase_config.json` y coloca los
   identificadores de la aplicación Android o web.
4. Despliega las reglas y el índice con `firebase deploy --only firestore`.
5. Ejecuta Flutter con el archivo de configuración:

```powershell
C:\src\flutter\bin\flutter.bat run -d emulator-5554 --dart-define-from-file=firebase_config.json
```

Si Firestore no está configurado, está vacío o no responde, el catálogo local
se usa automáticamente. Las cotizaciones y los datos personales no se escriben
en Firestore.

## Verificación

```powershell
C:\src\flutter\bin\flutter.bat analyze
C:\src\flutter\bin\flutter.bat test
C:\src\flutter\bin\flutter.bat build web
C:\src\flutter\bin\flutter.bat build apk --debug
```

La estructura de datos está explicada en
[`docs/firestore_schema.md`](docs/firestore_schema.md).
