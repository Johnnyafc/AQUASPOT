# Restaura el estado previo a "Refactor de arquitectura limpia de Venta de Repuesto (use case, servicio de dominio, modelo de presentacion)".
# Tambien borra los archivos NUEVOS creados en este cambio.
# Uso (desde la raiz del proyecto aquaspot_postventa):
#   powershell -ExecutionPolicy Bypass -File "Claude outputs/respaldos/2026-10-14_antes_refactor_arquitectura_venta/RESTAURAR.ps1"
$ErrorActionPreference = 'Stop'
$origen = Split-Path -Parent $MyInvocation.MyCommand.Path
$raiz = (Resolve-Path (Join-Path $origen '..\..\..')).Path
Get-ChildItem -Path $origen -Recurse -File -Filter '*.respaldo' | ForEach-Object {
  $rel = $_.FullName.Substring($origen.Length + 1) -replace '\.respaldo$', ''
  Copy-Item $_.FullName (Join-Path $raiz $rel) -Force
  Write-Host "Restaurado: $rel"
}
$nuevos = @(
  'lib\features\tickets\domain\usecases\finalizar_evaluacion_venta_repuesto_usecase.dart',
  'lib\features\tickets\domain\services\evaluacion_venta_repuesto_service.dart',
  'lib\features\tickets\presentation\models\archivos_linea_venta.dart',
  'test\evaluacion_venta_repuesto_test.dart'
)
foreach ($n in $nuevos) {
  $p = Join-Path $raiz $n
  if (Test-Path $p) { Remove-Item $p -Force; Write-Host "Borrado (nuevo): $n" }
}
Write-Host "Listo. Vuelva a compilar."
