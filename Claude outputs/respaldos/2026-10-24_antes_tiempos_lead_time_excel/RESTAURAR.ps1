# Restaura el estado previo a "Excel de Indicadores: tiempo exacto del lead time y etiquetas de rangos".
# Uso (desde la raiz del proyecto aquaspot_postventa):
#   powershell -ExecutionPolicy Bypass -File "Claude outputs/respaldos/2026-10-24_antes_tiempos_lead_time_excel/RESTAURAR.ps1"
$ErrorActionPreference = 'Stop'
$origen = Split-Path -Parent $MyInvocation.MyCommand.Path
$raiz = (Resolve-Path (Join-Path $origen '..\..\..')).Path
Get-ChildItem -Path $origen -Recurse -File -Filter '*.respaldo' | ForEach-Object {
  $rel = $_.FullName.Substring($origen.Length + 1) -replace '\.respaldo$', ''
  Copy-Item $_.FullName (Join-Path $raiz $rel) -Force
  Write-Host "Restaurado: $rel"
}
Write-Host "Listo. Vuelva a compilar."
