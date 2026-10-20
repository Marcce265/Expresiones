# Panel administrativo de Expresiones

El panel permite administrar el catálogo de Supabase desde una computadora sin
dar permisos de escritura a la aplicación pública. Tiene un punto de entrada
independiente en `lib/admin_main.dart`, se publica en `/admin/` y no se incluye
en el APK académico.

## Funciones del panel

- Inicio y cierre de sesión con correo y contraseña.
- Inscripción y verificación del segundo factor TOTP.
- Listado y búsqueda de familias y variantes.
- Creación y edición de nombres, descripciones, categorías, códigos, orden,
  unidad de venta y días de preparación.
- Edición de precios definitivos y tramos por cantidad.
- Edición de variantes, stock, disponibilidad y estado publicado.
- Carga y reemplazo de imágenes en el bucket `catalog`.
- Publicación, ocultamiento y restauración mediante borrado lógico.
- Edición de capacidad semanal, reservas agregadas, cierres y excepciones por
  fecha.

La analítica comercial se deja para la fase 9. No se muestra ni se recolecta en
el MVP.

## Seguridad aplicada

El acceso necesita tres condiciones simultáneas:

1. una cuenta válida de Supabase Auth;
2. el `user_id` presente en `public.admins`; y
3. una sesión con TOTP verificado en nivel `aal2`.

La ruta `/admin/` puede conocerse públicamente. La seguridad real la aplican las
políticas RLS de Postgres y Storage, no el nombre de la URL ni controles
visuales del panel. La clave publicable nunca permite saltar esas políticas.

No uses SMS: requiere un proveedor externo y puede generar costo. TOTP funciona
con una aplicación autenticadora y es la opción elegida para las dos cuentas.

## Crear los dos administradores

1. En Supabase abre **Authentication > Providers > Email** y desactiva el
   registro público de usuarios.
2. En **Authentication > Users**, crea manualmente dos cuentas separadas: una
   del propietario y otra de la copropietaria.
3. Marca ambos correos como verificados.
4. Copia los UUID de los usuarios.
5. En **SQL Editor**, inserta cada UUID en la lista permitida:

```sql
insert into public.admins (user_id)
values
  ('UUID_DEL_PRIMER_ADMIN'),
  ('UUID_DEL_SEGUNDO_ADMIN')
on conflict (user_id) do nothing;
```

6. Cada persona debe entrar con su propia cuenta y escanear su propio código
   TOTP. No compartan contraseña ni factor.

Las cuentas se crean después de aplicar las migraciones descritas en
[`SUPABASE.md`](SUPABASE.md). No guardes correos, contraseñas, secretos TOTP ni
capturas del QR dentro del repositorio.

## Primer acceso y TOTP

1. Abre `https://<proyecto>.pages.dev/admin/`.
2. Ingresa correo y contraseña. El formulario permite pegar credenciales y usar
   un gestor de contraseñas.
3. En el primer acceso, el panel muestra un QR y una clave de respaldo para
   enrolar TOTP en una aplicación autenticadora.
4. Introduce el código temporal de seis dígitos.
5. Supabase eleva la sesión a `aal2`; recién entonces las políticas permiten
   escribir.

Guarda la cuenta TOTP en un autenticador con copia de seguridad cifrada. Si una
persona pierde el segundo factor, la otra cuenta conserva acceso al negocio,
pero el factor perdido debe recuperarse o restablecerse desde la administración
de Auth de Supabase; nunca se debe desactivar `aal2` como solución rápida.

## Ejecutar en desarrollo

```bash
flutter run -d chrome \
  -t lib/admin_main.dart \
  --dart-define-from-file=supabase_config.json
```

En Windows PowerShell:

```powershell
flutter run -d chrome `
  -t lib/admin_main.dart `
  --dart-define-from-file=supabase_config.json
```

## Compilar para `/admin/`

La forma recomendada es generar los dos sitios juntos:

```bash
bash scripts/build_web_release.sh
```

El comando administrativo equivalente es:

```bash
flutter build web --release \
  -t lib/admin_main.dart \
  --base-href /admin/ \
  --output build/admin-web \
  --dart-define-from-file=supabase_config.json
```

El script copia el resultado a `build/web/admin/`, que luego se publica junto al
catálogo en Cloudflare Pages.

## Imágenes del catálogo

El bucket `catalog` es público solo para lectura. Las políticas de Storage
permiten subir, reemplazar o retirar archivos únicamente a administradores con
`aal2`. El panel debe rechazar formatos y tamaños no admitidos antes de subir,
pero la política del servidor sigue siendo obligatoria.

Las imágenes antiguas que aún viven en `assets/` sirven como respaldo local.
Una carga desde el panel no modifica esos archivos del repositorio; guarda el
nuevo archivo en Storage y actualiza su ruta en la familia o variante.

## Operación segura

- Usa siempre dos cuentas separadas.
- Mantén contraseñas únicas en un gestor de contraseñas.
- Cierra sesión en computadoras compartidas.
- No copies `service_role` a Flutter ni a Cloudflare.
- Antes de cambiar muchos precios, exporta o conserva el seed versionado.
- Oculta productos con `active = false`; evita borrados físicos salvo una
  limpieza deliberada y respaldada.
- Revisa `updated_at` y `updated_by` cuando necesites auditar un cambio.
