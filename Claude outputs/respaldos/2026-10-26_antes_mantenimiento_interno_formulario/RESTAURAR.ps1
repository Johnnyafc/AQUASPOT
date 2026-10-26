# Restaura el estado previo a "Mantenimiento interno: opcion en Crear Ticket y formulario dinamico".
# Tambien borra los archivos NUEVOS creados en este cambio.
# Uso (desde la raiz del proyecto aquaspot_postventa):
#   powershell -ExecutionPolicy Bypass -File "Claude outputs/respaldos/2026-10-26_antes_mantenimiento_interno_formulario/RESTAURAR.ps1"
$ErrorActionPreference = 'Stop'
$origen = Split-Path -Parent $MyInvocation.MyCommand.Path
$raiz = (Resolve-Path (Join-Path $origen '..\..\..')).Path
Get-ChildItem -Path $origen -Recurse -File -Filter '*.respaldo' | ForEach-Object {
  $rel = $_.FullName.Substring($origen.Length + 1) -replace '\.respaldo$', ''
  Copy-Item $_.FullName (Join-Path $raiz $rel) -Force
  Write-Host "Restaurado: $rel"
}
$nuevos = @(
  'lib\features\tickets\domain\entities\mantenimiento_interno_entity.dart',
  'lib\features\tickets\data\models\mantenimiento_interno_model.dart',
  'lib\features\tickets\domain\services\formulario_mantenimiento_service.dart',
  'lib\features\tickets\domain\usecases\crear_mantenimiento_interno_usecase.dart',
  'lib\features\tickets\domain\usecases\adjuntar_evidencias_mantenimiento_usecase.dart',
  'lib\features\tickets\presentation\bloc\mantenimiento_interno_cubit.dart',
  'lib\features\tickets\presentation\widgets\mantenimiento_interno_form_widget.dart',
  'test\formulario_mantenimiento_test.dart'
)
foreach ($n in $nuevos) {
  $p = Join-Path $raiz $n
  if (Test-Path $p) { Remove-Item $p -Force; Write-Host "Borrado (nuevo): $n" }
}
Write-Host "Listo. Vuelva a compilar."
