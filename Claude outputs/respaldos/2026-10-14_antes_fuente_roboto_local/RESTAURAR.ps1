# Restaura el estado previo a "Fuente Roboto incluida en la app (sin descarga desde internet)".
# Tambien borra la carpeta nueva assets/fonts.
# Uso (desde la raiz del proyecto aquaspot_postventa):
#   powershell -ExecutionPolicy Bypass -File "Claude outputs/respaldos/2026-10-14_antes_fuente_roboto_local/RESTAURAR.ps1"
$ErrorActionPreference = 'Stop'
$origen = Split-Path -Parent $MyInvocation.MyCommand.Path
$raiz = (Resolve-Path (Join-Path $origen '..\..\..')).Path
Get-ChildItem -Path $origen -Recurse -File -Filter '*.respaldo' | ForEach-Object {
  $rel = $_.FullName.Substring($origen.Length + 1) -replace '\.respaldo$', ''
  Copy-Item $_.FullName (Join-Path $raiz $rel) -Force
  Write-Host "Restaurado: $rel"
}
$fonts = Join-Path $raiz 'assets\fonts'
if (Test-Path $fonts) { Remove-Item $fonts -Recurse -Force; Write-Host "Borrado (nuevo): assets\fonts" }
Write-Host "Listo. Ejecute 'flutter pub get' y vuelva a compilar."
