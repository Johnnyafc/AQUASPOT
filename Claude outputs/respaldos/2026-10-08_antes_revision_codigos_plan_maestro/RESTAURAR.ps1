# Restaura el estado previo a "Revisión de Códigos del Plan Maestro".
# Uso (desde la raíz del proyecto aquaspot_postventa):
#   powershell -ExecutionPolicy Bypass -File "Claude outputs/respaldos/2026-10-08_antes_revision_codigos_plan_maestro/RESTAURAR.ps1"
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
  'lib\features\catalogo\domain\services\revision_codigos_plan_maestro_service.dart',
  'lib\features\catalogo\presentation\pages\revision_codigos_plan_maestro_page.dart',
  'test\revision_codigos_plan_maestro_test.dart'
)
foreach ($n in $nuevos) {
  $ruta = Join-Path $raiz $n
  if (Test-Path $ruta) { Remove-Item $ruta; Write-Host "Eliminado: $n" }
}
$dirServicios = Join-Path $raiz 'lib\features\catalogo\domain\services'
if ((Test-Path $dirServicios) -and -not (Get-ChildItem $dirServicios)) { Remove-Item $dirServicios }
Write-Host "Listo. Vuelva a compilar."
Write-Host "Nota: los cambios ya guardados en Firestore (catalogo_actividades / historial_plan_maestro) no se revierten con este script; use el boton Deshacer de la pantalla."
