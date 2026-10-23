// lib/features/tickets/domain/services/retiro_picking_service.dart
//
// 📦 RETIRO POR PICKING: cada orden de retiro lleva exactamente los
// repuestos de UN picking de Bodega (RegistroDespachoEntity), nada más.
//
// Por picking y por repuesto se calcula:
//   retirado   = lo recibido por el técnico en órdenes completadas
//   pendiente  = lo asignado en órdenes aún pendientes de retiro
//   disponible = lo del picking - retirado - pendiente
//
// Las órdenes anteriores a este cambio (sin pickingId) se reparten entre los
// pickings en orden de llegada, para no volver a ofrecer lo ya retirado.
// Las órdenes anuladas no cuentan.

import '../entities/orden_recepcion_repuestos_entity.dart';
import '../entities/registro_despacho_entity.dart';
import '../entities/ticket_entity.dart';

class ItemRetiroPicking {
  final String codigo;
  final String descripcion;
  final String unidad;
  final double cantidadPicking;
  final double retirado;
  final double pendiente;

  const ItemRetiroPicking({
    required this.codigo,
    required this.descripcion,
    required this.unidad,
    required this.cantidadPicking,
    required this.retirado,
    required this.pendiente,
  });

  double get disponible {
    final d = cantidadPicking - retirado - pendiente;
    return d > 0 ? d : 0;
  }
}

class RetiroPickingService {
  static const String listo = 'listo'; // listo para retiro
  static const String asignado = 'asignado'; // orden pendiente con técnico
  static const String retirado = 'retirado'; // todo retirado

  static String _k(String c) => c.trim().toUpperCase();

  static bool _cuenta(OrdenRecepcionRepuestosEntity o) => !o.estaAnulada;

  /// Ítems de cada picking (por id) con lo retirado / pendiente / disponible.
  static Map<String, List<ItemRetiroPicking>> calcular(TicketEntity t) {
    final pickings = t.historialDespachos;
    final ordenes = t.ordenesRecepcion.where(_cuenta).toList();

    // Directo: órdenes vinculadas a un picking.
    final directoRet = <String, Map<String, double>>{};
    final directoPend = <String, Map<String, double>>{};
    // Antiguas (sin picking): se reparten después.
    final antiguoRet = <String, double>{};
    final antiguoPend = <String, double>{};

    for (final o in ordenes) {
      final pendiente = o.estado == EstadoOrdenRecepcion.pendienteRecoger;
      for (final i in o.items) {
        final cant = pendiente ? i.cantidadDespachadaBodega : i.cantidadRecibidaTecnico;
        if (cant <= 0) continue;
        final k = _k(i.codigo);
        if (o.pickingId != null) {
          final destino = pendiente ? directoPend : directoRet;
          final m = destino.putIfAbsent(o.pickingId!, () => {});
          m[k] = (m[k] ?? 0) + cant;
        } else {
          final destino = pendiente ? antiguoPend : antiguoRet;
          destino[k] = (destino[k] ?? 0) + cant;
        }
      }
    }

    final resultado = <String, List<ItemRetiroPicking>>{};
    for (final p in pickings) {
      // Cantidades del picking agrupadas por código (respetando el orden).
      final cantidades = <String, double>{};
      final datos = <String, DetalleItemDespachadoEntity>{};
      for (final i in p.items) {
        final k = _k(i.codigo);
        cantidades[k] = (cantidades[k] ?? 0) + i.cantidad;
        datos.putIfAbsent(k, () => i);
      }
      final items = <ItemRetiroPicking>[];
      cantidades.forEach((k, cant) {
        var ret = directoRet[p.id]?[k] ?? 0;
        var pend = directoPend[p.id]?[k] ?? 0;
        // Reparto FIFO de las órdenes antiguas.
        var capacidad = cant - ret - pend;
        if (capacidad > 0 && (antiguoRet[k] ?? 0) > 0) {
          final usa = capacidad < antiguoRet[k]! ? capacidad : antiguoRet[k]!;
          ret += usa;
          antiguoRet[k] = antiguoRet[k]! - usa;
          capacidad -= usa;
        }
        if (capacidad > 0 && (antiguoPend[k] ?? 0) > 0) {
          final usa = capacidad < antiguoPend[k]! ? capacidad : antiguoPend[k]!;
          pend += usa;
          antiguoPend[k] = antiguoPend[k]! - usa;
        }
        final d = datos[k]!;
        items.add(ItemRetiroPicking(
          codigo: d.codigo,
          descripcion: d.descripcion,
          unidad: d.unidad,
          cantidadPicking: cant,
          retirado: ret,
          pendiente: pend,
        ));
      });
      resultado[p.id] = items;
    }
    return resultado;
  }

  static List<ItemRetiroPicking> items(TicketEntity t, String pickingId) => calcular(t)[pickingId] ?? const [];

  /// Hay una orden pendiente (con técnico) para este picking.
  static bool tieneOrdenPendiente(TicketEntity t, String pickingId) =>
      t.ordenesRecepcion.any((o) => o.pickingId == pickingId && o.estado == EstadoOrdenRecepcion.pendienteRecoger);

  static String estado(TicketEntity t, String pickingId, {Map<String, List<ItemRetiroPicking>>? calculado}) {
    final lista = (calculado ?? calcular(t))[pickingId] ?? const <ItemRetiroPicking>[];
    if (tieneOrdenPendiente(t, pickingId) || lista.any((i) => i.pendiente > 0)) return asignado;
    if (lista.any((i) => i.disponible > 0)) return listo;
    return retirado;
  }

  /// Pickings listos para enviar a retirar (con saldo y sin orden pendiente).
  static List<RegistroDespachoEntity> pickingsDisponibles(TicketEntity t) {
    final calculado = calcular(t);
    return t.historialDespachos.where((p) => estado(t, p.id, calculado: calculado) == listo).toList();
  }

  /// Pickings que el taller puede enviar a retirar: listos y con la
  /// evidencia de Bodega ya subida.
  static List<RegistroDespachoEntity> pickingsAsignables(TicketEntity t) =>
      pickingsDisponibles(t).where((p) => p.fotosEvidenciasUrls.isNotEmpty).toList();

  /// 🔒 TALLER SECUENCIAL: motivo por el que todavía NO se puede enviar a
  /// recoger otro picking (null = se puede). Una sola orden activa a la vez:
  /// todas las anteriores (sin contar anuladas) deben estar retiradas y con
  /// el consumo validado por el supervisor. Además, el picking a enviar
  /// debe tener la evidencia de Bodega.
  static String? motivoBloqueoAsignacion(TicketEntity t, {String? pickingId}) {
    for (final o in t.ordenesRecepcion) {
      if (o.estaAnulada) continue;
      final pk = o.pickingId == null ? '' : ' (${codigoCorto(t, o.pickingId!)})';
      if (o.estado == EstadoOrdenRecepcion.pendienteRecoger) {
        return 'La orden ${o.id}$pk aún está pendiente de retiro. Debe retirarse y validarse su consumo '
            'antes de enviar a recoger el siguiente picking.';
      }
      if (!o.validadoSupervisor) {
        return 'Valide el consumo de ${o.id}$pk antes de enviar a recoger el siguiente picking.';
      }
    }
    if (pickingId != null) {
      RegistroDespachoEntity? picking;
      for (final p in t.historialDespachos) {
        if (p.id == pickingId) picking = p;
      }
      if (picking == null) return 'El picking ${codigoCorto(t, pickingId)} ya no existe.';
      if (picking.fotosEvidenciasUrls.isEmpty) {
        return 'Bodega aún no sube la evidencia del ${codigoCorto(t, pickingId)}.';
      }
    } else if (t.historialDespachos.isNotEmpty && pickingsAsignables(t).isEmpty && pickingsDisponibles(t).isNotEmpty) {
      return 'Bodega aún no sube la evidencia de los pickings listos para retiro.';
    }
    return null;
  }

  /// Código corto del picking (sin el id del ticket): "PICK-02" / "DESP-01".
  static String codigoCorto(TicketEntity t, String pickingId) => pickingId.replaceFirst('${t.id}-', '');
}
