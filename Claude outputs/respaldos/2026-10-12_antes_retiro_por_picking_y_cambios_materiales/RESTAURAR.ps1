# Restaura el estado previo a "Retiro por picking, anulación de órdenes y registro de cambios de materiales".
# Uso (desde la raíz del proyecto aquaspot_postventa):
#   powershell -ExecutionPolicy Bypass -File "Claude outputs/respaldos/2026-10-12_antes_retiro_por_picking_y_cambios_materiales/RESTAURAR.ps1"
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
  'lib\features\tickets\domain\entities\cambio_material_entity.dart',
  'lib\features\tickets\domain\services\retiro_picking_service.dart',
  'test\retiro_picking_test.dart',
  'lib\features\tickets\presentation\widgets\cambios_materiales_widget.dart'
)
foreach ($n in $nuevos) {
  $ruta = Join-Path $raiz $n
  if (Test-Path $ruta) { Remove-Item $ruta; Write-Host "Eliminado: $n" }
}
Write-Host "Listo. Vuelva a compilar (y 'npm run build' en functions)."
