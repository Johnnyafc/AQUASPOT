# Restaura el estado previo a "Tramos en 0 + sección de inconsistencias".
# Uso (desde la raíz del proyecto aquaspot_postventa):
#   powershell -ExecutionPolicy Bypass -File "Claude outputs/respaldos/2026-10-07_antes_inconsistencias/RESTAURAR.ps1"
$ErrorActionPreference = 'Stop'
$origen = Split-Path -Parent $MyInvocation.MyCommand.Path
$raiz = (Resolve-Path (Join-Path $origen '..\..\..')).Path
Get-ChildItem -Path $origen -Recurse -File -Filter '*.respaldo' | ForEach-Object {
  $rel = $_.FullName.Substring($origen.Length + 1) -replace '\.respaldo$', ''
  Copy-Item $_.FullName (Join-Path $raiz $rel) -Force
  Write-Host "Restaurado: $rel"
}
$nuevos = @(
  'lib\features\tickets\domain\services\inconsistencias_trazabilidad_service.dart',
  'test\inconsistencias_trazabilidad_test.dart'
)
foreach ($n in $nuevos) {
  $p = Join-Path $raiz $n
  if (Test-Path $p) { Remove-Item $p; Write-Host "Eliminado: $n" }
}
Write-Host "Listo. Vuelva a compilar."
