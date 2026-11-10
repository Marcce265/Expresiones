#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
project_root="$(cd -- "$script_dir/.." && pwd)"
config_path="${1:-$project_root/supabase_config.json}"
flutter_bin="${FLUTTER_BIN:-flutter}"

if [[ "$config_path" != /* ]]; then
  config_path="$project_root/$config_path"
fi

if [[ ! -f "$config_path" ]]; then
  echo "No existe $config_path." >&2
  echo "Copia supabase_config.example.json como supabase_config.json y completa solo la URL y la clave pública." >&2
  exit 1
fi

for required_key in SUPABASE_URL SUPABASE_PUBLISHABLE_KEY; do
  if ! grep -q "\"$required_key\"" "$config_path"; then
    echo "Falta $required_key en $config_path." >&2
    exit 1
  fi
done

public_output="$project_root/build/web"
admin_output="$project_root/build/admin-web"
admin_destination="$public_output/admin"

case "$admin_destination" in
  "$project_root/build/web/admin") ;;
  *)
    echo "Ruta de salida no válida: $admin_destination" >&2
    exit 1
    ;;
esac

cd "$project_root"
"$flutter_bin" pub get
"$flutter_bin" build web --release --no-pub \
  --dart-define-from-file="$config_path"
"$flutter_bin" build web --release --no-pub \
  --no-tree-shake-icons \
  --target lib/admin_main.dart \
  --base-href /admin/ \
  --output "$admin_output" \
  --dart-define-from-file="$config_path"

# Flutter puede reutilizar la caché del primer build y omitir recursos comunes
# en la segunda salida. Ambos sitios comparten las fuentes, iconos y assets
# declarados en pubspec, por lo que completamos el build administrativo con la
# salida pública ya generada.
admin_material_font="$admin_output/assets/fonts/MaterialIcons-Regular.otf"
admin_material_backup="$admin_output/.admin-material-icons.otf"
if [[ -f "$admin_material_font" ]]; then
  cp -- "$admin_material_font" "$admin_material_backup"
fi
mkdir -p -- "$admin_output/assets"
cp -R -- "$public_output/assets/." "$admin_output/assets/"
if [[ -f "$admin_material_backup" ]]; then
  mkdir -p -- "$(dirname -- "$admin_material_font")"
  cp -- "$admin_material_backup" "$admin_material_font"
  rm -- "$admin_material_backup"
fi
for shell_file in manifest.json favicon.png; do
  if [[ -f "$public_output/$shell_file" ]]; then
    cp -- "$public_output/$shell_file" "$admin_output/$shell_file"
  fi
done
if [[ -d "$public_output/icons" ]]; then
  rm -rf -- "$admin_output/icons"
  cp -R -- "$public_output/icons" "$admin_output/icons"
fi

rm -rf -- "$admin_destination"
cp -R -- "$admin_output" "$admin_destination"

# Cache-busting basado en el contenido del bundle. Si main.dart.js no cambia,
# la URL se mantiene y los navegadores siguen usando la copia cacheada; así un
# deploy de headers, documentación o estilos no invalida 1.3 MB de JavaScript.
hash_file() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}' | cut -c1-12
  else
    shasum -a 256 "$1" | awk '{print $1}' | cut -c1-12
  fi
}

if [[ ! -f "$public_output/main.dart.js" || ! -f "$admin_destination/main.dart.js" ]]; then
  echo "No se encontró main.dart.js en la salida del build." >&2
  exit 1
fi

public_version="$(hash_file "$public_output/main.dart.js")"
admin_version="$(hash_file "$admin_destination/main.dart.js")"

if [[ -f "$public_output/index.html" ]]; then
  sed -i "s/flutter_bootstrap\.js/flutter_bootstrap.js?v=$public_version/g" "$public_output/index.html"
fi
if [[ -f "$admin_destination/index.html" ]]; then
  sed -i "s/flutter_bootstrap\.js/flutter_bootstrap.js?v=$admin_version/g" "$admin_destination/index.html"
fi
if [[ -f "$public_output/flutter_bootstrap.js" ]]; then
  sed -i "s/\"main\.dart\.js\"/\"main.dart.js?v=$public_version\"/g" "$public_output/flutter_bootstrap.js"
fi
if [[ -f "$admin_destination/flutter_bootstrap.js" ]]; then
  sed -i "s/\"main\.dart\.js\"/\"main.dart.js?v=$admin_version\"/g" "$admin_destination/flutter_bootstrap.js"
fi

cp -- "$project_root/web/_redirects" "$public_output/_redirects"
cp -- "$project_root/web/_headers" "$public_output/_headers"

echo "Build para Cloudflare Pages listo: $public_output"
echo "Catálogo: /"
echo "Administración: /admin/"
echo "Privacidad: /privacy.html"
