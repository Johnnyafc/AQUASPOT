// lib/features/tickets/domain/usecases/registrar_cotizacion_compras_venta_usecase.dart
//
// 🛒 Compras adjunta la cotización de una Venta de Repuesto. Marca como
// cotizadas las líneas pendientes (sin stock / fuera del sistema) del ticket
// ACTUAL, dentro de una transacción:
//   - si aún queda algún repuesto por determinar (Evaluación técnica en
//     paralelo), el ticket SIGUE en Evaluación;
//   - si no, se enruta con RuteoVentaRepuestoService (normalmente Comercial).

import 'package:dartz/dartz.dart';
import '../../../../core/enum/proceso_auditoria.dart';
import '../../../../core/enum/ticket_enums.dart';
import '../../../../core/errors/failures.dart';
import '../entities/cambio_venta_repuesto.dart';
import '../entities/evento_auditoria_entity.dart';
import '../entities/ticket_entity.dart';
import '../repositories/ticket_repository.dart';
import '../services/ruteo_venta_repuesto_service.dart';

class RegistrarCotizacionComprasVentaUseCase {
  final ITicketRepository repository;

  RegistrarCotizacionComprasVentaUseCase(this.repository);

  Future<Either<Failure, TicketEntity>> call({
    required String ticketId,
    required List<String> urlsCotizacion,
    required String nombreUsuario,
    required String rolUsuario,
    DateTime? ahora,
  }) {
    final momento = ahora ?? DateTime.now();
    return repository.actualizarVentaRepuestoEnTransaccion(
      ticketId: ticketId,
      aplicar: (actual) => aplicarSobre(actual, urlsCotizacion, nombreUsuario, rolUsuario, momento),
    );
  }

  /// Regla pura (testeable sin repositorio).
  static CambioVentaRepuesto aplicarSobre(
    TicketEntity actual,
    List<String> urlsCotizacion,
    String nombreUsuario,
    String rolUsuario,
    DateTime momento,
  ) {
    final enEtapa = actual.estadoActual == EstadoTicket.cotizandoRepuesto ||
        RuteoVentaRepuestoService.comprasEnParalelo(actual);
    if (actual.tipoRequerimiento != TipoRequerimiento.ventaRepuesto || !enEtapa) {
      throw CambioVentaRechazado(
          'El requerimiento ya no tiene repuestos pendientes de cotizar (estado: ${actual.estadoActual.nombreLegible}). Actualice la bandeja.');
    }

    final lineas = actual.lineasRepuestoVenta
        .map((l) => RuteoVentaRepuestoService.requiereGestionCompras(l)
            ? l.copyWith(cotizadaPorCompras: true, cotizadaPor: nombreUsuario, cotizadaEn: momento)
            : l)
        .toList();

    final sigueEnEvaluacion = lineas.any((l) => l.porDeterminar);
    final destino = RuteoVentaRepuestoService.destino(lineas);

    return CambioVentaRepuesto(
      lineas: lineas,
      estadoNuevo: sigueEnEvaluacion ? null : RuteoVentaRepuestoService.estadoDe(destino),
      urlsCotizacionComprasNuevas: urlsCotizacion,
      evento: EventoAuditoriaEntity(
        accion: sigueEnEvaluacion
            ? 'COMPRAS: GESTIÓN DE REPUESTO SIN STOCK COMPLETADA (VENTA DE REPUESTO, EN PARALELO A EVALUACIÓN)'
            : 'COMPRAS: GESTIÓN DE REPUESTO SIN STOCK COMPLETADA (VENTA DE REPUESTO)',
        usuarioNombre: nombreUsuario,
        usuarioRol: rolUsuario,
        timestamp: momento,
        proceso: ProcesoAuditoria.compras,
        hito: HitoProceso.fin,
        // En paralelo no habilita nada nuevo: la Evaluación sigue su curso.
        habilita: sigueEnEvaluacion ? const [] : [RuteoVentaRepuestoService.procesoDe(destino)],
      ),
    );
  }
}
