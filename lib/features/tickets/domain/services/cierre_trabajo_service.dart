// lib/features/tickets/domain/services/cierre_trabajo_service.dart
//
// 🏁 Qué pasa cuando el taller sube la evidencia del trabajo (fin de Proceso
// de Trabajo). Solo reglas puras; probado en test/flujo_mantenimiento_test.dart.
// - Mantenimiento interno: pasa directo a FINALIZADO (no hay cliente: sin
//   facturación ni entrega).
// - Lo demás: Validación de Facturación (revisión de pagos), como siempre.

import '../../../../core/enum/proceso_auditoria.dart';
import '../../../../core/enum/ticket_enums.dart';
import '../entities/ticket_entity.dart';

class CierreTrabajoService {
  static EstadoTicket estadoTrasEvidencia(TicketEntity t) =>
      t.esMantenimientoInterno ? EstadoTicket.finalizado : EstadoTicket.validacionFacturacion;

  static List<ProcesoAuditoria> procesosTrasEvidencia(TicketEntity t) =>
      t.esMantenimientoInterno ? const [] : const [ProcesoAuditoria.revisionPagos];

  /// Texto que se agrega a la auditoría de la evidencia.
  static String notaAuditoria(TicketEntity t) =>
      t.esMantenimientoInterno ? ' MANTENIMIENTO INTERNO FINALIZADO.' : '';
}
