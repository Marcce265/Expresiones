[CmdletBinding()]
param(
  [string]$SupabaseConfig = ""
)

$ErrorActionPreference = "Stop"

$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$flutter = if ($env:FLUTTER_ROOT) {
  Join-Path $env:FLUTTER_ROOT "bin\flutter.bat"
} else {
  (Get-Command flutter -ErrorAction Stop).Source
}

if (-not $SupabaseConfig) {
  $SupabaseConfig = Join-Path $projectRoot "supabase_config.json"
} elseif (-not [IO.Path]::IsPathRooted($SupabaseConfig)) {
  $SupabaseConfig = Join-Path $projectRoot $SupabaseConfig
}

$SupabaseConfig = [IO.Path]::GetFullPath($SupabaseConfig)
if (-not (Test-Path -LiteralPath $SupabaseConfig -PathType Leaf)) {
  throw "No existe $SupabaseConfig. Copia supabase_config.example.json como supabase_config.json y completa solo la URL y la clave pública."
}

$config = Get-Content -LiteralPath $SupabaseConfig -Raw | ConvertFrom-Json
if (-not $config.SUPABASE_URL -or -not $config.SUPABASE_PUBLISHABLE_KEY) {
  throw "La configuración debe incluir SUPABASE_URL y SUPABASE_PUBLISHABLE_KEY."
}

$defineArgs = @("--dart-define-from-file=$SupabaseConfig")
$publicOutput = Join-Path $projectRoot "build\web"
$adminOutput = Join-Path $projectRoot "build\admin-web"
$adminDestination = Join-Path $publicOutput "admin"

Push-Location $projectRoot
try {
  & $flutter pub get
  if ($LASTEXITCODE -ne 0) { throw "flutter pub get falló." }

  & $flutter build web --release --no-pub @defineArgs
  if ($LASTEXITCODE -ne 0) { throw "Falló el build público." }

  & $flutter build web --release --no-pub --no-tree-shake-icons --target lib/admin_main.dart --base-href /admin/ --output $adminOutput @defineArgs
  if ($LASTEXITCODE -ne 0) { throw "Falló el build administrativo." }

  # Flutter puede reutilizar la caché del primer build y omitir en la segunda
  # salida archivos compartidos que no cambiaron. El panel usa las mismas
  # fuentes, iconos y recursos declarados en pubspec, así que completamos su
  # salida con los archivos ya generados y verificados del build público.
  $adminAssets = Join-Path $adminOutput "assets"
  $adminMaterialFont = Join-Path $adminAssets "fonts\MaterialIcons-Regular.otf"
  $adminMaterialBackup = Join-Path $adminOutput ".admin-material-icons.otf"
  if (Test-Path -LiteralPath $adminMaterialFont) {
    Copy-Item -LiteralPath $adminMaterialFont -Destination $adminMaterialBackup -Force
  }
  New-Item -ItemType Directory -Force -Path $adminAssets | Out-Null
  Copy-Item -Path (Join-Path $publicOutput "assets\*") -Destination $adminAssets -Recurse -Force
  if (Test-Path -LiteralPath $adminMaterialBackup) {
    New-Item -ItemType Directory -Force -Path (Split-Path $adminMaterialFont) | Out-Null
    Copy-Item -LiteralPath $adminMaterialBackup -Destination $adminMaterialFont -Force
    Remove-Item -LiteralPath $adminMaterialBackup -Force
  }
  foreach ($shellFile in @("manifest.json", "favicon.png")) {
    $source = Join-Path $publicOutput $shellFile
    if (Test-Path -LiteralPath $source) {
      Copy-Item -LiteralPath $source -Destination (Join-Path $adminOutput $shellFile) -Force
    }
  }
  $publicIcons = Join-Path $publicOutput "icons"
  $adminIcons = Join-Path $adminOutput "icons"
  if (Test-Path -LiteralPath $publicIcons) {
    if (Test-Path -LiteralPath $adminIcons) {
      Remove-Item -LiteralPath $adminIcons -Recurse -Force
    }
    Copy-Item -LiteralPath $publicIcons -Destination $adminIcons -Recurse
  }

  $resolvedDestination = [IO.Path]::GetFullPath($adminDestination)
  $expectedDestination = [IO.Path]::GetFullPath((Join-Path $projectRoot "build\web\admin"))
  if ($resolvedDestination -ne $expectedDestination) {
    throw "Ruta de salida no válida: $resolvedDestination"
  }
  if (Test-Path -LiteralPath $resolvedDestination) {
    Remove-Item -LiteralPath $resolvedDestination -Recurse -Force
  }
  Copy-Item -LiteralPath $adminOutput -Destination $resolvedDestination -Recurse

  Copy-Item -LiteralPath (Join-Path $projectRoot "web\_redirects") -Destination (Join-Path $publicOutput "_redirects") -Force
  Copy-Item -LiteralPath (Join-Path $projectRoot "web\_headers") -Destination (Join-Path $publicOutput "_headers") -Force

  Write-Host "Build para Cloudflare Pages listo: $publicOutput"
  Write-Host "Catálogo: /"
  Write-Host "Administración: /admin/"
  Write-Host "Privacidad: /privacy.html"
} finally {
  Pop-Location
}
