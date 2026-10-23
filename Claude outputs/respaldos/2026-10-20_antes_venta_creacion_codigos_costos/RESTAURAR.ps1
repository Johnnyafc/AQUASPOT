# Restaura el estado previo a "Venta de Repuesto: ficha de creacion de codigo, aceptacion del cliente y creacion de codigos en Costos".
# Tambien borra los archivos NUEVOS creados en este cambio.
# Uso (desde la raiz del proyecto aquaspot_postventa):
#   powershell -ExecutionPolicy Bypass -File "Claude outputs/respaldos/2026-10-20_antes_venta_creacion_codigos_costos/RESTAURAR.ps1"
# Si ya desplegaste Cloud Functions con este cambio, vuelve a desplegarlas despues de restaurar.
$ErrorActionPreference = 'Stop'
$origen = Split-Path -Parent $MyInvocation.MyCommand.Path
$raiz = (Resolve-Path (Join-Path $origen '..\..\..')).Path
Get-ChildItem -Path $origen -Recurse -File -Filter '*.respaldo' | ForEach-Object {
  $rel = $_.FullName.Substring($origen.Length + 1) -replace '\.respaldo$', ''
  Copy-Item $_.FullName (Join-Path $raiz $rel) -Force
  Write-Host "Restaurado: $rel"
}
$nuevos = @(
  'lib\features\tickets\domain\entities\ficha_creacion_repuesto_entity.dart',
  'lib\features\tickets\domain\services\creacion_codigos_venta_service.dart',
  'lib\features\tickets\domain\usecases\confirmar_aceptacion_cliente_venta_usecase.dart',
  'lib\features\tickets\domain\usecases\registrar_codigos_creados_usecase.dart',
  'lib\features\tickets\presentation\pages\creacion_codigos_venta_page.dart',
  'lib\features\tickets\presentation\widgets\codigos_creados_costos_widget.dart',
  'test\creacion_codigos_venta_test.dart'
)
foreach ($n in $nuevos) {
  $p = Join-Path $raiz $n
  if (Test-Path $p) { Remove-Item $p -Force; Write-Host "Borrado (nuevo): $n" }
}
Write-Host "Listo. Vuelva a compilar."
