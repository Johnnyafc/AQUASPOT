// lib/features/tickets/domain/usecases/finalizar_evaluacion_venta_repuesto_usecase.dart
//
// 🛒 Evaluación de Venta de Repuesto (supervisor). Recibe las líneas como
// las dejó la pantalla (por determinar ya definidas, stock recalculado y
// enlaces de cotización del proveedor ya subidos) y las aplica sobre el
// ticket ACTUAL dentro de una transacción: solo reemplaza las líneas que
// seguían por determinar y conserva lo que Compras haya marcado en paralelo.
// El destino lo decide RuteoVentaRepuestoService (Comercial o Compras).

import 'package:dartz/dartz.dart';
import '../../../../core/enum/proceso_auditoria.dart';
import '../../../../core/enum/ticket_enums.dart';
import '../../../../core/errors/failures.dart';
import '../entities/cambio_venta_repuesto.dart';
import '../entities/evento_auditoria_entity.dart';
import '../entities/linea_repuesto_venta_entity.dart';
import '../entities/ticket_entity.dart';
import '../repositories/ticket_repository.dart';
import '../services/ruteo_venta_repuesto_service.dart';

class FinalizarEvaluacionVentaRepuestoUseCase {
  final ITicketRepository repository;

  FinalizarEvaluacionVentaRepuestoUseCase(this.repository);

  /// Devuelve el ticket como quedó guardado.
  Future<Either<Failure, TicketEntity>> call({
    required TicketEntity ticket,
    required List<LineaRepuestoVentaEntity> lineas,
    required String nombreUsuario,
    required String rolUsuario,
    DateTime? ahora,
  }) async {
    if (lineas.isEmpty || lineas.any((l) => l.porDeterminar)) {
      return const Left(ValidationFailure('Defina todos los repuestos por determinar antes de finalizar.'));
    }
    final momento = ahora ?? DateTime.now();
    return repository.actualizarVentaRepuestoEnTransaccion(
      ticketId: ticket.id,
      aplicar: (actual) => aplicarSobre(actual, lineas, nombreUsuario, rolUsuario, momento),
    );
  }

  /// Regla pura (testeable sin repositorio).
  static CambioVentaRepuesto aplicarSobre(
    TicketEntity actual,
    List<LineaRepuestoVentaEntity> definidas,
    String nombreUsuario,
    String rolUsuario,
    DateTime momento,
  ) {
    if (actual.estadoActual != EstadoTicket.recepcionFisica) {
      throw CambioVentaRechazado(
          'El requerimiento ya no está en Evaluación técnica (estado: ${actual.estadoActual.nombreLegible}). Vuelva a abrir la bandeja.');
    }
    final vigentes = actual.lineasRepuestoVenta;
    if (vigentes.length != definidas.length) {
      throw const CambioVentaRechazado('Los repuestos del requerimiento cambiaron. Vuelva a abrir la evaluación.');
    }

    final lineas = [
      for (int i = 0; i < vigentes.length; i++)
        vigentes[i].porDeterminar
            ? definidas[i]
            // Conserva las marcas de Compras; solo actualiza el stock recalculado.
            : vigentes[i].copyWith(stockDisponibleAlEvaluar: definidas[i].stockDisponibleAlEvaluar),
    ];

    final destino = RuteoVentaRepuestoService.destino(lineas);
    return CambioVentaRepuesto(
      lineas: lineas,
      estadoNuevo: RuteoVentaRepuestoService.estadoDe(destino),
      evento: EventoAuditoriaEntity(
        accion: 'EVALUACIÓN DE VENTA DE REPUESTO COMPLETADA',
        usuarioNombre: nombreUsuario,
        usuarioRol: rolUsuario,
        timestamp: momento,
        proceso: ProcesoAuditoria.evaluacion,
        hito: HitoProceso.fin,
        habilita: [RuteoVentaRepuestoService.procesoDe(destino)],
      ),
    );
  }
}
