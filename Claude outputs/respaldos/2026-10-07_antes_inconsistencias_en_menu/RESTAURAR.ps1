# Restaura el estado previo a "Inconsistencias en el menú principal".
# Uso (desde la raíz del proyecto aquaspot_postventa):
#   powershell -ExecutionPolicy Bypass -File "Claude outputs/respaldos/2026-10-07_antes_inconsistencias_en_menu/RESTAURAR.ps1"
$ErrorActionPreference = 'Stop'
$origen = Split-Path -Parent $MyInvocation.MyCommand.Path
$raiz = (Resolve-Path (Join-Path $origen '..\..\..')).Path
Get-ChildItem -Path $origen -Recurse -File -Filter '*.respaldo' | ForEach-Object {
  $rel = $_.FullName.Substring($origen.Length + 1) -replace '\.respaldo$', ''
  Copy-Item $_.FullName (Join-Path $raiz $rel) -Force
  Write-Host "Restaurado: $rel"
}
# Archivo nuevo creado por este cambio (no existía antes):
$nuevo = Join-Path $raiz 'lib\features\tickets\presentation\pages\inconsistencias_trazabilidad_page.dart'
if (Test-Path $nuevo) { Remove-Item $nuevo; Write-Host "Eliminado: inconsistencias_trazabilidad_page.dart" }
Write-Host "Listo. Vuelva a compilar."
