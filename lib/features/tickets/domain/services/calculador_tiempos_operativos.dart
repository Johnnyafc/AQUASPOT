// lib/features/tickets/domain/services/calculador_tiempos_operativos.dart

import '../entities/ticket_entity.dart';
import '../entities/item_despacho_bodega_entity.dart';
import '../entities/tiempos_operativos_entity.dart';

class CalculadorTiemposOperativos {
  /// Actualiza las métricas de Compras cuando se guardan validaciones
  static TiemposOperativosEntity actualizarMetricasCompras({
    required TicketEntity ticket,
    required List<ItemDespachoBodegaEntity> items,
    required DateTime timestamp,
  }) {
    final actual = ticket.tiemposOperativos ?? const TiemposOperativosEntity();
    final totalItems = items.length;
    final totalValidados = items.where((i) => i.validadoPorCompras).length;

    final fechaInicio = actual.compras.fechaInicio ??
        (ticket.historialEventos.isNotEmpty
            ? ticket.historialEventos.first.timestamp
            : timestamp);

    final horas = timestamp.difference(fechaInicio).inMinutes / 60.0;
    final tiempoGestion = double.parse(horas.toStringAsFixed(2));

    final bool completa = totalItems > 0 && totalValidados == totalItems;
    final String estadoCompras = totalValidados == 0
        ? 'PENDIENTE'
        : (completa ? 'COMPLETADO' : 'EN_RECEPCION_PARCIAL');

    final String estadoBodega = totalValidados > 0
        ? (actual.subEstados.bodega == 'DESPACHO_TOTAL'
            ? 'DESPACHO_TOTAL'
            : (actual.subEstados.bodega == 'DESPACHO_PARCIAL'
                ? 'DESPACHO_PARCIAL'
                : 'DISPONIBLE_DESPACHO'))
        : 'EN_ESPERA';

    return actual.copyWith(
      subEstados: actual.subEstados.copyWith(
        compras: estadoCompras,
        bodega: estadoBodega,
      ),
      compras: actual.compras.copyWith(
        fechaInicio: fechaInicio,
        fechaFin: completa ? timestamp : actual.compras.fechaFin,
        tiempoGestionHoras: tiempoGestion,
        totalRepuestos: totalItems,
        repuestosValidados: totalValidados,
      ),
    );
  }

  /// Actualiza las métricas de Bodega cuando se despacha un lote
  static TiemposOperativosEntity actualizarMetricasBodega({
    required TicketEntity ticket,
    required List<ItemDespachoBodegaEntity> itemsActualizados,
    required bool esDespachoCompleto,
    required DateTime timestamp,
  }) {
    final actual = ticket.tiemposOperativos ?? const TiemposOperativosEntity();

    final primerDespacho = actual.bodega.fechaPrimerDespacho ?? timestamp;
    final ultimoDespacho = timestamp;

    // Calcular el tiempo neto de reacción de bodega promediando los deltas de ítems despachados
    double tiempoNetoHoras = 0.0;
    int itemsConCalculo = 0;
    for (final item in itemsActualizados) {
      final delta = item.tiempoReaccionBodegaCalculadoHoras;
      if (delta != null && delta >= 0) {
        tiempoNetoHoras += delta;
        itemsConCalculo++;
      }
    }
    final promedioNeto = itemsConCalculo > 0
        ? (tiempoNetoHoras / itemsConCalculo)
        : actual.bodega.tiempoNetoDespachoHoras;

    // Tiempo de espera por Compras = tiempo que Compras tardó en validar
    final esperaCompras = actual.compras.tiempoGestionHoras;

    final estadoBodega = esDespachoCompleto ? 'DESPACHO_TOTAL' : 'DESPACHO_PARCIAL';
    final estadoTaller = esDespachoCompleto ? 'TRABAJO_EN_CURSO' : 'TRABAJO_PARCIAL';

    return actual.copyWith(
      subEstados: actual.subEstados.copyWith(
        bodega: estadoBodega,
        taller: actual.subEstados.taller == 'FINALIZADO'
            ? 'FINALIZADO'
            : estadoTaller,
      ),
      bodega: actual.bodega.copyWith(
        fechaPrimerDespacho: primerDespacho,
        fechaUltimoDespacho: ultimoDespacho,
        tiempoNetoDespachoHoras: double.parse(promedioNeto.toStringAsFixed(2)),
        tiempoEsperaPorComprasHoras: esperaCompras,
        totalLotesDespachados: actual.bodega.totalLotesDespachados + 1,
      ),
    );
  }

  /// Actualiza las métricas de Taller cuando se inicia o se finaliza el trabajo
  static TiemposOperativosEntity registrarInicioTrabajoTaller({
    required TicketEntity ticket,
    required DateTime timestamp,
  }) {
    final actual = ticket.tiemposOperativos ?? const TiemposOperativosEntity();
    return actual.copyWith(
      subEstados: actual.subEstados.copyWith(taller: 'TRABAJO_EN_CURSO'),
      taller: actual.taller.copyWith(
        fechaInicioTrabajo: actual.taller.fechaInicioTrabajo ?? timestamp,
      ),
    );
  }

  static TiemposOperativosEntity registrarFinTrabajoTaller({
    required TicketEntity ticket,
    required DateTime timestamp,
  }) {
    final actual = ticket.tiemposOperativos ?? const TiemposOperativosEntity();
    final inicio = actual.taller.fechaInicioTrabajo ??
        (ticket.historialEventos.isNotEmpty
            ? ticket.historialEventos.first.timestamp
            : timestamp);

    final horas = timestamp.difference(inicio).inMinutes / 60.0;
    final tiempoNeto = double.parse(horas.toStringAsFixed(2));

    // Lead Time Total = desde la creación hasta ahora
    final fechaCreacion = ticket.historialEventos.isNotEmpty
        ? ticket.historialEventos.first.timestamp
        : inicio;
    final leadTimeHoras = double.parse(
        (timestamp.difference(fechaCreacion).inMinutes / 60.0).toStringAsFixed(2));

    // Tiempo de espera por repuestos en taller = Lead Time menos trabajo neto
    final esperaMaterial = (leadTimeHoras - tiempoNeto).clamp(0.0, double.infinity);

    return actual.copyWith(
      leadTimeTotalHoras: leadTimeHoras,
      subEstados: actual.subEstados.copyWith(taller: 'FINALIZADO'),
      taller: actual.taller.copyWith(
        fechaFinTrabajo: timestamp,
        tiempoNetoTrabajoHoras: tiempoNeto,
        tiempoEsperaMaterialHoras: double.parse(esperaMaterial.toStringAsFixed(2)),
      ),
    );
  }
}
