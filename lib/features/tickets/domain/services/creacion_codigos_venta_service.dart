// lib/features/tickets/domain/services/creacion_codigos_venta_service.dart
//
// 🧾 VENTA DE REPUESTO con repuestos que NO están en el sistema (los que el
// supervisor definió con cotización de proveedor y ficha de creación):
//
//   Proformas enviadas → ✔ Cliente aceptó → Costos crea los códigos →
//   Proformas enviadas (aviso con los códigos) → recién ahí la OV.
//
// Las ventas sin esos repuestos y las reparaciones no pasan por aquí.

import '../../../../core/enum/ticket_enums.dart';
import '../entities/linea_repuesto_venta_entity.dart';
import '../entities/ticket_entity.dart';

class CreacionCodigosVentaService {
  /// La línea es un repuesto nuevo (con ficha) al que Costos aún no le creó código.
  static bool pendienteDeCodigo(LineaRepuestoVentaEntity l) => l.fichaCreacion != null && !l.codigoCreadoPorCostos;

  static bool esVenta(TicketEntity t) => t.tipoRequerimiento == TipoRequerimiento.ventaRepuesto;

  /// Venta que todavía necesita que Costos cree códigos.
  static bool requiereCreacionCodigos(TicketEntity t) => esVenta(t) && t.lineasRepuestoVenta.any(pendienteDeCodigo);

  /// Venta cuyos repuestos nuevos ya tienen código oficial.
  static bool tieneCodigosCreados(TicketEntity t) =>
      esVenta(t) && t.lineasRepuestoVenta.any((l) => l.codigoCreadoPorCostos) && !requiereCreacionCodigos(t);

  /// Se puede registrar la OV (en ventas con repuestos nuevos, solo tras Costos).
  static bool puedeRegistrarOV(TicketEntity t) => !requiereCreacionCodigos(t);

  /// Índices de las líneas a las que Costos debe crear código.
  static List<int> indicesPendientes(TicketEntity t) => [
        for (int i = 0; i < t.lineasRepuestoVenta.length; i++)
          if (pendienteDeCodigo(t.lineasRepuestoVenta[i])) i,
      ];

  /// Cómo queda la línea con el código oficial que creó Costos: pasa a estar
  /// en el sistema; conserva la ficha, la cotización y las marcas de Compras.
  static LineaRepuestoVentaEntity conCodigoOficial(
    LineaRepuestoVentaEntity l, {
    required String codigo,
    required String descripcion,
    required String creadoPor,
    required DateTime creadoEn,
  }) {
    return l.copyWith(
      codigo: codigo.trim(),
      descripcion: descripcion.trim(),
      unidad: l.fichaCreacion?.udm.trim().isNotEmpty == true ? l.fichaCreacion!.udm.trim() : l.unidad,
      existeEnSistema: true,
      codigoCreadoPorCostos: true,
      codigoCreadoPor: creadoPor,
      codigoCreadoEn: creadoEn,
    );
  }
}
