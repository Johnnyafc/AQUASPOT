# Restaura los archivos al estado previo a "Validación simple en Despacho Bodega".
# Los respaldos tienen extensión .dart.respaldo para que Dart/Flutter los
# ignore al compilar; este script los copia de vuelta como .dart.
# Uso (desde la raíz del proyecto aquaspot_postventa):
#   powershell -ExecutionPolicy Bypass -File "Claude outputs/respaldos/2026-10-06_antes_validacion_simple_bodega/RESTAURAR.ps1"
$ErrorActionPreference = 'Stop'
$origen = Split-Path -Parent $MyInvocation.MyCommand.Path
$raiz = (Resolve-Path (Join-Path $origen '..\..\..')).Path
Get-ChildItem -Path (Join-Path $origen 'lib') -Recurse -File -Filter '*.dart.respaldo' | ForEach-Object {
  $rel = $_.FullName.Substring($origen.Length + 1) -replace '\.respaldo$', ''
  Copy-Item $_.FullName (Join-Path $raiz $rel) -Force
  Write-Host "Restaurado: $rel"
}
# Archivo nuevo creado por este cambio (no existía antes):
$nuevo = Join-Path $raiz 'lib\features\tickets\presentation\pages\validacion_simple_despacho_page.dart'
if (Test-Path $nuevo) { Remove-Item $nuevo; Write-Host "Eliminado: validacion_simple_despacho_page.dart" }
Write-Host "Listo. Ejecute 'flutter pub get' si hace falta y vuelva a compilar."
