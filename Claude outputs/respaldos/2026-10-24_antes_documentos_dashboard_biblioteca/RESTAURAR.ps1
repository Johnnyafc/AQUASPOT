# Restaura el estado previo a "Documentos: columnas nuevas en el Dashboard y carpetas nuevas en la Biblioteca".
# Tambien borra los archivos NUEVOS creados en este cambio.
# Uso (desde la raiz del proyecto aquaspot_postventa):
#   powershell -ExecutionPolicy Bypass -File "Claude outputs/respaldos/2026-10-24_antes_documentos_dashboard_biblioteca/RESTAURAR.ps1"
$ErrorActionPreference = 'Stop'
$origen = Split-Path -Parent $MyInvocation.MyCommand.Path
$raiz = (Resolve-Path (Join-Path $origen '..\..\..')).Path
Get-ChildItem -Path $origen -Recurse -File -Filter '*.respaldo' | ForEach-Object {
  $rel = $_.FullName.Substring($origen.Length + 1) -replace '\.respaldo$', ''
  Copy-Item $_.FullName (Join-Path $raiz $rel) -Force
  Write-Host "Restaurado: $rel"
}
$nuevos = @(
  'lib\features\tickets\domain\services\documentos_ticket_service.dart',
  'test\documentos_ticket_test.dart'
)
foreach ($n in $nuevos) {
  $p = Join-Path $raiz $n
  if (Test-Path $p) { Remove-Item $p -Force; Write-Host "Borrado (nuevo): $n" }
}
Write-Host "Listo. Vuelva a compilar."
