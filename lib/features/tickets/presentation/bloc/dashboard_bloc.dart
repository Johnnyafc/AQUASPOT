// lib/features/tickets/presentation/bloc/dashboard_bloc.dart
//
// 🧠 OPTIMIZACIÓN CLAVE: todo el trabajo pesado del Dashboard (recorrer
// historialEventos de cada ticket, calcular horas por ticket y por
// departamento, armar las listas de filtros) se ejecuta DENTRO de
// `compute()` — es decir, en un isolate (hilo) separado del hilo de la
// interfaz. Así, sin importar cuántos tickets tenga la colección, la app
// NUNCA se congela mientras se calcula el dashboard: la UI sigue
// respondiendo (animaciones, scroll, taps) mientras el cálculo corre en
// paralelo. Cuando termina, el resultado (DashboardDatos, un DTO 100%
// plano) vuelve a la interfaz mediante un evento normal del Bloc.
//
// La pantalla (dashboard_tickets_page.dart) no sabe NADA de TicketEntity
// ni de cómo se calculan estos números: solo consume `DashboardState` a
// través del BlocBuilder. Esa separación es justamente lo que se pidió:
// que el cálculo viva en el Bloc, no en la interfaz.

import 'package:flutter/foundation.dart' show compute;
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/ticket_entity.dart';
import '../../domain/services/documentos_ticket_service.dart';
import '../../domain/services/tiempos_por_proceso_service.dart';
import '../../../../core/enum/ticket_enums.dart';
import 'dashboard_event.dart';
import 'dashboard_state.dart';

class DashboardBloc extends Bloc<DashboardEvent, DashboardState> {
  DashboardBloc() : super(const DashboardState()) {
    on<CargarDashboardEvent>(_alCargar);
  }

  Future<void> _alCargar(CargarDashboardEvent event, Emitter<DashboardState> emit) async {
    emit(state.copyWith(status: DashboardStatus.cargando));
    try {
      // ⚙️ `compute` mueve _procesarDashboardEnHilo a otro isolate y espera
      // el resultado sin bloquear el hilo de la interfaz.
      final datos = await compute(_procesarDashboardEnHilo, event.tickets);
      emit(state.copyWith(status: DashboardStatus.listo, datos: datos));
    } catch (e) {
      emit(state.copyWith(
        status: DashboardStatus.error,
        mensaje: 'No se pudo procesar el dashboard: $e',
      ));
    }
  }
}

// ---------------------------------------------------------------------------
// ⚙️ FUNCIONES DE PROCESAMIENTO
// Deben ser funciones de nivel superior (top-level) — no métodos de clase —
// porque `compute()` las ejecuta en otro isolate, que no tiene acceso al
// estado de esta clase.
// ---------------------------------------------------------------------------

const Map<String, String> _estadoLabelsBloc = {
  'creado': 'Creado',
  'enCamino': 'En camino',
  'recepcionFisica': 'Evaluación Técnica',
  'revisionGarantia': 'Revisión Garantía',
  'cotizandoRepuesto': 'Cotizando repuesto',
  'comercial': 'En cotización',
  'cotizado': 'Proforma enviada',
  'costos': 'Costos',
  'compras': 'Compras',
  'bodega': 'Bodega',
  'procesoTrabajo': 'Proceso de Trabajo',
  'validacionFacturacion': 'Revisión de pagos',
  'entrega': 'Entrega',
  'finalizado': 'Finalizado',
  'anulado': 'Anulado',
};

String _nombreEstadoBloc(EstadoTicket e) => _estadoLabelsBloc[e.name] ?? e.name;

String _bucketEstadoBloc(EstadoTicket estado) {
  switch (estado) {
    case EstadoTicket.finalizado:
      return 'Finalizado';
    case EstadoTicket.anulado:
      return 'Anulado';
    case EstadoTicket.validacionFacturacion:
      return 'Revisión de pagos';
    default:
      return 'En proceso';
  }
}

String _etiquetaTipoRequerimientoBloc(TipoRequerimiento t) {
  switch (t) {
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

String _capBloc(String s) => s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

double _redondear2(double v) => double.parse(v.toStringAsFixed(2));


// Tipo de garantía legible; null si no es "Máquina nueva" ni "Servicio"
// (ej. "pendiente" o "noAplica" en tickets que no son garantía).
String? _etiquetaTipoGarantiaBloc(String? valor) {
  switch ((valor ?? '').trim()) {
    case 'maquinaNueva':
      return 'Máquina nueva';
    case 'servicio':
      return 'Servicio';
    default:
      return null;
  }
}

// Dictamen de un reclamo de garantía:
//  - Aprobada:  ingeniería aprobó la garantía (esGarantia).
//  - Rechazada: tiene la etiqueta de auditoría de la revisión de garantía
//    "GARANTÍA RECHAZADA - PASA A FACTURACIÓN CLIENTE".
//  - Sin dictamen: el resto (aún en revisión).
String? _dictamenGarantiaBloc(TicketEntity t) {
  if (!t.esReclamoDeGarantia) return null;
  if (t.esGarantia == true) return 'Aprobada';
  if (t.historialEventos.any((e) => e.accion.toUpperCase().startsWith('GARANTÍA RECHAZADA'))) return 'Rechazada';
  return 'Sin dictamen';
}

ResumenTicketDash _resumirTicketBloc(TicketEntity t) {
  // Ordenamos una copia (nunca mutamos la lista original del ticket).
  final timestamps = t.historialEventos.map((e) => e.timestamp).toList()..sort();
  final DateTime? primero = timestamps.isEmpty ? null : timestamps.first;
  final DateTime? ultimo = timestamps.isEmpty ? null : timestamps.last;

  // Tiempo total: desde la creación hasta el último registro (en un ticket
  // finalizado, hasta su finalización). Antes se usaba
  // tiemposOperativos.leadTimeTotalHoras, que se cortaba al terminar el
  // taller y dejaba fuera la revisión de pagos y la entrega.
  final horas = (primero != null && ultimo != null) ? ultimo.difference(primero).inMinutes / 60.0 : 0.0;
  final horasRedondeadas = _redondear2(horas);

  return ResumenTicketDash(
    id: t.id,
    clienteId: t.clienteId,
    equipo: t.equipo.name,
    // Sin distinguir mayúsculas: "aquaspot" (tickets viejos) y "AQUASPOT" son la misma marca.
    marca: t.marca.trim().toUpperCase(),
    fallaReportada: t.fallaReportada,
    lugarAtencion: _capBloc(t.lugarAtencion.name),
    sede: t.sede.name,
    tipoGarantia: _etiquetaTipoGarantiaBloc(t.tipoGarantia),
    // Un ticket con dictamen de garantía en la auditoría cuenta como reclamo
    // de garantía aunque su tipo se haya cambiado a mano (ver esReclamoDeGarantia).
    tipoRequerimientoEtiqueta: t.esReclamoDeGarantia
        ? _etiquetaTipoRequerimientoBloc(TipoRequerimiento.reclamoGarantia)
        : _etiquetaTipoRequerimientoBloc(t.tipoRequerimiento),
    esReclamoGarantia: t.esReclamoDeGarantia,
    garantiaAprobada: t.esGarantia == true,
    fechaCreacion: primero,
    fechaActualizacion: ultimo,
    horasTotales: horasRedondeadas,
    diasTotales: _redondear2(horasRedondeadas / 24),
    numPasos: t.historialEventos.length,
    estadoBucket: _bucketEstadoBloc(t.estadoActual),
    estadoNombre: _nombreEstadoBloc(t.estadoActual),
    dictamenGarantia: _dictamenGarantiaBloc(t),
    // 🆕 Documentos agrupados por trámite lógico (ver comentario en el DTO).
    documentos: DocumentosTicketService.porColumna(t),
    diagnosticos: t.diagnosticoFallas
        .map((d) => DiagnosticoFallaDash(
              categoria: d.categoria,
              subcategoria: d.subcategoria,
              falla: d.falla,
              razones: d.razonesProblema,
            ))
        .toList(),
  );
}

// ⏱️ Convierte el historial de UN ticket en el tiempo total que le dedicó
// cada proceso (y cada persona dentro del proceso). Ver
// TiemposPorProcesoService: tickets con etiquetas se miden por carriles
// (paralelismo), los antiguos por el texto de la acción.
List<SegmentoTiempoDash> _segmentosDeTicketBloc(TicketEntity t) {
  return TiemposPorProcesoService.calcular(t.historialEventos).map((x) {
    final rolCrudo = x.usuarioRol.trim();
    return SegmentoTiempoDash(
      ticketId: t.id,
      proceso: x.proceso,
      subproceso: x.subproceso,
      departamento: rolCrudo.isEmpty ? 'SIN ROL' : rolCrudo.toUpperCase(),
      usuarioNombre: x.usuarioNombre,
      horas: _redondear2(x.horas),
    );
  }).toList();
}


List<String> _valoresUnicosBloc(Iterable<String> valores) {
  final set = valores.where((v) => v.isNotEmpty).toSet().toList();
  set.sort();
  return set;
}

// 🚀 Punto de entrada para `compute()`: recibe TODOS los tickets ya
// cargados en memoria (sin ninguna lectura nueva a Firestore) y devuelve
// los DTOs planos listos para pintar el dashboard.
DashboardDatos _procesarDashboardEnHilo(List<TicketEntity> tickets) {
  final resumen = tickets.map(_resumirTicketBloc).toList();

  final segmentos = <SegmentoTiempoDash>[];
  for (final t in tickets) {
    segmentos.addAll(_segmentosDeTicketBloc(t));
  }

  return DashboardDatos(
    resumen: resumen,
    segmentos: segmentos,
    marcas: _valoresUnicosBloc(resumen.map((r) => r.marca)),
    equipos: _valoresUnicosBloc(resumen.map((r) => r.equipo)),
    sedes: _valoresUnicosBloc(resumen.map((r) => r.sede)),
    tiposGarantia: const ['Máquina nueva', 'Servicio'],
    estados: EstadoTicket.values.map(_nombreEstadoBloc).toList(),
  );
}
