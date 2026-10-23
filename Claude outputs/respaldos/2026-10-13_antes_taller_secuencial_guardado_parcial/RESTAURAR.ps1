# Restaura el estado previo a "Taller secuencial + guardado parcial de órdenes de retiro".
# Uso (desde la raíz del proyecto aquaspot_postventa):
#   powershell -ExecutionPolicy Bypass -File "Claude outputs/respaldos/2026-10-13_antes_taller_secuencial_guardado_parcial/RESTAURAR.ps1"
$ErrorActionPreference = 'Stop'
$origen = Split-Path -Parent $MyInvocation.MyCommand.Path
$raiz = (Resolve-Path (Join-Path $origen '..\..\..')).Path
Get-ChildItem -Path $origen -Recurse -File -Filter '*.respaldo' | ForEach-Object {
  $rel = $_.FullName.Substring($origen.Length + 1) -replace '\.respaldo$', ''
  Copy-Item $_.FullName (Join-Path $raiz $rel) -Force
  Write-Host "Restaurado: $rel"
}
$nuevo = Join-Path $raiz 'test\taller_secuencial_test.dart'
if (Test-Path $nuevo) { Remove-Item $nuevo; Write-Host "Eliminado: test\taller_secuencial_test.dart" }
Write-Host "Listo. Vuelva a compilar."
