// lib/features/tickets/domain/services/flujo_reportes_automaticos_service.dart
//
// 🤖 "Usa flujo con generación de reportes automáticos" (el flujo que nació
// con Caracol): Evaluación con Plan Maestro e informe técnico + Solicitud
// de materiales generados en la app, stock apartado al evaluar, Validación
// Bodega por repuesto, Despacho Bodega con picking (que libera la reserva)
// y anulación que devuelve lo apartado. Solo reglas puras; probado en
// test/flujo_reportes_automaticos_test.dart.
//
// - Al EVALUAR corresponde a: todo mantenimiento interno y a las
//   reparaciones / garantías de Caracol, Cosechadora y Contador ("Otros" y
//   la venta de repuesto no).
// - Al guardar la evaluación el ticket queda marcado
//   (usaFlujoReportesAutomaticos) y desde ahí lo usa. Los tickets ya
//   evaluados sin marca terminan con el flujo con el que empezaron; los
//   Caracol antiguos siempre lo usaron.

import '../../../../core/enum/ticket_enums.dart';
import '../entities/ticket_entity.dart';

class FlujoReportesAutomaticosService {
  static const String etiqueta = 'Usa flujo con generación de reportes automáticos';

  static const Set<TipoEquipo> equiposReparacion = {TipoEquipo.Caracol, TipoEquipo.Cosechadora, TipoEquipo.Contador};

  static bool _esVenta(TicketEntity t) => t.tipoRequerimiento == TipoRequerimiento.ventaRepuesto;

  /// Al guardar su Evaluación Técnica, ¿el ticket entra a este flujo?
  static bool correspondeAlEvaluar(TicketEntity t) {
    if (t.esMantenimientoInterno) return true;
    if (_esVenta(t)) return false;
    return equiposReparacion.contains(t.equipo);
  }

  /// ¿El ticket (ya evaluado) usa este flujo? Marca o Caracol antiguo.
  static bool usa(TicketEntity t) {
    if (_esVenta(t)) return false;
    return t.usaFlujoReportesAutomaticos || t.equipo == TipoEquipo.Caracol;
  }

  /// Equipo del Plan Maestro (catálogo) de una reparación con este flujo.
  static String equipoPlanMaestro(TipoEquipo e) => e.name.toLowerCase();

  /// Para la pantalla y el guardado de la Evaluación Técnica: si aún no
  /// tiene evaluación decide la regla nueva; si ya la tiene (re-evaluación),
  /// sigue con el flujo con el que empezó.
  static bool paraEvaluacion(TicketEntity t) =>
      t.evaluacionTecnica == null ? correspondeAlEvaluar(t) : usa(t);
}
