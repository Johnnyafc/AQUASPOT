# Restaura los archivos al estado previo a "ronda de revision de fallas"
$raiz = Resolve-Path (Join-Path $PSScriptRoot "../../..")
Copy-Item -Force (Join-Path $PSScriptRoot 'lib/core/utils/constants.dart.respaldo') (Join-Path $raiz 'lib/core/utils/constants.dart')
Copy-Item -Force (Join-Path $PSScriptRoot 'lib/features/tickets/domain/entities/ticket_entity.dart.respaldo') (Join-Path $raiz 'lib/features/tickets/domain/entities/ticket_entity.dart')
Copy-Item -Force (Join-Path $PSScriptRoot 'lib/features/tickets/data/models/ticket_model.dart.respaldo') (Join-Path $raiz 'lib/features/tickets/data/models/ticket_model.dart')
Copy-Item -Force (Join-Path $PSScriptRoot 'lib/features/tickets/presentation/bloc/ticket_bloc.dart.respaldo') (Join-Path $raiz 'lib/features/tickets/presentation/bloc/ticket_bloc.dart')
Copy-Item -Force (Join-Path $PSScriptRoot 'lib/features/tickets/presentation/pages/bandeja_fallas_pendientes_page.dart.respaldo') (Join-Path $raiz 'lib/features/tickets/presentation/pages/bandeja_fallas_pendientes_page.dart')
Write-Host "Restaurado."
