# Restaura el estado previo a "Tiempo por proceso: Despacho desplegable (antes del picking, picking, validacion simple)".
# Uso (desde la raiz del proyecto aquaspot_postventa):
#   powershell -ExecutionPolicy Bypass -File "Claude outputs/respaldos/2026-10-24_antes_desglose_despacho_picking/RESTAURAR.ps1"
$ErrorActionPreference = 'Stop'
$origen = Split-Path -Parent $MyInvocation.MyCommand.Path
$raiz = (Resolve-Path (Join-Path $origen '..\..\..')).Path
Get-ChildItem -Path $origen -Recurse -File -Filter '*.respaldo' | ForEach-Object {
  $rel = $_.FullName.Substring($origen.Length + 1) -replace '\.respaldo$', ''
  Copy-Item $_.FullName (Join-Path $raiz $rel) -Force
  Write-Host "Restaurado: $rel"
}
Write-Host "Listo. Vuelva a compilar."
