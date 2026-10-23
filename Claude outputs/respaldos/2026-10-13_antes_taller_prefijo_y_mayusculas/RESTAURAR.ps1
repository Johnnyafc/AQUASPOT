# Restaura el estado previo a "Prefijo TALLER en inicio de trabajo + marca y serie en mayúsculas".
# Uso (desde la raíz del proyecto aquaspot_postventa):
#   powershell -ExecutionPolicy Bypass -File "Claude outputs/respaldos/2026-10-13_antes_taller_prefijo_y_mayusculas/RESTAURAR.ps1"
$ErrorActionPreference = 'Stop'
$origen = Split-Path -Parent $MyInvocation.MyCommand.Path
$raiz = (Resolve-Path (Join-Path $origen '..\..\..')).Path
Get-ChildItem -Path $origen -Recurse -File -Filter '*.respaldo' | ForEach-Object {
  $rel = $_.FullName.Substring($origen.Length + 1) -replace '\.respaldo$', ''
  Copy-Item $_.FullName (Join-Path $raiz $rel) -Force
  Write-Host "Restaurado: $rel"
}
$nuevo = Join-Path $raiz 'test\prefijo_taller_y_mayusculas_test.dart'
if (Test-Path $nuevo) { Remove-Item $nuevo; Write-Host "Eliminado: test\prefijo_taller_y_mayusculas_test.dart" }
Write-Host "Listo. Vuelva a compilar."
