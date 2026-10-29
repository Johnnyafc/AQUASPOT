// lib/features/tickets/domain/services/visibilidad_segmento_service.dart
//
// 👥 Qué requerimientos ve (y de cuáles recibe aviso) cada supervisor según
// su segmento. Probado en test/visibilidad_segmento_test.dart.
//
// - General / sin segmento: todo.
// - Requerimientos (reparación, garantía, venta…): solo los de su equipo
//   (Caracol, Cosechadora, Contador).
// - OT (mantenimiento interno), según la máquina:
//     Caracol → Caracol
//     Cosechadora → Cosechadora y también Caracol
//     Contador → Contador
//     Bomba de transferencia, vehículo, aire acondicionado, herramientas →
//       Caracol
// La misma regla está en functions/src/index.ts (segmentosDelTicket) para
// las notificaciones: si cambia aquí, cambia allá.

import '../../../../core/enum/segmento_operativo.dart';
import '../../../../core/enum/ticket_enums.dart';
import '../entities/mantenimiento_interno_entity.dart';
import '../entities/ticket_entity.dart';

class VisibilidadSegmentoService {
  /// Segmentos que reciben este requerimiento (además de general / ninguno).
  static Set<SegmentoOperativo> segmentosDe(TicketEntity t) {
    if (!t.esMantenimientoInterno) {
      return switch (t.equipo) {
        TipoEquipo.Caracol => {SegmentoOperativo.caracol},
        TipoEquipo.Cosechadora => {SegmentoOperativo.cosechadora},
        TipoEquipo.Contador => {SegmentoOperativo.contador},
        _ => const {},
      };
    }
    // OT sin máquina legible: a Caracol, igual que las notificaciones.
    return switch (t.mantenimientoInterno?.tipoActivo) {
      TipoActivoMantenimiento.contador => {SegmentoOperativo.contador},
      TipoActivoMantenimiento.cosechadora => {SegmentoOperativo.cosechadora, SegmentoOperativo.caracol},
      _ => {SegmentoOperativo.caracol},
    };
  }

  static bool veTodo(SegmentoOperativo s) => s == SegmentoOperativo.general || s == SegmentoOperativo.ninguno;

  static bool ve(SegmentoOperativo s, TicketEntity t) => veTodo(s) || segmentosDe(t).contains(s);

  /// Para la consulta: equipos de los requerimientos del segmento.
  static List<TipoEquipo> equiposDe(SegmentoOperativo s) => switch (s) {
        SegmentoOperativo.caracol => [TipoEquipo.Caracol],
        SegmentoOperativo.cosechadora => [TipoEquipo.Cosechadora],
        SegmentoOperativo.contador => [TipoEquipo.Contador],
        _ => const [],
      };

  /// El segmento recibe OT de máquinas que no son de su equipo (Caracol):
  /// la consulta debe traer también los mantenimientos internos.
  static bool consultaMantenimientos(SegmentoOperativo s) => s == SegmentoOperativo.caracol;
}
