// lib/features/tickets/domain/services/flujo_venta_repuesto_service.dart
//
// 🛒 VENTA DE REPUESTO después de la OV (reglas puras):
//
//   OV → Compras (sin Costos/proyecto) → Validación Bodega (por repuesto,
//   en cualquier equipo) → Despacho/picking → Entrega (guía + factura,
//   igual que reparación; sin Revisión de pagos) → Finalizado.
//
// Las reparaciones y garantías no cambian.

import '../../../../core/enum/proceso_auditoria.dart';
import '../../../../core/enum/ticket_enums.dart';
import '../entities/item_despacho_bodega_entity.dart';
import '../entities/linea_repuesto_venta_entity.dart';
import '../entities/ticket_entity.dart';
import 'flujo_reportes_automaticos_service.dart';

class FlujoVentaRepuestoService {
  static bool esVenta(TicketEntity t) => t.tipoRequerimiento == TipoRequerimiento.ventaRepuesto;

  // ------------------------------------------------------------- OV
  /// Estado tras registrar la OV: la venta va directo a Compras.
  static EstadoTicket estadoTrasOV(TicketEntity t) => esVenta(t) ? EstadoTicket.compras : EstadoTicket.costos;

  /// Procesos que habilita la OV.
  static List<ProcesoAuditoria> procesosTrasOV(TicketEntity t) =>
      esVenta(t) ? const [ProcesoAuditoria.compras] : const [ProcesoAuditoria.costos, ProcesoAuditoria.compras];

  /// Lista para Bodega armada con los repuestos finales de la venta.
  static List<ItemDespachoBodegaEntity> itemsDespachoDesdeLineas(
    List<LineaRepuestoVentaEntity> lineas, {
    required DateTime fechaSolicitud,
  }) {
    return [
      for (final l in lineas)
        ItemDespachoBodegaEntity(
          codigo: l.codigo,
          descripcion: l.descripcionVisible,
          unidad: l.unidad,
          cantidadSolicitada: l.cantidad,
          stockDisponibleAlEvaluar: l.stockDisponibleAlEvaluar ?? 0,
          validadoPorCompras: false,
          cantidadDespachada: 0,
          fechaSolicitud: fechaSolicitud,
        ),
    ];
  }

  // ------------------------------------------------- Validación Bodega
  /// Validación por repuesto con "Transferir a Bodega" (sin "directo a
  /// taller"): la venta y los tickets con flujo de reportes automáticos.
  static bool validacionPorRepuesto(TicketEntity t) => esVenta(t) || FlujoReportesAutomaticosService.usa(t);

  // ------------------------------------------------------------ Picking
  /// Estado tras "Finalizar picking": la venta pasa a Entrega.
  static EstadoTicket estadoTrasPicking(TicketEntity t) =>
      esVenta(t) ? EstadoTicket.entrega : EstadoTicket.procesoTrabajo;

  static List<ProcesoAuditoria> procesosTrasPicking(TicketEntity t) =>
      esVenta(t) ? const [ProcesoAuditoria.entrega] : const [ProcesoAuditoria.taller];

  // ------------------------------------------------------------ Entrega
  /// En Entrega y Bodega aún no sube la guía firmada (sigue en Despacho).
  static bool esperaGuiaFirmada(TicketEntity t) =>
      esVenta(t) && t.estadoActual == EstadoTicket.entrega && t.tieneDespachoPendienteDeEvidencia;

  static bool _tiene(String? url) => url != null && url.trim().isNotEmpty;

  /// Qué falta para finalizar la entrega (vacío = se puede finalizar).
  /// Venta: guía + factura (Entregas) + guía firmada de Bodega (Despacho).
  static List<String> faltantesParaFinalizar(TicketEntity t) => [
        if (!_tiene(t.urlGuiaRemision)) 'Guía de remisión',
        if (!_tiene(t.urlFactura)) 'Factura',
        if (esVenta(t) && (t.historialDespachos.isEmpty || t.tieneDespachoPendienteDeEvidencia)) 'Guía firmada de Bodega',
      ];

  static bool puedeFinalizarEntrega(TicketEntity t) =>
      t.estadoActual == EstadoTicket.entrega && faltantesParaFinalizar(t).isEmpty;

  /// El picking libera la reserva solo en los tickets con flujo de reportes
  /// automáticos (los que apartan stock al evaluar): las ventas nunca
  /// reservan stock (no deben tocar reservas de otros tickets).
  static bool liberaReservaEnPicking(TicketEntity t) => FlujoReportesAutomaticosService.usa(t);
}
