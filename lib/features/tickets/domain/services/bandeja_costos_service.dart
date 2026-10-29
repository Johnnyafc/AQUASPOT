// lib/features/tickets/domain/services/bandeja_costos_service.dart
//
// 💼 Las dos tarjetas de Costos en el menú:
// - "Creación de proyectos": requerimientos en Costos que esperan su código
//   de proyecto (reparación, garantía…).
// - "Creación de códigos": repuestos sin código por crear en el ERP: los de
//   mantenimiento interno (aunque el resto ya esté en Compras / Bodega) y
//   los de una venta de repuestos que está en Costos.
// Ningún requerimiento aparece en las dos. Probado en
// test/bandeja_costos_test.dart.

import '../../../../core/enum/ticket_enums.dart';
import '../entities/ticket_entity.dart';
import 'creacion_codigos_mantenimiento_service.dart';
import 'creacion_codigos_venta_service.dart';

enum TarjetaCostos { creacionProyectos, creacionCodigos }

class BandejaCostosService {
  static bool esCreacionCodigos(TicketEntity t) =>
      CreacionCodigosMantenimientoService.requiereCreacionCodigos(t) ||
      (t.estadoActual == EstadoTicket.costos && CreacionCodigosVentaService.requiereCreacionCodigos(t));

  static bool esCreacionProyecto(TicketEntity t) => t.estadoActual == EstadoTicket.costos && !esCreacionCodigos(t);

  static bool corresponde(TarjetaCostos tarjeta, TicketEntity t) => switch (tarjeta) {
        TarjetaCostos.creacionProyectos => esCreacionProyecto(t),
        TarjetaCostos.creacionCodigos => esCreacionCodigos(t),
      };

  static String titulo(TarjetaCostos tarjeta) => switch (tarjeta) {
        TarjetaCostos.creacionProyectos => 'Creación de proyectos',
        TarjetaCostos.creacionCodigos => 'Creación de códigos',
      };
}
