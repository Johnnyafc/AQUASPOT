# Restaura el estado previo a "Link de prueba desarrollo (GitHub Actions + canal de vista previa de Firebase)".
# Este cambio solo AGREGÓ un archivo; restaurar = borrarlo.
# Uso (desde la raiz del proyecto aquaspot_postventa):
#   powershell -ExecutionPolicy Bypass -File "Claude outputs/respaldos/2026-10-26_antes_vista_previa_desarrollo/RESTAURAR.ps1"
# Nota: el canal "desarrollo" de Firebase se borra aparte (Firebase → Hosting → Canales de vista previa).
$ErrorActionPreference = 'Stop'
$origen = Split-Path -Parent $MyInvocation.MyCommand.Path
$raiz = (Resolve-Path (Join-Path $origen '..\..\..')).Path
$nuevo = Join-Path $raiz '.github\workflows\vista-previa-desarrollo.yml'
if (Test-Path $nuevo) { Remove-Item $nuevo -Force; Write-Host 'Borrado (nuevo): .github\workflows\vista-previa-desarrollo.yml' }
Write-Host 'Listo.'
