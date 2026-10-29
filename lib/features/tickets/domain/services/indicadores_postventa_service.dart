// lib/features/tickets/domain/services/indicadores_postventa_service.dart
//
// 📊 Indicadores de Postventa (botón del Dashboard → Excel). Solo cálculo,
// sin Flutter ni Firebase; probado en test/indicadores_postventa_test.dart.
//
// 1. N.º de servicios técnicos realizados por tipo (taller / campo):
//    tickets que YA TERMINARON Proceso de Trabajo (hoy en Revisión de
//    pagos, Entrega o Finalizado), en el mes en que salieron de él (último
//    evento de Proceso de Trabajo).
// 2. Lead time de atención (taller / campo): tickets FINALIZADOS en el
//    mes, días desde la creación hasta la finalización (igual que "Días
//    promedio" del Dashboard).
// 3. Recurrencia de fallas por sistema y tipo de equipo: el diagnóstico de
//    fallas (categoría = sistema → falla → razones), por mes de CREACIÓN del
//    ticket (igual que el filtro de fechas del Dashboard). Sin anulados.

import '../../../../core/enum/proceso_auditoria.dart';
import '../../../../core/enum/ticket_enums.dart';
import '../entities/ticket_entity.dart';
import 'fallas_por_parte_service.dart';
import 'tiempos_por_proceso_service.dart';

class ServicioRealizado {
  final TicketEntity ticket;
  final DateTime fechaFinTrabajo;
  final String tipo;
  final String lugar;
  final String equipo;

  const ServicioRealizado({
    required this.ticket,
    required this.fechaFinTrabajo,
    required this.tipo,
    required this.lugar,
    required this.equipo,
  });

  DateTime get mes => IndicadoresPostventaService.mesDe(fechaFinTrabajo);
}

/// Indicador adicional: ticket creado en el rango (incluye anulados).
class TicketCreado {
  final TicketEntity ticket;
  final DateTime fechaCreacion;
  final String tipo;
  final String lugar;
  final String estado; // Finalizado / En proceso / Anulado

  const TicketCreado({
    required this.ticket,
    required this.fechaCreacion,
    required this.tipo,
    required this.lugar,
    required this.estado,
  });

  DateTime get mes => IndicadoresPostventaService.mesDe(fechaCreacion);
}

class LeadTimeTicket {
  final TicketEntity ticket;
  final DateTime fechaCreacion;
  final DateTime fechaFinalizacion;
  final String lugar;

  const LeadTimeTicket({
    required this.ticket,
    required this.fechaCreacion,
    required this.fechaFinalizacion,
    required this.lugar,
  });

  double get dias => fechaFinalizacion.difference(fechaCreacion).inMinutes / 1440.0;
  DateTime get mes => IndicadoresPostventaService.mesDe(fechaFinalizacion);
}

class FallaDiagnosticada {
  final TicketEntity ticket;
  final DateTime fechaCreacion;
  final String equipo;
  final String sistema; // categoría de la falla
  final String subcategoria;
  final String falla;
  final List<String> razones; // normalizadas como en el Dashboard (sin repetir)

  const FallaDiagnosticada({
    required this.ticket,
    required this.fechaCreacion,
    required this.equipo,
    required this.sistema,
    required this.subcategoria,
    required this.falla,
    required this.razones,
  });

  DateTime get mes => IndicadoresPostventaService.mesDe(fechaCreacion);
}

/// Resumen de lead time de un grupo (mes × lugar).
class ResumenLeadTime {
  final int tickets;
  final double promedio;
  final double minimo;
  final double maximo;

  const ResumenLeadTime({required this.tickets, required this.promedio, required this.minimo, required this.maximo});

  static ResumenLeadTime? de(Iterable<LeadTimeTicket> lista) {
    final dias = lista.map((l) => l.dias).toList();
    if (dias.isEmpty) return null;
    final suma = dias.fold<double>(0, (s, d) => s + d);
    return ResumenLeadTime(
      tickets: dias.length,
      promedio: suma / dias.length,
      minimo: dias.reduce((a, b) => a < b ? a : b),
      maximo: dias.reduce((a, b) => a > b ? a : b),
    );
  }
}

class IndicadoresPostventa {
  final DateTime desde; // día inicial (incluido)
  final DateTime hasta; // día final (incluido)
  final String? equipo; // null = todos los equipos
  final List<DateTime> meses;
  final List<ServicioRealizado> servicios;
  final List<LeadTimeTicket> leadTimes;
  final List<FallaDiagnosticada> fallas;
  final List<TicketCreado> creados; // indicador adicional

  const IndicadoresPostventa({
    required this.desde,
    required this.hasta,
    this.equipo,
    required this.meses,
    required this.servicios,
    required this.leadTimes,
    required this.fallas,
    this.creados = const [],
  });
}

class IndicadoresPostventaService {
  static const String taller = 'Taller';
  static const String campo = 'Campo';
  static const String sinLugar = 'Sin definir';

  /// Estados de un ticket que ya terminó Proceso de Trabajo.
  static const Set<EstadoTicket> estadosTrabajoTerminado = {
    EstadoTicket.validacionFacturacion,
    EstadoTicket.entrega,
    EstadoTicket.finalizado,
  };

  static const String finalizado = 'Finalizado';
  static const String enProceso = 'En proceso';
  static const String anulado = 'Anulado';

  /// Ventas (de repuesto y de máquina): fuera del indicador adicional,
  /// porque ese flujo todavía no está en funcionamiento.
  static const Set<TipoRequerimiento> tiposVenta = {TipoRequerimiento.ventaRepuesto, TipoRequerimiento.ventaMaquina};

  static String estadoAgrupado(EstadoTicket e) => switch (e) {
        EstadoTicket.finalizado => finalizado,
        EstadoTicket.anulado => anulado,
        _ => enProceso,
      };

  static DateTime mesDe(DateTime d) => DateTime(d.year, d.month);

  /// Meses de [desde] a [hasta] (ambos incluidos).
  static List<DateTime> mesesEntre(DateTime desde, DateTime hasta) {
    final meses = <DateTime>[];
    var m = mesDe(desde);
    final fin = mesDe(hasta);
    while (!m.isAfter(fin)) {
      meses.add(m);
      m = DateTime(m.year, m.month + 1);
    }
    return meses;
  }

  static String etiquetaTipo(TicketEntity t) {
    // Igual que el Dashboard: el dictamen de garantía en la auditoría manda.
    if (t.esReclamoDeGarantia) return 'Reclamo de garantía';
    switch (t.tipoRequerimiento) {
      case TipoRequerimiento.reparacion:
        return 'Reparación regular';
      case TipoRequerimiento.reclamoGarantia:
        return 'Reclamo de garantía';
      case TipoRequerimiento.ventaRepuesto:
        return 'Venta de repuesto';
      case TipoRequerimiento.alquilerPrueba:
        return 'Alquiler / prueba';
      case TipoRequerimiento.ventaMaquina:
        return 'Venta de máquina';
      case TipoRequerimiento.mantenimientoInterno:
        return 'Mantenimiento interno';
      case TipoRequerimiento.ninguno:
        return 'Sin especificar';
    }
  }

  static String etiquetaLugar(LugarAtencion l) => switch (l) {
        LugarAtencion.taller => taller,
        LugarAtencion.campo => campo,
        _ => sinLugar,
      };

  static DateTime? fechaCreacion(TicketEntity t) => t.fechaCreacionTicket;

  /// Fecha de finalización: último registro de un ticket finalizado.
  static DateTime? fechaFinalizacion(TicketEntity t) {
    if (t.estadoActual != EstadoTicket.finalizado || t.historialEventos.isEmpty) return null;
    return t.historialEventos.map((e) => e.timestamp).reduce((a, b) => a.isAfter(b) ? a : b);
  }

  /// Fecha en que el ticket salió de Proceso de Trabajo (último evento de
  /// ese proceso). null si no lo terminó o no tiene eventos de taller.
  static DateTime? fechaFinProcesoTrabajo(TicketEntity t) {
    if (!estadosTrabajoTerminado.contains(t.estadoActual)) return null;
    DateTime? ultimo;
    for (final e in t.historialEventos) {
      final esTaller = e.proceso != null
          ? e.proceso == ProcesoAuditoria.taller
          : TiemposPorProcesoService.procesoPorTexto(e.accion) == TiemposPorProcesoService.taller;
      if (esTaller && (ultimo == null || e.timestamp.isAfter(ultimo))) ultimo = e.timestamp;
    }
    return ultimo;
  }

  /// Razones de una falla como las nombra el Dashboard (las estándar y las
  /// escritas a mano, cada una con su nombre: FallasPorParteService
  /// .etiquetaRazon); sin repetir.
  static List<String> normalizarRazones(List<String> razones) {
    final vistas = <String>{};
    final resultado = <String>[];
    for (final r in razones) {
      final et = FallasPorParteService.etiquetaRazon(r);
      if (et.isNotEmpty && vistas.add(et)) resultado.add(et);
    }
    return resultado;
  }

  /// [desde] y [hasta] son días (ambos incluidos, se ignora la hora).
  /// [equipo] = nombre de TipoEquipo (p. ej. 'Cosechadora'); null = todos.
  static IndicadoresPostventa calcular({
    required List<TicketEntity> tickets,
    required DateTime desde,
    required DateTime hasta,
    String? equipo,
  }) {
    final inicio = DateTime(desde.year, desde.month, desde.day);
    final finExclusivo = DateTime(hasta.year, hasta.month, hasta.day + 1);
    final meses = mesesEntre(inicio, hasta);
    bool dentro(DateTime fecha) => !fecha.isBefore(inicio) && fecha.isBefore(finExclusivo);

    final servicios = <ServicioRealizado>[];
    final leadTimes = <LeadTimeTicket>[];
    final fallas = <FallaDiagnosticada>[];

    final creados = <TicketCreado>[];

    for (final t in tickets) {
      if (equipo != null && t.equipo.name != equipo) continue;
      // Mantenimiento interno (máquinas propias): fuera de los indicadores
      // de servicio al cliente.
      if (t.esMantenimientoInterno) continue;
      final lugar = etiquetaLugar(t.lugarAtencion);

      // Indicador adicional: TODOS los creados en el rango (anulados
      // incluidos, diferenciados por estado), sin ventas.
      final creadoEl = fechaCreacion(t);
      if (creadoEl != null && dentro(creadoEl) && !tiposVenta.contains(t.tipoRequerimiento)) {
        creados.add(TicketCreado(
          ticket: t,
          fechaCreacion: creadoEl,
          tipo: etiquetaTipo(t),
          lugar: lugar,
          estado: estadoAgrupado(t.estadoActual),
        ));
      }

      if (t.estadoActual == EstadoTicket.anulado) continue;

      final finTrabajo = fechaFinProcesoTrabajo(t);
      if (finTrabajo != null && dentro(finTrabajo)) {
        servicios.add(ServicioRealizado(
          ticket: t,
          fechaFinTrabajo: finTrabajo,
          tipo: etiquetaTipo(t),
          lugar: lugar,
          equipo: t.equipo.name,
        ));
      }

      final creacion = fechaCreacion(t);
      final finalizacion = fechaFinalizacion(t);
      if (creacion != null && finalizacion != null && dentro(finalizacion)) {
        leadTimes.add(LeadTimeTicket(
          ticket: t,
          fechaCreacion: creacion,
          fechaFinalizacion: finalizacion,
          lugar: lugar,
        ));
      }

      if (creacion != null && dentro(creacion)) {
        for (final d in t.diagnosticoFallas) {
          if (d.categoria.trim().isEmpty) continue;
          fallas.add(FallaDiagnosticada(
            ticket: t,
            fechaCreacion: creacion,
            equipo: t.equipo.name,
            sistema: d.categoria.trim(),
            subcategoria: d.subcategoria.trim(),
            falla: d.falla.trim(),
            razones: normalizarRazones(d.razonesProblema),
          ));
        }
      }
    }

    return IndicadoresPostventa(
      desde: inicio,
      hasta: DateTime(hasta.year, hasta.month, hasta.day),
      equipo: equipo,
      meses: meses,
      servicios: servicios,
      leadTimes: leadTimes,
      fallas: fallas,
      creados: creados,
    );
  }
}
