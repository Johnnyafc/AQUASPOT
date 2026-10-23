# Restaura el estado previo a "Borrador completo de Evaluación Técnica (IndexedDB en web)".
# Uso (desde la raíz del proyecto aquaspot_postventa):
#   powershell -ExecutionPolicy Bypass -File "Claude outputs/respaldos/2026-10-08_antes_borrador_evaluacion_tecnica/RESTAURAR.ps1"
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
  'lib\core\services\archivos_borrador_store.dart',
  'lib\core\services\archivos_borrador_store_stub.dart',
  'lib\core\services\archivos_borrador_store_web.dart',
  'lib\features\tickets\domain\services\borrador_evaluacion_codec.dart',
  'test\borrador_evaluacion_codec_test.dart'
)
foreach ($n in $nuevos) {
  $ruta = Join-Path $raiz $n
  if (Test-Path $ruta) { Remove-Item $ruta; Write-Host "Eliminado: $n" }
}
Write-Host "Listo. Vuelva a compilar."
