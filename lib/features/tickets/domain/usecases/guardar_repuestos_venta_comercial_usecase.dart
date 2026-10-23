// lib/features/tickets/domain/usecases/guardar_repuestos_venta_comercial_usecase.dart
//
// 🛒 Comercial guarda la lista de repuestos editada de una Venta de Repuesto
// (agregar desde el sistema, quitar, cambiar cantidad). Se aplica sobre el
// ticket ACTUAL dentro de una transacción y solo si sigue en Comercial. No
// cambia de etapa ni registra auditoría: los cambios van al registro
// "Cambios de materiales" (lista `venta`).

import 'package:dartz/dartz.dart';
import '../../../../core/enum/ticket_enums.dart';
import '../../../../core/errors/failures.dart';
import '../entities/cambio_material_entity.dart';
import '../entities/cambio_venta_repuesto.dart';
import '../entities/linea_repuesto_venta_entity.dart';
import '../entities/ticket_entity.dart';
import '../repositories/ticket_repository.dart';
import '../services/edicion_venta_comercial_service.dart';

class GuardarRepuestosVentaComercialUseCase {
  final ITicketRepository repository;

  GuardarRepuestosVentaComercialUseCase(this.repository);

  Future<Either<Failure, TicketEntity>> call({
    required String ticketId,
    required List<LineaRepuestoVentaEntity> lineas,
    required String nombreUsuario,
    required String rolUsuario,
    DateTime? ahora,
  }) async {
    if (lineas.isEmpty) {
      return const Left(ValidationFailure('Debe quedar al menos un repuesto en la venta.'));
    }
    if (lineas.any((l) => l.cantidad <= 0)) {
      return const Left(ValidationFailure('Todas las cantidades deben ser mayores a cero.'));
    }
    final momento = ahora ?? DateTime.now();
    return repository.actualizarVentaRepuestoEnTransaccion(
      ticketId: ticketId,
      aplicar: (actual) => aplicarSobre(actual, lineas, nombreUsuario, rolUsuario, momento),
    );
  }

  /// Regla pura (testeable sin repositorio).
  static CambioVentaRepuesto aplicarSobre(
    TicketEntity actual,
    List<LineaRepuestoVentaEntity> lineas,
    String nombreUsuario,
    String rolUsuario,
    DateTime momento,
  ) {
    if (actual.estadoActual != EstadoTicket.comercial) {
      throw CambioVentaRechazado(
          'El requerimiento ya no está en Comercial (estado: ${actual.estadoActual.nombreLegible}). No se guardaron los cambios.');
    }
    // Diferencias contra lo que hay guardado AHORA (no contra lo que se abrió).
    final cambios = EdicionVentaComercialService.diferencias(
      antes: actual.lineasRepuestoVenta,
      despues: lineas,
      momento: actual.proforma != null ? CambioMaterialEntity.regresoComercial : CambioMaterialEntity.primeraCotizacion,
      usuarioNombre: nombreUsuario,
      usuarioRol: rolUsuario,
      fecha: momento,
    );
    return CambioVentaRepuesto(lineas: lineas, cambiosMateriales: cambios);
  }
}
