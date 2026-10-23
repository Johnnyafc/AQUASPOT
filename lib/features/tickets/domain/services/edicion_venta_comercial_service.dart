// lib/features/tickets/domain/services/edicion_venta_comercial_service.dart
//
// 🛒 Comercial edita los repuestos de una Venta de Repuesto (el cliente no
// quiere alguno, quiere otro o cambia la cantidad). Reglas puras:
// - nuevaLineaDesdeInventario: repuesto elegido del sistema, con su stock.
// - diferencias: qué se agregó, quitó o cambió de cantidad, para el registro
//   "Cambios de materiales" (lista `venta`). Sin auditoría ni cambio de etapa.

import '../entities/cambio_material_entity.dart';
import '../entities/linea_repuesto_venta_entity.dart';
import '../entities/repuesto_registrado_entity.dart';

class EdicionVentaComercialService {
  static LineaRepuestoVentaEntity nuevaLineaDesdeInventario({
    required String codigo,
    required String descripcion,
    required String unidad,
    required double cantidad,
    required double stockNeto,
  }) {
    return LineaRepuestoVentaEntity(
      codigo: codigo,
      descripcion: descripcion,
      unidad: unidad,
      cantidad: cantidad,
      stockDisponibleAlEvaluar: stockNeto,
    );
  }

  static List<CambioMaterialEntity> diferencias({
    required List<LineaRepuestoVentaEntity> antes,
    required List<LineaRepuestoVentaEntity> despues,
    required String momento,
    required String usuarioNombre,
    required String usuarioRol,
    required DateTime fecha,
  }) {
    RepuestoRegistradoEntity comoRepuesto(LineaRepuestoVentaEntity l) => RepuestoRegistradoEntity(
          codigo: l.codigo,
          descripcion: l.descripcionVisible,
          unidad: l.unidad,
          cantidad: l.cantidad,
        );
    return CambioMaterialEntity.diferencias(
      antes: antes.map(comoRepuesto).toList(),
      despues: despues.map(comoRepuesto).toList(),
      lista: CambioMaterialEntity.listaVenta,
      momento: momento,
      usuarioNombre: usuarioNombre,
      usuarioRol: usuarioRol,
      fecha: fecha,
    );
  }
}
