[CmdletBinding()]
param(
  [string]$FirebaseConfig = ""
)

$ErrorActionPreference = "Stop"

$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$flutter = if ($env:FLUTTER_ROOT) {
  Join-Path $env:FLUTTER_ROOT "bin\flutter.bat"
} else {
  "C:\src\flutter\bin\flutter.bat"
}

if (-not (Test-Path -LiteralPath $flutter)) {
  $flutter = (Get-Command flutter -ErrorAction Stop).Source
}

if (-not $FirebaseConfig) {
  $defaultConfig = Join-Path $projectRoot "firebase_config.json"
  if (Test-Path -LiteralPath $defaultConfig) {
    $FirebaseConfig = $defaultConfig
  }
} elseif (-not [IO.Path]::IsPathRooted($FirebaseConfig)) {
  $FirebaseConfig = Join-Path $projectRoot $FirebaseConfig
}

$defineArgs = @("--dart-define=ENABLE_TELEMETRY=true")
if ($FirebaseConfig) {
  $FirebaseConfig = [IO.Path]::GetFullPath($FirebaseConfig)
  if (-not (Test-Path -LiteralPath $FirebaseConfig)) {
    throw "No existe el archivo de configuración: $FirebaseConfig"
  }
  $defineArgs += "--dart-define-from-file=$FirebaseConfig"
} else {
  Write-Warning "No existe firebase_config.json. El build usará el catálogo local y el panel mostrará la pantalla de configuración."
}

$publicOutput = Join-Path $projectRoot "build\web"
$adminOutput = Join-Path $projectRoot "build\admin-web"
$adminDestination = Join-Path $publicOutput "admin"

Push-Location $projectRoot
try {
  & $flutter pub get
  if ($LASTEXITCODE -ne 0) { throw "flutter pub get falló." }

  & $flutter build web --release --no-pub @defineArgs
  if ($LASTEXITCODE -ne 0) { throw "Falló el build público." }

  & $flutter build web --release --no-pub --target lib/admin_main.dart --base-href /admin/ --output $adminOutput @defineArgs
  if ($LASTEXITCODE -ne 0) { throw "Falló el build administrativo." }

  if (Test-Path -LiteralPath $adminDestination) {
    $resolvedDestination = [IO.Path]::GetFullPath($adminDestination)
    if (-not $resolvedDestination.StartsWith("$projectRoot\", [StringComparison]::OrdinalIgnoreCase)) {
      throw "Ruta de salida no válida: $resolvedDestination"
    }
    Remove-Item -LiteralPath $resolvedDestination -Recurse -Force
  }

  Copy-Item -LiteralPath $adminOutput -Destination $adminDestination -Recurse
  Write-Host "Build listo: $publicOutput"
  Write-Host "Catálogo: /"
  Write-Host "Administración: /admin/"
  Write-Host "Privacidad: /privacy.html"
} finally {
  Pop-Location
}
