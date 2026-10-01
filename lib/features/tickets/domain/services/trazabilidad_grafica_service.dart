// lib/features/tickets/domain/services/trazabilidad_grafica_service.dart
//
// 🧭 LECTOR DE TRAZABILIDAD GRÁFICA
//
// Este servicio NO agrega ningún campo nuevo al ticket ni cambia cómo se
// generan los eventos de auditoría. Solo RE-LEE el mismo `historialEventos`
// que ya se guarda hoy (el que alimenta la tarjeta "Trazabilidad y
// Auditoría") y lo agrupa por proceso de negocio, calculando cuánto duró
// cada uno (cierre - inicio).
//
// La regla confirmada con datos reales: cada texto de auditoría representa
// el CIERRE del proceso que nombra, no la apertura del siguiente. Por eso
// este lector busca, en orden, el evento que cierra cada etapa -- nunca
// compara contra el `estadoActual` que viene después.
//
// Casos especiales confirmados contra el código real de ticket_bloc.dart:
//  - Evaluación Técnica es obligatoria. Revisión de Garantía es OPCIONAL:
//    si no aparece, se pasa directo a Comercial.
//  - Si Garantía se APRUEBA, el ticket salta directo a Costos (sin pasar
//    por Comercial/Cotización, porque el cliente no paga).
//  - Costos y Compras corren EN PARALELO desde el mismo instante (el cierre
//    de Comercial o de Garantía aprobada), pero Compras está bloqueada en
//    la UI hasta que Costos cierra (ver GestionComprasPage.dart).
//  - Bodega normalmente cierra con "BODEGA: DESPACHO TOTAL..." o
//    "BODEGA: REGISTRO DE N EVIDENCIAS...", pero puede saltarse por
//    completo si Compras resuelve "VALIDACIÓN EN BODEGA APROBADA -
//    TRANSFERIDO DIRECTO A PROCESO DE TRABAJO".
//  - Entrega cierra con el segundo de los dos documentos (Guía o Factura,
//    en cualquier orden) -- o, si ambos ya estaban cargados de antes, se
//    salta directo a Finalizado con el texto "...TICKET FINALIZADO.".
//  - Anulación de Ticket puede ocurrir en cualquier punto del flujo.
//
// Si un ticket no encaja en estos patrones (texto no reconocido, flujo
// atípico), el lector simplemente deja de avanzar en ese punto -- nunca
// inventa un cierre. Lo ya reconocido se muestra igual; el resto queda
// disponible sin cambios en la lista cruda de abajo.

import '../entities/evento_auditoria_entity.dart';

/// Un tramo del flujo de negocio ya reconstruido a partir de auditoría real.
class EtapaTrazabilidad {
  final String nombre;
  final DateTime inicio;
  final DateTime? fin; // null = esta etapa sigue abierta ahora mismo
  final EventoAuditoriaEntity? eventoCierre;
  final String? nota;
  final bool paralelo; // true para Costos y Compras
  final String? hitoIntermedio;

  const EtapaTrazabilidad({
    required this.nombre,
    required this.inicio,
    this.fin,
    this.eventoCierre,
    this.nota,
    this.paralelo = false,
    this.hitoIntermedio,
  });

  bool get enCurso => fin == null;

  Duration get duracion => (fin ?? DateTime.now()).difference(inicio);
}

/// Resultado completo para un ticket: sus etapas reconocidas más el marco
/// general (cuándo se creó, cuándo cerró el ciclo si ya cerró).
class ResultadoTrazabilidad {
  final DateTime creacion;
  final List<EtapaTrazabilidad> etapas;
  final DateTime? cierre; // null = el ticket sigue abierto
  final bool anulado;

  const ResultadoTrazabilidad({
    required this.creacion,
    required this.etapas,
    this.cierre,
    this.anulado = false,
  });

  Duration get tiempoTotal => (cierre ?? DateTime.now()).difference(creacion);

  List<EtapaTrazabilidad> get etapasConDuracion =>
      etapas.where((e) => e.nombre != 'Anulado').toList();
}

class TrazabilidadCalculator {
  static ResultadoTrazabilidad? calcular(List<EventoAuditoriaEntity> historial) {
    if (historial.isEmpty) return null;

    final eventos = List<EventoAuditoriaEntity>.from(historial)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    final creacion = eventos.first.timestamp;
    final etapas = <EtapaTrazabilidad>[];

    EventoAuditoriaEntity? anulacion;
    for (final e in eventos) {
      if (e.accion.toUpperCase().contains('ANULACIÓN DE TICKET')) {
        anulacion = e;
        break;
      }
    }

    // Busca, desde `desde` en adelante, el primer evento que cumpla `test`.
    // Si hay una anulación, nunca busca más allá de su marca de tiempo.
    EventoAuditoriaEntity? buscar(
      DateTime desde,
      bool Function(String texto) test, {
      bool Function(String texto)? excluir,
    }) {
      for (final e in eventos) {
        if (e.timestamp.isBefore(desde)) continue;
        if (anulacion != null && !e.timestamp.isBefore(anulacion.timestamp)) break;
        final texto = e.accion.toUpperCase();
        if (excluir != null && excluir(texto)) continue;
        if (test(texto)) return e;
      }
      return null;
    }

    // Cierra la reconstrucción en el punto en que nos quedamos: si hay una
    // anulación pendiente, la registra como etapa final; si no, deja la
    // etapa actual marcada "en curso" (el ticket sigue vivo en ese proceso).
    ResultadoTrazabilidad detener(DateTime cursor, String etapaEnCurso, {bool paralelo = false}) {
      if (anulacion != null) {
        etapas.add(EtapaTrazabilidad(
          nombre: 'Anulado',
          inicio: cursor,
          fin: anulacion.timestamp,
          eventoCierre: anulacion,
        ));
        return ResultadoTrazabilidad(creacion: creacion, etapas: etapas, cierre: anulacion.timestamp, anulado: true);
      }
      etapas.add(EtapaTrazabilidad(nombre: etapaEnCurso, inicio: cursor, paralelo: paralelo));
      return ResultadoTrazabilidad(creacion: creacion, etapas: etapas, cierre: null, anulado: false);
    }

    DateTime cursor = creacion;

    // 1. En Camino -> cierra con la recepción física (local o remota).
    final cierreCamino = buscar(cursor, (t) => t.contains('RECEPCIÓN FÍSICA') || t.contains('RECIBIDO EN TALLER'));
    if (cierreCamino == null) return detener(cursor, 'En Camino');
    etapas.add(EtapaTrazabilidad(nombre: 'En Camino', inicio: cursor, fin: cierreCamino.timestamp, eventoCierre: cierreCamino));
    cursor = cierreCamino.timestamp;

    // 2. Evaluación Técnica -> siempre ocurre.
    final cierreEval = buscar(cursor, (t) => t.contains('EVALUACIÓN TÉCNICA Y DOCUMENTAL'));
    if (cierreEval == null) return detener(cursor, 'Evaluación Técnica');
    etapas.add(EtapaTrazabilidad(nombre: 'Evaluación Técnica', inicio: cursor, fin: cierreEval.timestamp, eventoCierre: cierreEval));
    cursor = cierreEval.timestamp;

    // 3. Revisión de Garantía -> OPCIONAL.
    bool garantiaAprobada = false;
    final cierreGarantia = buscar(cursor, (t) => t.contains('GARANTÍA APROBADA') || t.contains('GARANTÍA RECHAZADA'));
    if (cierreGarantia != null) {
      garantiaAprobada = cierreGarantia.accion.toUpperCase().contains('APROBADA');
      etapas.add(EtapaTrazabilidad(nombre: 'Revisión de Garantía', inicio: cursor, fin: cierreGarantia.timestamp, eventoCierre: cierreGarantia));
      cursor = cierreGarantia.timestamp;
    }

    // 4. Comercial -> se SALTA si la garantía fue aprobada.
    if (!(cierreGarantia != null && garantiaAprobada)) {
      final cierreComercial = buscar(cursor, (t) => t.contains('APROBACIÓN COMERCIAL'));
      if (cierreComercial == null) return detener(cursor, 'Comercial');
      final cotizacion = buscar(cursor, (t) => t.contains('COTIZACIÓN GENERADA'));
      etapas.add(EtapaTrazabilidad(
        nombre: 'Comercial',
        inicio: cursor,
        fin: cierreComercial.timestamp,
        eventoCierre: cierreComercial,
        hitoIntermedio: cotizacion != null ? 'Cotización generada' : null,
      ));
      cursor = cierreComercial.timestamp;
    }

    final inicioParalelo = cursor;

    // 5. Costos + Compras -> EN PARALELO desde el mismo instante.
    final cierreCostos = buscar(inicioParalelo, (t) => t.contains('FASE COSTOS'));
    final cierreCompras = buscar(
      inicioParalelo,
      (t) =>
          t.contains('COMPRAS LIBERADAS') ||
          t.contains('ÓRDENES DE COMPRA') ||
          (t.contains('COMPRAS:') && t.contains('VALIDACIÓN')),
      excluir: (t) => t.contains('PARCIAL'),
    );

    if (cierreCostos == null && cierreCompras == null) {
      return detener(inicioParalelo, 'Costos / Compras', paralelo: true);
    }

    if (anulacion != null && (cierreCostos == null || cierreCompras == null)) {
      // La anulación ocurrió mientras Costos y Compras aún corrían: no
      // intentamos adivinar cuál iba más avanzado, solo marcamos el tramo.
      return detener(inicioParalelo, 'Costos / Compras', paralelo: true);
    }

    bool saltoDirectoATaller = false;
    if (cierreCostos != null) {
      etapas.add(EtapaTrazabilidad(nombre: 'Costos', inicio: inicioParalelo, fin: cierreCostos.timestamp, eventoCierre: cierreCostos, paralelo: true));
    } else {
      etapas.add(EtapaTrazabilidad(nombre: 'Costos', inicio: inicioParalelo, paralelo: true));
    }
    if (cierreCompras != null) {
      String? nota;
      if (cierreCostos != null && cierreCompras.timestamp.isAfter(cierreCostos.timestamp)) {
        nota = 'Esperó a Costos: ${_formatDuracion(cierreCompras.timestamp.difference(cierreCostos.timestamp))}';
      }
      etapas.add(EtapaTrazabilidad(nombre: 'Compras', inicio: inicioParalelo, fin: cierreCompras.timestamp, eventoCierre: cierreCompras, paralelo: true, nota: nota));
      saltoDirectoATaller = cierreCompras.accion.toUpperCase().contains('TRANSFERIDO DIRECTO A PROCESO DE TRABAJO');
    } else {
      etapas.add(EtapaTrazabilidad(
        nombre: 'Compras',
        inicio: inicioParalelo,
        paralelo: true,
        nota: cierreCostos != null ? 'Bloqueada esperando a Costos.' : null,
      ));
    }

    if (cierreCostos == null || cierreCompras == null) {
      return ResultadoTrazabilidad(creacion: creacion, etapas: etapas, cierre: null, anulado: false);
    }

    final finesParalelo = [cierreCostos.timestamp, cierreCompras.timestamp];
    final inicioBodega = finesParalelo.reduce((a, b) => a.isAfter(b) ? a : b);
    cursor = inicioBodega;

    // 6. Bodega -> se SALTA si Compras ya transfirió directo a Taller.
    DateTime inicioTaller;
    if (saltoDirectoATaller) {
      inicioTaller = cursor;
    } else {
      final cierreBodega = buscar(
        cursor,
        (t) =>
            t.contains('BODEGA') &&
            (t.contains('TRANSFERENCIA A PROCESO DE TRABAJO') ||
                t.contains('DESPACHO TOTAL') ||
                (t.contains('REGISTRO DE') && t.contains('EVIDENCIAS'))),
        excluir: (t) => t.contains('PARCIAL') || t.contains('PENDIENTE DE EVIDENCIAS'),
      );
      if (cierreBodega == null) return detener(cursor, 'Bodega');
      etapas.add(EtapaTrazabilidad(nombre: 'Bodega', inicio: cursor, fin: cierreBodega.timestamp, eventoCierre: cierreBodega));
      inicioTaller = cierreBodega.timestamp;
    }
    cursor = inicioTaller;

    // 7. Proceso de Trabajo (Taller).
    final cierreTaller = buscar(cursor, (t) => t.contains('TALLER: EVIDENCIA REGISTRADA'));
    if (cierreTaller == null) return detener(cursor, 'Proceso de Trabajo');
    etapas.add(EtapaTrazabilidad(nombre: 'Proceso de Trabajo', inicio: cursor, fin: cierreTaller.timestamp, eventoCierre: cierreTaller));
    cursor = cierreTaller.timestamp;

    // 8. Validación Facturación.
    final cierreFacturacion = buscar(cursor, (t) => t.contains('REVISIÓN COMERCIAL COMPLETADA'));
    if (cierreFacturacion == null) return detener(cursor, 'Validación Facturación');
    etapas.add(EtapaTrazabilidad(nombre: 'Validación Facturación', inicio: cursor, fin: cierreFacturacion.timestamp, eventoCierre: cierreFacturacion));
    cursor = cierreFacturacion.timestamp;

    final cruceAutomatico = cierreFacturacion.accion.toUpperCase().contains('TICKET FINALIZADO');
    if (cruceAutomatico) {
      // Guía y Factura ya estaban cargadas antes: Entrega y Finalizado
      // ocurren en el mismo instante que el cierre de Facturación.
      etapas.add(EtapaTrazabilidad(
        nombre: 'Entrega',
        inicio: cursor,
        fin: cursor,
        eventoCierre: cierreFacturacion,
        nota: 'Guía y Factura ya estaban cargadas — cierre automático.',
      ));
      return ResultadoTrazabilidad(creacion: creacion, etapas: etapas, cierre: cursor, anulado: false);
    }

    // 9. Entrega -> Guía y Factura en cualquier orden; el segundo cierra.
    final documentos = eventos.where((e) {
      if (e.timestamp.isBefore(cursor)) return false;
      if (anulacion != null && !e.timestamp.isBefore(anulacion.timestamp)) return false;
      final t = e.accion.toUpperCase();
      return t.contains('CARGA DE GUÍA') || t.contains('CARGA DE FACTURA');
    }).toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    if (documentos.length < 2) return detener(cursor, 'Entrega');

    final cierreEntrega = documentos.last;
    etapas.add(EtapaTrazabilidad(
      nombre: 'Entrega',
      inicio: cursor,
      fin: cierreEntrega.timestamp,
      eventoCierre: cierreEntrega,
      nota: 'Guía y Factura pueden subirse en cualquier orden.',
    ));

    return ResultadoTrazabilidad(creacion: creacion, etapas: etapas, cierre: cierreEntrega.timestamp, anulado: false);
  }

  static String _formatDuracion(Duration d) {
    if (d.inMinutes < 60) return '${d.inMinutes}min';
    final dias = d.inHours ~/ 24;
    final horas = d.inHours % 24;
    if (dias > 0) return horas > 0 ? '${dias}d ${horas}h' : '${dias}d';
    return '${d.inHours}h';
  }
}
