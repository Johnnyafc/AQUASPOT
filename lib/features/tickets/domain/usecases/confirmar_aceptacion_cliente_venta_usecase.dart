// lib/features/tickets/domain/usecases/confirmar_aceptacion_cliente_venta_usecase.dart
//
// 🧾 Proformas enviadas: Comercial confirma que el cliente aceptó la proforma
// de una Venta de Repuesto con repuestos que no están en el sistema. El
// ticket pasa a Costos para que cree los códigos (transacción sobre el
// ticket ACTUAL; solo si sigue en Proformas enviadas y aún faltan códigos).

import 'package:dartz/dartz.dart';
import '../../../../core/enum/proceso_auditoria.dart';
import '../../../../core/enum/ticket_enums.dart';
import '../../../../core/errors/failures.dart';
import '../entities/cambio_venta_repuesto.dart';
import '../entities/evento_auditoria_entity.dart';
import '../entities/ticket_entity.dart';
import '../repositories/ticket_repository.dart';
import '../services/creacion_codigos_venta_service.dart';

class ConfirmarAceptacionClienteVentaUseCase {
  final ITicketRepository repository;

  ConfirmarAceptacionClienteVentaUseCase(this.repository);

  Future<Either<Failure, TicketEntity>> call({
    required String ticketId,
    required String nombreUsuario,
    required String rolUsuario,
    DateTime? ahora,
  }) {
    final momento = ahora ?? DateTime.now();
    return repository.actualizarVentaRepuestoEnTransaccion(
      ticketId: ticketId,
      aplicar: (actual) => aplicarSobre(actual, nombreUsuario, rolUsuario, momento),
    );
  }

  /// Regla pura (testeable sin repositorio).
  static CambioVentaRepuesto aplicarSobre(TicketEntity actual, String nombreUsuario, String rolUsuario, DateTime momento) {
    if (actual.estadoActual != EstadoTicket.cotizado) {
      throw CambioVentaRechazado(
          'El requerimiento ya no está en Proformas enviadas (estado: ${actual.estadoActual.nombreLegible}). Actualice la bandeja.');
    }
    if (!CreacionCodigosVentaService.requiereCreacionCodigos(actual)) {
      throw const CambioVentaRechazado('Este requerimiento no tiene repuestos pendientes de crear código.');
    }
    final n = CreacionCodigosVentaService.indicesPendientes(actual).length;
    return CambioVentaRepuesto(
      lineas: actual.lineasRepuestoVenta,
      estadoNuevo: EstadoTicket.costos,
      evento: EventoAuditoriaEntity(
        accion: 'COMERCIAL: CLIENTE ACEPTÓ LA PROFORMA — PASA A COSTOS PARA CREAR $n CÓDIGO(S) DE REPUESTO',
        usuarioNombre: nombreUsuario,
        usuarioRol: rolUsuario,
        timestamp: momento,
        proceso: ProcesoAuditoria.aprobacionCliente,
        hito: HitoProceso.avance,
        habilita: const [ProcesoAuditoria.costos],
      ),
    );
  }
}
