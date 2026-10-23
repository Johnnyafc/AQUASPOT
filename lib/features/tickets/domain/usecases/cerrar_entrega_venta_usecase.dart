// lib/features/tickets/domain/usecases/cerrar_entrega_venta_usecase.dart
//
// 🛒 Entrega de una Venta de Repuesto. Registra la guía de remisión o la
// factura (Entregas) y finaliza el requerimiento solo cuando están las tres
// piezas: guía + factura + guía firmada subida por Bodega en Despacho. Da
// igual el orden: también se llama sin documentos justo después de que
// Bodega sube la guía firmada. Transacción sobre el ticket ACTUAL, para no
// pisar lo que Entregas y Bodega guardan en paralelo.

import 'package:dartz/dartz.dart';
import '../../../../core/enum/proceso_auditoria.dart';
import '../../../../core/enum/ticket_enums.dart';
import '../../../../core/errors/failures.dart';
import '../entities/cambio_venta_repuesto.dart';
import '../entities/evento_auditoria_entity.dart';
import '../entities/ticket_entity.dart';
import '../repositories/ticket_repository.dart';
import '../services/flujo_venta_repuesto_service.dart';

class CerrarEntregaVentaUseCase {
  final ITicketRepository repository;

  CerrarEntregaVentaUseCase(this.repository);

  /// [urlGuiaRemision] / [urlFactura]: documento recién subido (o null).
  Future<Either<Failure, TicketEntity>> call({
    required String ticketId,
    String? urlGuiaRemision,
    String? urlFactura,
    String observacion = '',
    required String nombreUsuario,
    required String rolUsuario,
    DateTime? ahora,
  }) {
    final momento = ahora ?? DateTime.now();
    return repository.actualizarVentaRepuestoEnTransaccion(
      ticketId: ticketId,
      aplicar: (actual) => aplicarSobre(
        actual,
        urlGuiaRemision: urlGuiaRemision,
        urlFactura: urlFactura,
        observacion: observacion,
        nombreUsuario: nombreUsuario,
        rolUsuario: rolUsuario,
        momento: momento,
      ),
    );
  }

  /// Regla pura (testeable sin repositorio).
  static CambioVentaRepuesto aplicarSobre(
    TicketEntity actual, {
    String? urlGuiaRemision,
    String? urlFactura,
    String observacion = '',
    required String nombreUsuario,
    required String rolUsuario,
    required DateTime momento,
  }) {
    if (!FlujoVentaRepuestoService.esVenta(actual)) {
      throw const CambioVentaRechazado('Este requerimiento no es una Venta de Repuesto.');
    }
    if (actual.estadoActual == EstadoTicket.finalizado || actual.estadoActual == EstadoTicket.anulado) {
      throw CambioVentaRechazado('El requerimiento ya está ${actual.estadoActual.nombreLegible}.');
    }

    final conDocumentos = actual.copyWith(
      urlGuiaRemision: urlGuiaRemision ?? actual.urlGuiaRemision,
      urlFactura: urlFactura ?? actual.urlFactura,
    );
    final finaliza = FlujoVentaRepuestoService.puedeFinalizarEntrega(conDocumentos);
    final subeDocumento = urlGuiaRemision != null || urlFactura != null;

    // Sin documento nuevo y sin poder finalizar: no hay nada que guardar.
    if (!subeDocumento && !finaliza) return const CambioVentaRepuesto();

    final obs = observacion.trim().isEmpty ? 'Sin observaciones' : observacion.trim();
    final accionBase = urlGuiaRemision != null
        ? 'CARGA DE GUÍA DE REMISIÓN (VENTA). Obs: $obs'
        : urlFactura != null
            ? 'CARGA DE FACTURA (VENTA). Obs: $obs'
            : 'BODEGA: GUÍA FIRMADA REGISTRADA (VENTA)';

    return CambioVentaRepuesto(
      urlGuiaRemision: urlGuiaRemision,
      urlFactura: urlFactura,
      estadoNuevo: finaliza ? EstadoTicket.finalizado : null,
      evento: EventoAuditoriaEntity(
        accion: finaliza ? '$accionBase — ENTREGA COMPLETA (GUÍA, FACTURA Y GUÍA FIRMADA): FINALIZADO' : accionBase,
        usuarioNombre: nombreUsuario,
        usuarioRol: rolUsuario,
        timestamp: momento,
        proceso: ProcesoAuditoria.entrega,
        hito: finaliza ? HitoProceso.fin : HitoProceso.avance,
      ),
    );
  }
}
