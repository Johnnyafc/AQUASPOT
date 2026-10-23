# Restaura el estado previo a "Indicadores de Postventa (botón del Dashboard)".
# Uso (desde la raíz del proyecto aquaspot_postventa):
#   powershell -ExecutionPolicy Bypass -File "Claude outputs/respaldos/2026-10-08_antes_indicadores_postventa/RESTAURAR.ps1"
$ErrorActionPreference = 'Stop'
$origen = Split-Path -Parent $MyInvocation.MyCommand.Path
$raiz = (Resolve-Path (Join-Path $origen '..\..\..')).Path
Get-ChildItem -Path $origen -Recurse -File -Filter '*.respaldo' | ForEach-Object {
  $rel = $_.FullName.Substring($origen.Length + 1) -replace '\.respaldo$', ''
  Copy-Item $_.FullName (Join-Path $raiz $rel) -Force
  Write-Host "Restaurado: $rel"
}
# Archivos nuevos creados por este cambio (no existían antes):
$nuevos = @(
  'lib\features\tickets\domain\services\indicadores_postventa_service.dart',
  'lib\features\tickets\presentation\services\generador_excel_indicadores_postventa.dart',
  'test\indicadores_postventa_test.dart'
)
foreach ($n in $nuevos) {
  $ruta = Join-Path $raiz $n
  if (Test-Path $ruta) { Remove-Item $ruta; Write-Host "Eliminado: $n" }
}
Write-Host "Listo. Vuelva a compilar."
