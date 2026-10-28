// lib/features/tickets/domain/entities/cambio_mantenimiento_interno.dart
//
// 🛠️ Resultado de aplicar una regla de MANTENIMIENTO INTERNO sobre el ticket
// ACTUAL (releído dentro de la transacción por la capa de datos), así Costos
// no pisa lo que Compras o Bodega guardaron mientras tanto.

import 'cambio_venta_repuesto.dart' show RepuestoInventarioNuevo;
import 'evento_auditoria_entity.dart';
import 'ticket_entity.dart';

class CambioMantenimientoInterno {
  // Ticket con los cambios: se guardan su mantenimientoInterno,
  // itemsDespachoBodega, los repuestos de la evaluación y el estado.
  final TicketEntity ticket;
  final EventoAuditoriaEntity evento;
  // Repuestos con código recién creado: al inventario con stock 0 (solo si
  // ese código aún no existe).
  final List<RepuestoInventarioNuevo> inventarioNuevos;
  // Caracol: código → cantidad a sumar a stockReservado (el picking lo libera).
  final Map<String, double> reservas;

  const CambioMantenimientoInterno({
    required this.ticket,
    required this.evento,
    this.inventarioNuevos = const [],
    this.reservas = const {},
  });
}

/// La regla no se puede aplicar sobre el ticket actual. Se informa como
/// ValidationFailure.
class CambioMantenimientoRechazado implements Exception {
  final String mensaje;
  const CambioMantenimientoRechazado(this.mensaje);

  @override
  String toString() => mensaje;
}
