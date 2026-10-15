# Publicación web

La aplicación web se genera como sitio estático y `firebase.json` ya contiene la
configuración de Firebase Hosting. La reescritura a `index.html` permite abrir o
recargar las rutas internas sin recibir un error 404.

## Preparar el build público y administrativo

```powershell
.\scripts\build_web_release.ps1
```

Si la configuración real está en otra ruta:

```powershell
.\scripts\build_web_release.ps1 -FirebaseConfig C:\ruta\firebase_config.json
```

El contenido publicable queda unido en `build/web`:

- `/`: catálogo y cotizador.
- `/admin/`: portal administrativo.
- `/privacy.html`: política de privacidad para la web y Play Store.

Sin `firebase_config.json` el comando también permite comprobar la compilación,
pero usa el catálogo local y el panel muestra el aviso de configuración. No se
debe publicar ese build como producción.

## Asociar el proyecto real

La selección del proyecto y el inicio de sesión se realizan una sola vez en el
equipo del propietario:

```powershell
firebase login
firebase use --add
```

El alias seleccionado se guarda en `.firebaserc`. No se debe inventar un ID de
proyecto porque ese valor debe coincidir con el proyecto real de Expresiones.

## Publicar

```powershell
firebase deploy --only hosting
```

Para publicar también reglas e índices de Firestore:

```powershell
firebase deploy --only hosting,firestore:rules,firestore:indexes
```

Después del despliegue se debe comprobar la URL de Hosting en un celular y una
computadora, `/admin/`, `/privacy.html`, el enlace a WhatsApp y la instalación
como aplicación web.
