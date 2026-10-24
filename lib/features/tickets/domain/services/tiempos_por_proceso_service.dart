// lib/features/tickets/domain/services/tiempos_por_proceso_service.dart
//
// ⏱️ Tiempo que cada PROCESO del flujo le dedicó a UN ticket, para el
// dashboard "Tiempo promedio por proceso". Devuelve, por ticket, el total
// de horas de cada proceso (y de cada persona dentro del proceso); el
// dashboard luego promedia ENTRE TICKETS (cada ticket cuenta una sola vez
// por proceso, sin importar cuántos eventos registró).
//
// Algunos procesos agrupan varias partes y se pueden desplegar en el
// dashboard (ver `subprocesos`): cada tramo lleva además su `subproceso`, y
// las partes de un proceso suman exactamente su total.
//
// Despacho (carril de Bodega) se parte en: "Antes del picking" (desde que
// le habilitan el ticket hasta "BODEGA: INICIO DE PICKING"), "Picking"
// (hasta el fin de Bodega) y "Validación simple" (tickets que Bodega cierra
// con la validación simple, sin picking). Sin "INICIO DE PICKING" (tickets
// anteriores al picking) todo va en "Antes del picking".
//
// Dos formas de medir, según cómo se creó el ticket:
//
// 1. Tickets con etiquetas (su evento de creación tiene `proceso`): cada
//    proceso se mide en su propio carril, desde la acción que lo HABILITÓ
//    (o su propio INICIO) hasta su FIN. Así Compras, Validación Bodega,
//    Despacho y Taller se miden bien aunque trabajen en paralelo. Si un
//    proceso se repite (ej. Comercial recotiza tras una modificación), se
//    suman los ciclos.
//
// 2. Tickets antiguos (sin etiquetas): el tramo entre dos eventos seguidos
//    se asigna al proceso del evento de llegada, clasificado por el texto
//    de la acción (mismo criterio que antes, con correcciones de lectura).
//    No se modifica nada en Firestore.

import '../../../../core/enum/proceso_auditoria.dart';
import '../entities/evento_auditoria_entity.dart';

/// Horas de un proceso (o de una parte de él) en un ticket, atribuidas a
/// una persona.
class TiempoProcesoTicket {
  final String proceso;        // Nombre de la barra del dashboard
  final String? subproceso;    // Parte del proceso (null si no se desglosa)
  final String usuarioNombre;
  final String usuarioRol;
  final double horas;

  const TiempoProcesoTicket({
    required this.proceso,
    this.subproceso,
    required this.usuarioNombre,
    required this.usuarioRol,
    required this.horas,
  });
}

class TiemposPorProcesoService {
  static const String etiquetaSinClasificar = 'Sin clasificar';
  static const String etiquetaOtro = 'Otro';

  static const String recepcion = 'Recepción';
  static const String compras = 'Compras';
  static const String despacho = 'Despacho';
  static const String taller = 'Proceso de Trabajo';

  static const String subRegistro = 'Registro y acta';
  static const String subEnCamino = 'En camino (Guabo)';
  static const String subAntesDeIniciar = 'Antes de iniciar';
  static const String subEsperaMaterial = 'Espera de material';
  static const String subTrabajo = 'Trabajo';
  static const String subAntesPicking = 'Antes del picking';
  static const String subPicking = 'Picking';
  static const String subValidacionSimple = 'Validación simple';

  /// Procesos que se pueden desplegar y el orden de sus partes.
  static const Map<String, List<String>> subprocesos = {
    recepcion: [subRegistro, subEnCamino],
    despacho: [subAntesPicking, subPicking, subValidacionSimple],
    taller: [subAntesDeIniciar, subEsperaMaterial, subTrabajo],
  };

  /// true si el ticket se creó con etiquetas (se mide por carriles).
  static bool usaEtiquetas(List<EventoAuditoriaEntity> historial) {
    if (historial.isEmpty) return false;
    final primero = [...historial]..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return primero.first.proceso != null;
  }

  /// Total de horas por (proceso, parte, persona) dentro de un ticket.
  static List<TiempoProcesoTicket> calcular(List<EventoAuditoriaEntity> historial) {
    if (historial.length < 2) return const [];
    final eventos = [...historial]..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    final acumulado = <String, _Acumulado>{};

    // Los tramos de 0 minutos (acciones registradas en el mismo minuto) SÍ
    // cuentan: el ticket pasó por ese proceso, solo que al instante. Así
    // todos los tickets entran en los procesos por los que pasaron. Un
    // tramo negativo (fechas inconsistentes) cuenta como 0.
    void sumar(String proceso, EventoAuditoriaEntity e, DateTime desde, DateTime hasta) {
      final minutos = hasta.difference(desde).inMinutes;
      final horas = minutos < 0 ? 0.0 : minutos / 60.0;
      final sub = subprocesoPorTexto(proceso, e.accion);
      final clave = '$proceso|${sub ?? ''}|${e.usuarioNombre}';
      acumulado.putIfAbsent(clave, () => _Acumulado(proceso, sub, e.usuarioNombre, e.usuarioRol)).horas += horas;
    }

    // Partes del taller (antes de iniciar / espera / trabajo): una parte en
    // 0 no se registra (no ocurrió), salvo `forzar` para que el ticket
    // cuente en el proceso aunque todo el taller haya durado 0.
    void sumarParte(String proceso, String sub, EventoAuditoriaEntity e, DateTime desde, DateTime hasta, {bool forzar = false}) {
      final minutos = hasta.difference(desde).inMinutes;
      final horas = minutos < 0 ? 0.0 : minutos / 60.0;
      if (horas <= 0 && !forzar) return;
      final clave = '$proceso|$sub|${e.usuarioNombre}';
      acumulado.putIfAbsent(clave, () => _Acumulado(proceso, sub, e.usuarioNombre, e.usuarioRol)).horas += horas;
    }

    if (usaEtiquetas(eventos)) {
      _calcularPorCarriles(eventos, sumar, sumarParte);
    } else {
      _calcularSecuencial(eventos, sumar);
    }

    return acumulado.values
        .map((a) => TiempoProcesoTicket(
              proceso: a.proceso,
              subproceso: a.subproceso,
              usuarioNombre: a.usuarioNombre,
              usuarioRol: a.usuarioRol,
              horas: double.parse(a.horas.toStringAsFixed(2)),
            ))
        .toList();
  }

  // ---------------------------------------------------------------------------
  // 1. Carriles (tickets con etiquetas)
  // ---------------------------------------------------------------------------
  static void _calcularPorCarriles(
    List<EventoAuditoriaEntity> eventos,
    void Function(String proceso, EventoAuditoriaEntity e, DateTime desde, DateTime hasta) sumar,
    void Function(String proceso, String sub, EventoAuditoriaEntity e, DateTime desde, DateTime hasta, {bool forzar}) sumarParte,
  ) {
    final abiertos = <ProcesoAuditoria, DateTime>{};
    // Aperturas provisionales: Costos deja visible el ticket en Despacho,
    // pero solo cuenta desde ahí si Bodega actúa antes de que otro proceso
    // le habilite trabajo (repuestos que ya estaban en stock).
    final provisionales = <ProcesoAuditoria>{};
    DateTime? anterior;
    DateTime? inicioTaller;        // "Iniciar trabajo" del ciclo de taller en curso
    DateTime? ultimoFinBodega;     // último despacho total (fin de la espera de material)
    DateTime? inicioPicking;       // "BODEGA: INICIO DE PICKING" del ciclo de Bodega en curso

    for (final e in eventos) {
      final p = e.proceso;
      if (p == null) {
        // Evento sin etiqueta en un ticket nuevo: se hace visible como
        // "Sin clasificar" (tramo desde el evento anterior).
        if (anterior != null) sumar(etiquetaSinClasificar, e, anterior, e.timestamp);
        anterior = e.timestamp;
        continue;
      }

      // Cambio forzado por el administrador: el reloj de todas las etapas
      // abiertas se reinicia; solo cuenta la etapa destino (vía `habilita`).
      if (p == ProcesoAuditoria.admin) {
        abiertos.clear();
        provisionales.clear();
        inicioTaller = null;
        inicioPicking = null;
      }

      // Una acción propia del proceso confirma su apertura provisional.
      provisionales.remove(p);
      final etiqueta = p.etiquetaDashboard;

      if (p == ProcesoAuditoria.bodega && e.accion.toUpperCase().startsWith('BODEGA: INICIO DE PICKING')) {
        inicioPicking ??= e.timestamp;
      }

      if (e.hito == HitoProceso.inicio) {
        abiertos.putIfAbsent(p, () => e.timestamp);
        if (p == ProcesoAuditoria.taller) inicioTaller ??= e.timestamp;
      } else if (e.hito == HitoProceso.avance && p == ProcesoAuditoria.recepcion && abiertos.containsKey(p)) {
        // Recepción se parte en sus etapas (ej. acta en El Guabo -> en camino).
        if (etiqueta != null) sumar(etiqueta, e, abiertos[p]!, e.timestamp);
        abiertos[p] = e.timestamp;
      } else if (e.hito == HitoProceso.fin) {
        final desde = abiertos.remove(p) ?? anterior;
        if (desde != null && etiqueta != null) {
          if (p == ProcesoAuditoria.taller) {
            // Taller = antes de iniciar + espera de material + trabajo.
            final inicio = (inicioTaller != null && inicioTaller.isAfter(desde)) ? inicioTaller : desde;
            sumarParte(etiqueta, subAntesDeIniciar, e, desde, inicio);
            var finEspera = inicio;
            if (ultimoFinBodega != null && ultimoFinBodega.isAfter(inicio)) {
              finEspera = ultimoFinBodega.isBefore(e.timestamp) ? ultimoFinBodega : e.timestamp;
            }
            sumarParte(etiqueta, subEsperaMaterial, e, inicio, finEspera);
            sumarParte(etiqueta, subTrabajo, e, finEspera, e.timestamp,
                forzar: !e.timestamp.isAfter(desde)); // taller de 0 minutos: igual cuenta
            inicioTaller = null;
          } else if (p == ProcesoAuditoria.bodega) {
            // Despacho = antes del picking + picking, o validación simple.
            // La última parte se fuerza para que el ticket cuente en
            // Despacho aunque el tramo haya durado 0.
            if (e.accion.toUpperCase().contains('VALIDACIÓN SIMPLE')) {
              sumarParte(etiqueta, subValidacionSimple, e, desde, e.timestamp, forzar: true);
            } else if (inicioPicking != null) {
              final inicio = inicioPicking.isAfter(desde) ? inicioPicking : desde;
              sumarParte(etiqueta, subAntesPicking, e, desde, inicio);
              sumarParte(etiqueta, subPicking, e, inicio, e.timestamp, forzar: true);
            } else {
              sumarParte(etiqueta, subAntesPicking, e, desde, e.timestamp, forzar: true);
            }
            inicioPicking = null;
          } else {
            sumar(etiqueta, e, desde, e.timestamp);
          }
        }
        if (p == ProcesoAuditoria.bodega) ultimoFinBodega = e.timestamp;
      }

      for (final h in e.habilita) {
        if (!abiertos.containsKey(h)) {
          abiertos[h] = e.timestamp;
          if (p == ProcesoAuditoria.costos) provisionales.add(h);
        } else if (provisionales.remove(h)) {
          // Estaba abierto solo provisionalmente y el proceso no actuó:
          // empieza a contar desde esta habilitación real.
          abiertos[h] = e.timestamp;
        }
      }

      anterior = e.timestamp;
    }
  }

  // ---------------------------------------------------------------------------
  // 2. Secuencial (tickets antiguos, clasificados por texto)
  // ---------------------------------------------------------------------------
  static void _calcularSecuencial(
    List<EventoAuditoriaEntity> eventos,
    void Function(String proceso, EventoAuditoriaEntity e, DateTime desde, DateTime hasta) sumar,
  ) {
    for (var i = 1; i < eventos.length; i++) {
      final proceso = procesoPorTexto(eventos[i].accion);
      if (proceso != null) sumar(proceso, eventos[i], eventos[i - 1].timestamp, eventos[i].timestamp);
    }
  }

  /// Parte del proceso a la que pertenece el tramo que termina en esta
  /// acción. null = el proceso no se desglosa.
  static String? subprocesoPorTexto(String proceso, String accion) {
    final a = accion.toUpperCase();
    switch (proceso) {
      case recepcion:
        return a.contains('GUABO') ? subEnCamino : subRegistro;
      case despacho:
        if (a.contains('VALIDACIÓN SIMPLE')) return subValidacionSimple;
        if (a.contains('PICKING') && !a.startsWith('BODEGA: INICIO DE PICKING')) return subPicking;
        return subAntesPicking;
      case taller:
        // Texto anterior y nuevo (con prefijo "TALLER: ").
        if (a.startsWith('INICIO DE TRABAJO') || a.startsWith('TALLER: INICIO DE TRABAJO')) return subAntesDeIniciar;
        if (a.startsWith('TALLER: ORDEN') || a.startsWith('TALLER: REPUESTOS') || a.startsWith('TALLER: CONFORMIDAD')) {
          return subEsperaMaterial;
        }
        return subTrabajo;
    }
    return null;
  }

  /// Clasifica una acción antigua por su texto. null = fuera de los promedios.
  /// ⚠️ El orden de los checks importa (una acción puede mencionar varias
  /// palabras clave).
  static String? procesoPorTexto(String accion) {
    final a = accion.toUpperCase();
    if (a.startsWith('ADMIN:')) return null;
    if (a.contains('GUABO')) return recepcion;
    if (a.startsWith('SUPERVISOR DECLAR') || a.startsWith('SUPERVISOR RESTABLEC')) return 'Evaluación Técnica';
    if (a.contains('COTIZACIÓN DE REPUESTO') || a.contains('REPUESTO SIN STOCK')) return compras;
    if (a.contains('GARANT')) return 'Revisión Garantía';
    if (a.contains('RECEP')) return recepcion;
    if (a.contains('EVALUACI')) return 'Evaluación Técnica';
    if (a.startsWith('APROBACIÓN COMERCIAL') || a.startsWith('SOLICITUD DE MODIFICACI')) return 'Proforma enviada';
    if (a.startsWith('REVISIÓN COMERCIAL COMPLETADA')) return 'Revisión de pagos';
    if (a.contains('COTIZA') || a.contains('COMERCIAL')) return 'En cotización';
    if (a.contains('COSTO')) return 'Costos';
    // Flujo antiguo (antes del 16/09): la bandeja de Validación Bodega abría
    // la "Estación Bodega", que registraba esta acción.
    if (a.startsWith('ORDEN DE COMPRA VALIDADA EN BODEGA')) return 'Validación Bodega';
    if (a.contains('COMPRA') && (a.contains('VALIDACI') || a.contains('VALIDADA'))) return 'Validación Bodega';
    if (a.contains('COMPRA')) return compras;
    if (a.startsWith('TALLER:') || a.startsWith('INFORME TÉCNICO') || a.startsWith('TÉCNICOS ASIGNADOS')) return taller;
    if (a.contains('BODEGA') || a.contains('DESPACHO')) return 'Despacho';
    if (a.contains('TALLER') || a.contains('TRABAJO')) return taller;
    if (a.contains('FACTURA') || a.contains('ENTREGA') || a.contains('GUÍA') || a.contains('GUIA')) return 'Entrega';
    if (a.startsWith('ANULACI')) return null;
    return etiquetaOtro;
  }
}

class _Acumulado {
  final String proceso;
  final String? subproceso;
  final String usuarioNombre;
  final String usuarioRol;
  double horas = 0;
  _Acumulado(this.proceso, this.subproceso, this.usuarioNombre, this.usuarioRol);
}
