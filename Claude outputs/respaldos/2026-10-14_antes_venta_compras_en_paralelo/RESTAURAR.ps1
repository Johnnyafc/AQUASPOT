# Restaura el estado previo a "Venta de Repuesto: Compras en paralelo con la Evaluacion tecnica".
# Tambien borra los archivos NUEVOS creados en este cambio.
# Uso (desde la raiz del proyecto aquaspot_postventa):
#   powershell -ExecutionPolicy Bypass -File "Claude outputs/respaldos/2026-10-14_antes_venta_compras_en_paralelo/RESTAURAR.ps1"
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
  'lib\features\tickets\domain\entities\cambio_venta_repuesto.dart',
  'lib\features\tickets\domain\usecases\registrar_cotizacion_compras_venta_usecase.dart',
  'test\venta_compras_en_paralelo_test.dart'
)
foreach ($n in $nuevos) {
  $p = Join-Path $raiz $n
  if (Test-Path $p) { Remove-Item $p -Force; Write-Host "Borrado (nuevo): $n" }
}
Write-Host "Listo. Vuelva a compilar."
