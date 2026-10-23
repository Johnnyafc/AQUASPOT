# Restaura los archivos al estado previo a "Trazabilidad por proceso + notificaciones a Bodega".
# Los respaldos tienen extensión .respaldo para que Dart/TypeScript los ignoren.
# Uso (desde la raíz del proyecto aquaspot_postventa):
#   powershell -ExecutionPolicy Bypass -File "Claude outputs/respaldos/2026-10-06_antes_trazabilidad_por_proceso/RESTAURAR.ps1"
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
  'lib\core\enum\proceso_auditoria.dart',
  'lib\features\tickets\domain\services\tiempos_por_proceso_service.dart',
  'test\tiempos_por_proceso_test.dart',
  'test\auditoria_etiquetada_test.dart'
)
foreach ($n in $nuevos) {
  $p = Join-Path $raiz $n
  if (Test-Path $p) { Remove-Item $p; Write-Host "Eliminado: $n" }
}
Write-Host "Listo. Vuelva a compilar (y a desplegar functions si ya las había desplegado)."
