// lib/features/tickets/domain/services/estado_despacho_service.dart
//
// 📦 PICKING EN BODEGA: estado del despacho de un ticket (campo
// `estadoDespacho` en Firestore) y las reglas de los botones de la tarjeta.
//
//   pendiente → pickingEnCurso → despachoParcial → pickingFinalizado
//
// - Iniciar picking: solo en `pendiente`.
// - Las entregas parciales (ventana de despacho) dejan `despachoParcial`.
// - Finalizar picking: cuando todos los repuestos tienen su check
//   (despachados al 100 %) y todos los despachos tienen evidencia. Recién
//   ahí el ticket pasa a Proceso de Trabajo.
// - Tickets anteriores sin el campo: el estado se deduce de lo que ya
//   tienen (ver efectivo) y la bandeja lo escribe en Firestore.

import '../../../../core/enum/ticket_enums.dart';
import '../entities/registro_despacho_entity.dart';
import '../entities/ticket_entity.dart';
import 'creacion_codigos_mantenimiento_service.dart';

class EstadoDespachoService {
  static const String pendiente = 'pendiente';
  static const String pickingEnCurso = 'pickingEnCurso';
  static const String despachoParcial = 'despachoParcial';
  static const String pickingFinalizado = 'pickingFinalizado';

  static const List<String> valores = [pendiente, pickingEnCurso, despachoParcial, pickingFinalizado];

  /// Estado deducido para tickets que aún no tienen el campo. Un ticket que
  /// ya despachó todo con evidencia se considera finalizado (antes de este
  /// cambio pasaba solo a Proceso de Trabajo); uno con alguna entrega,
  /// en despacho parcial (picking en curso); si no, pendiente.
  static String deducido(TicketEntity t) {
    if (t.bodegaDespachoCompleto && !t.tieneDespachoPendienteDeEvidencia) return pickingFinalizado;
    if (t.tieneAlMenosUnDespachoBodega) return despachoParcial;
    return pendiente;
  }

  /// Estado vigente: el guardado en Firestore o, si no existe, el deducido.
  static String efectivo(TicketEntity t) {
    final guardado = t.estadoDespacho;
    return (guardado != null && valores.contains(guardado)) ? guardado : deducido(t);
  }

  /// El picking ya empezó (permite abrir la ventana de despacho).
  static bool pickingIniciado(TicketEntity t) => efectivo(t) != pendiente;

  static bool puedeIniciarPicking(TicketEntity t) => efectivo(t) == pendiente;

  /// 🛒 En Venta de Repuesto la evidencia (guía firmada) es el último paso,
  /// ya en Entrega: no se exige para pasar a entrega.
  static bool exigeEvidenciaParaFinalizar(TicketEntity t) => t.tipoRequerimiento != TipoRequerimiento.ventaRepuesto;

  /// Todos los repuestos con check (despachados al 100 %) y todas las
  /// entregas con evidencia (salvo en ventas), con el picking abierto.
  static bool puedeFinalizarPicking(TicketEntity t) {
    // Mantenimiento interno con repuestos esperando su código en Costos.
    if (CreacionCodigosMantenimientoService.requiereCreacionCodigos(t)) return false;
    final estado = efectivo(t);
    if (estado != pickingEnCurso && estado != despachoParcial) return false;
    return t.bodegaDespachoCompleto && (!exigeEvidenciaParaFinalizar(t) || !t.tieneDespachoPendienteDeEvidencia);
  }

  /// 🛑 No se despacha más de lo que falta de cada repuesto (evita repetir
  /// una preparación con una lista desactualizada). null = se puede.
  static String? motivoExcesoDespacho(TicketEntity t, List<DetalleItemDespachadoEntity> detalles) {
    String fmt(double v) => v % 1 == 0 ? v.toStringAsFixed(0) : v.toStringAsFixed(2);
    for (final d in detalles) {
      final clave = d.codigo.trim().toUpperCase();
      double faltante = 0;
      var encontrado = false;
      for (final i in t.itemsDespachoBodega) {
        if (i.codigo.trim().toUpperCase() == clave) {
          faltante += i.cantidadFaltante;
          encontrado = true;
        }
      }
      if (!encontrado) continue; // sin referencia: no se bloquea
      if (d.cantidad > faltante + 1e-9) {
        return faltante <= 0
            ? 'El repuesto ${d.codigo} ya fue despachado por completo. Cierre y vuelva a abrir la ventana.'
            : 'Del repuesto ${d.codigo} solo faltan ${fmt(faltante)}. Cierre y vuelva a abrir la ventana.';
      }
    }
    return null;
  }

  /// Motivo por el que aún no se puede finalizar (null si ya se puede).
  static String? motivoNoFinaliza(TicketEntity t) {
    final estado = efectivo(t);
    if (estado == pendiente) return 'Inicie el picking primero.';
    if (estado == pickingFinalizado) return 'El picking ya fue finalizado.';
    if (CreacionCodigosMantenimientoService.requiereCreacionCodigos(t)) {
      return 'Hay repuestos esperando que Costos cree su código.';
    }
    if (!t.bodegaDespachoCompleto) return 'Faltan repuestos por despachar.';
    if (exigeEvidenciaParaFinalizar(t) && t.tieneDespachoPendienteDeEvidencia) return 'Hay despachos sin evidencia.';
    return null;
  }

  /// Porcentaje despachado (cantidades), 0..100.
  static double porcentajeDespachado(TicketEntity t) {
    final items = t.itemsDespachoBodega;
    final solicitado = items.fold<double>(0, (s, i) => s + i.cantidadSolicitada);
    if (solicitado <= 0) return 0;
    final despachado = items.fold<double>(
        0, (s, i) => s + (i.cantidadDespachada > i.cantidadSolicitada ? i.cantidadSolicitada : i.cantidadDespachada));
    return despachado / solicitado * 100;
  }

  /// Bodega ya despachó todos los materiales del ticket (o no tiene
  /// materiales que despachar): condición para poder finalizar el trabajo.
  static bool materialesDespachados(TicketEntity t) {
    if (t.itemsDespachoBodega.isEmpty) return true;
    return efectivo(t) == pickingFinalizado;
  }
}
