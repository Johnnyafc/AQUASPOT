// lib/features/tickets/domain/entities/cambio_venta_repuesto.dart
//
// 🛒 Resultado de aplicar una regla de Venta de Repuesto sobre el ticket
// ACTUAL (releído dentro de la transacción por la capa de datos). Así
// Compras y la Evaluación técnica, que trabajan en paralelo, no se pisan.

import '../../../../core/enum/ticket_enums.dart';
import 'cambio_material_entity.dart';
import 'evento_auditoria_entity.dart';
import 'linea_repuesto_venta_entity.dart';

class CambioVentaRepuesto {
  final List<LineaRepuestoVentaEntity>? lineas; // null = las líneas no cambian
  final EstadoTicket? estadoNuevo; // null = el estado no cambia
  final EventoAuditoriaEntity? evento; // null = sin evento de auditoría
  final List<String> urlsCotizacionComprasNuevas;
  // Registro aparte "Cambios de materiales" (ediciones de Comercial).
  final List<CambioMaterialEntity> cambiosMateriales;
  // Repuestos con código recién creado por Costos: se agregan al inventario
  // de la app con stock 0, solo si ese código aún no existe.
  final List<RepuestoInventarioNuevo> inventarioNuevos;
  // Documentos de Entrega (venta): guía de remisión y factura recién subidas.
  final String? urlGuiaRemision;
  final String? urlFactura;

  const CambioVentaRepuesto({
    this.lineas,
    this.urlGuiaRemision,
    this.urlFactura,
    this.evento,
    this.estadoNuevo,
    this.urlsCotizacionComprasNuevas = const [],
    this.cambiosMateriales = const [],
    this.inventarioNuevos = const [],
  });
}

class RepuestoInventarioNuevo {
  final String codigo;
  final String descripcion;
  final String unidad;

  const RepuestoInventarioNuevo({required this.codigo, required this.descripcion, required this.unidad});
}

/// La regla no se puede aplicar sobre el ticket actual (cambió de etapa,
/// no quedan repuestos pendientes, etc.). Se informa como ValidationFailure.
class CambioVentaRechazado implements Exception {
  final String mensaje;
  const CambioVentaRechazado(this.mensaje);

  @override
  String toString() => mensaje;
}
