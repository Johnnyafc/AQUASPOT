# Restaura el estado previo a "Venta de Repuesto - Fase B: pantalla de evaluacion de venta".
# Tambien borra los archivos NUEVOS creados en este cambio (no toca los de la fase A).
# Uso (desde la raiz del proyecto aquaspot_postventa):
#   powershell -ExecutionPolicy Bypass -File "Claude outputs/respaldos/2026-10-14_antes_venta_fase_b_evaluacion/RESTAURAR.ps1"
$ErrorActionPreference = 'Stop'
$origen = Split-Path -Parent $MyInvocation.MyCommand.Path
$raiz = (Resolve-Path (Join-Path $origen '..\..\..')).Path
Get-ChildItem -Path $origen -Recurse -File -Filter '*.respaldo' | ForEach-Object {
  $rel = $_.FullName.Substring($origen.Length + 1) -replace '\.respaldo$', ''
  Copy-Item $_.FullName (Join-Path $raiz $rel) -Force
  Write-Host "Restaurado: $rel"
}
$nuevos = @(
  'lib\features\tickets\presentation\pages\evaluacion_venta_repuesto_page.dart'
)
foreach ($n in $nuevos) {
  $p = Join-Path $raiz $n
  if (Test-Path $p) { Remove-Item $p -Force; Write-Host "Borrado (nuevo): $n" }
}
Write-Host "Listo. Vuelva a compilar."
