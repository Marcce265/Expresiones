# Publicación web en Cloudflare Pages

La entrega de producción es un sitio estático con dos builds Flutter:

- `/`: catálogo y cotizador público;
- `/admin/`: panel administrativo independiente; y
- `/privacy.html`: política de privacidad.

No se necesita comprar un dominio. Cloudflare Pages entrega una dirección HTTPS
del tipo `https://expresiones.pages.dev` sin costo en el plan Free.

## 1. Preparar la configuración

```bash
cp supabase_config.example.json supabase_config.json
```

Completa los dos valores públicos del proyecto Supabase:

```json
{
  "SUPABASE_URL": "https://tu-proyecto.supabase.co",
  "SUPABASE_PUBLISHABLE_KEY": "sb_publishable_reemplazar"
}
```

`supabase_config.json` no se publica en Git. La clave publicable sí termina
incluida en el JavaScript que recibe el navegador; esto es correcto. La
protección real está en las políticas RLS. Nunca uses `service_role` en Flutter,
Cloudflare Pages ni en un archivo del repositorio.

## 2. Generar ambos builds

En Fedora:

```bash
bash scripts/build_web_release.sh
```

En Windows PowerShell:

```powershell
.\scripts\build_web_release.ps1
```

También se puede indicar otra ubicación de configuración:

```bash
bash scripts/build_web_release.sh /ruta/segura/supabase_config.json
```

```powershell
.\scripts\build_web_release.ps1 `
  -SupabaseConfig C:\ruta\segura\supabase_config.json
```

Los scripts ejecutan, en esencia:

```bash
flutter build web --release \
  --dart-define-from-file=supabase_config.json

flutter build web --release \
  -t lib/admin_main.dart \
  --base-href /admin/ \
  --output build/admin-web \
  --dart-define-from-file=supabase_config.json
```

Después colocan el segundo build en `build/web/admin/`. El único directorio que
se publica es `build/web`.

El script exige una configuración válida para impedir que, por accidente, se
publique como producción una compilación conectada solo al catálogo local. La
telemetría permanece desactivada: no se añade `ENABLE_TELEMETRY` al build.

## 3. Rutas para Cloudflare Pages

`web/_redirects` y `web/_headers` se copian al resultado automáticamente.
`/admin` redirige a `/admin/` para que el `base-href` del panel resuelva sus
archivos correctamente.

No se debe añadir la regla `/* /index.html 200`. En Cloudflare, las reglas de
`_redirects` se aplican incluso si existe un archivo y ese comodín interceptaría
`main.dart.js`, imágenes, fuentes y CanvasKit. Si no existe un `404.html` en la
raíz, Pages ya activa su comportamiento SPA para las rutas que no coinciden con
un archivo.

## 4. Publicar con Direct Upload

Para este proyecto pequeño, Direct Upload evita configurar Flutter dentro de
los servidores de build de Cloudflare. Primero compila localmente y luego sube
solo los archivos ya generados.

1. Crea una cuenta gratuita en Cloudflare.
2. Instala Node.js y autentica Wrangler:

```bash
npx wrangler login
```

3. Crea el proyecto una sola vez:

```bash
npx wrangler pages project create expresiones
```

4. Publica el resultado:

```bash
npx wrangler pages deploy build/web --project-name=expresiones
```

Wrangler mostrará la URL final `*.pages.dev`. Si el nombre ya está ocupado,
Cloudflare asignará otra dirección disponible. No agregues un dominio propio.

También existe carga por arrastrar y soltar en el panel de Cloudflare, pero
Wrangler admite más archivos y resulta más repetible para una aplicación
Flutter. Al crear un proyecto mediante Direct Upload se elige ese flujo para el
proyecto; si en el futuro se quiere integración automática con Git, conviene
crear otro proyecto de Pages.

## 5. Límites y costo cero

Comprobado el 20 de octubre de 2026, la documentación del plan Free de Pages
indica, entre otros límites, 20 000 archivos por sitio, 25 MiB por archivo y 500
builds mensuales. Direct Upload con Wrangler admite hasta 20 000 archivos; la
carga por arrastrar y soltar admite 1 000. Antes de una entrega definitiva,
vuelve a revisar las páginas oficiales porque las condiciones pueden cambiar:

- [Límites de Cloudflare Pages](https://developers.cloudflare.com/pages/platform/limits/)
- [Direct Upload](https://developers.cloudflare.com/pages/get-started/direct-upload/)
- [Enrutamiento SPA de Pages](https://developers.cloudflare.com/pages/configuration/serving-pages/)

Cloudflare Pages solo aloja archivos estáticos; la base, la autenticación y las
imágenes dinámicas permanecen en Supabase Free. No se habilitan Pages Functions,
Workers, R2, SMS, dominio personalizado ni servicios pagados.

Supabase Free también tiene límites y puede pausar un proyecto inactivo. Revisa
[los precios vigentes de Supabase](https://supabase.com/pricing) y usa el panel
de consumo antes de publicar campañas con mucho tráfico.

## 6. Configuración posterior en Supabase

Cuando Cloudflare entregue la URL final:

1. abre **Authentication > URL Configuration** en Supabase;
2. establece como Site URL la dirección `https://<proyecto>.pages.dev`;
3. agrega `https://<proyecto>.pages.dev/admin/**` a Redirect URLs; y
4. confirma que el registro público esté desactivado.

La ruta `/admin/` no se enlaza desde el catálogo, pero ocultarla no es una medida
de seguridad. Supabase RLS exige que la cuenta figure en `admins` y que la sesión
haya completado TOTP con nivel `aal2` antes de cualquier escritura.

## 7. Comprobación antes y después de publicar

```bash
flutter analyze
flutter test
find build/web -type f -size +25M -print
```

Luego verifica en celular y computadora:

- `/` carga catálogo, imágenes, búsqueda y carrito;
- una recarga del sitio no produce 404;
- `/admin` redirige a `/admin/`;
- el panel permite iniciar sesión y exige TOTP;
- una cuenta pública no puede escribir directamente en Supabase;
- `/privacy.html` es accesible;
- PDF, Excel y WhatsApp funcionan; y
- no hay claves `service_role`, contraseñas ni archivos de configuración privada
  dentro de `build/web`.
