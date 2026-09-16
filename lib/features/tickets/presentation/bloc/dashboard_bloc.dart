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
  'recepcionFisica': 'Evaluación técnica',
  'revisionGarantia': 'Revisión garantía',
  'comercial': 'Comercial',
  'cotizado': 'Cotizado',
  'costos': 'Costos',
  'compras': 'Compras',
  'bodega': 'Bodega',
  'procesoTrabajo': 'Proceso de trabajo',
  'validacionFacturacion': 'Revisión de pagos',
  'entrega': 'Entrega',
  'finalizado': 'Finalizado',
  'anulado': 'Anulado',
};

String _nombreEstadoBloc(EstadoTicket e) => _estadoLabelsBloc[e.name] ?? e.name;

String _bucketEstadoBloc(EstadoTicket estado) {
  switch (estado) {
    case EstadoTicket.finalizado:
      return 'Cerrado';
    case EstadoTicket.anulado:
      return 'Anulado';
    case EstadoTicket.validacionFacturacion:
      return 'Validación facturación';
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
    case TipoRequerimiento.ninguno:
      return 'Sin especificar';
  }
}

String _capBloc(String s) => s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

double _redondear2(double v) => double.parse(v.toStringAsFixed(2));

// 🆕 Filtra nulos/vacíos y junta varias fuentes de URLs en una sola lista
// plana — así cada grupo documental queda listo para la tabla del
// Dashboard sin importar cuántas variables crudas lo componen.
List<String> _urls(Iterable<String?> fuentes) =>
    fuentes.where((u) => u != null && u.trim().isNotEmpty).map((u) => u!.trim()).toList();

ResumenTicketDash _resumirTicketBloc(TicketEntity t) {
  // Ordenamos una copia (nunca mutamos la lista original del ticket).
  final timestamps = t.historialEventos.map((e) => e.timestamp).toList()..sort();
  final DateTime? primero = timestamps.isEmpty ? null : timestamps.first;
  final DateTime? ultimo = timestamps.isEmpty ? null : timestamps.last;

  double horas = 0;
  if (t.tiemposOperativos != null && t.tiemposOperativos!.leadTimeTotalHoras > 0) {
    horas = t.tiemposOperativos!.leadTimeTotalHoras;
  } else if (primero != null && ultimo != null) {
    horas = ultimo.difference(primero).inMinutes / 60.0;
  }
  final horasRedondeadas = _redondear2(horas);

  final to = t.tiemposOperativos;

  return ResumenTicketDash(
    id: t.id,
    clienteId: t.clienteId,
    equipo: t.equipo.name,
    marca: t.marca,
    fallaReportada: t.fallaReportada,
    lugarAtencion: _capBloc(t.lugarAtencion.name),
    sede: t.sede.name,
    tipoGarantia: t.tipoGarantia,
    tipoRequerimientoEtiqueta: _etiquetaTipoRequerimientoBloc(t.tipoRequerimiento),
    esReclamoGarantia: t.tipoRequerimiento == TipoRequerimiento.reclamoGarantia,
    fechaCreacion: primero,
    fechaActualizacion: ultimo,
    horasTotales: horasRedondeadas,
    diasTotales: _redondear2(horasRedondeadas / 24),
    numPasos: t.historialEventos.length,
    estadoBucket: _bucketEstadoBloc(t.estadoActual),
    estadoNombre: _nombreEstadoBloc(t.estadoActual),
    horasNetasCompras: to?.compras.tiempoGestionHoras,
    horasNetasBodega: to?.bodega.tiempoNetoDespachoHoras,
    horasEsperaBodega: to?.bodega.tiempoEsperaPorComprasHoras,
    horasNetasTaller: to?.taller.tiempoNetoTrabajoHoras,
    horasEsperaTaller: to?.taller.tiempoEsperaMaterialHoras,
    subEstadoCompras: to?.subEstados.compras,
    subEstadoBodega: to?.subEstados.bodega,
    subEstadoTaller: to?.subEstados.taller,
    // 🆕 Documentos agrupados por trámite lógico (ver comentario en el DTO).
    documentosActa: _urls([t.pdfActaUrl, ...t.fotosUrls]),
    documentosEvaluacion: _urls([
      t.evaluacionTecnica?.urlProformaExcel,
      ...?t.evaluacionTecnica?.urlsAdjuntosPdf,
      ...?t.evaluacionTecnica?.urlsAdjuntosPdfGarantia,
    ]),
    documentosProforma: _urls([
      ...?t.proforma?.pdfUrls,
      ...?t.proforma?.excelUrls,
    ]),
    documentosCompras: _urls([...?t.gestionCompras?.urlsOrdenCompra]),
    documentosEvidenciaTrabajo: _urls([
      ...t.procesoTrabajoUrls,
      ...?t.evidenciaTrabajo?.fotosUrls,
      ...?t.evidenciaTrabajo?.videosUrls,
    ]),
    documentosEntrega: _urls([t.urlGuiaRemision, t.urlFactura]),
    documentosGarantia: _urls([...?t.urlsEvidenciasGarantia]),
  );
}

// 🆕 Etiqueta del segmento operativo (CARACOL / COSECHADORA / CONTADOR /
// GENERAL) a partir del tipo de equipo del ticket — así se puede separar
// el tiempo de un departamento que atiende varios tipos de equipo (ej.
// SUPERVISOR) por cada uno, en vez de un solo promedio mezclado.
String _segmentoOperativoLabelBloc(TipoEquipo equipo) {
  switch (equipo) {
    case TipoEquipo.Caracol:
      return 'CARACOL';
    case TipoEquipo.Cosechadora:
      return 'COSECHADORA';
    case TipoEquipo.Contador:
      return 'CONTADOR';
    case TipoEquipo.Otros:
      return 'GENERAL';
  }
}

// ⏱️ Convierte el historial de UN ticket en "segmentos" de tiempo: uno por
// cada paso (a partir del segundo), con la duración desde el paso anterior,
// el departamento (usuarioRol) responsable de ese paso y el segmento
// operativo (tipo de equipo) del ticket.
List<SegmentoTiempoDash> _segmentosDeTicketBloc(TicketEntity t) {
  if (t.historialEventos.length < 2) return const [];

  final segmentoOperativo = _segmentoOperativoLabelBloc(t.equipo);
  final eventos = [...t.historialEventos]..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  final segmentos = <SegmentoTiempoDash>[];
  for (var i = 1; i < eventos.length; i++) {
    final anterior = eventos[i - 1];
    final actual = eventos[i];
    final horas = actual.timestamp.difference(anterior.timestamp).inMinutes / 60.0;
    final rolCrudo = actual.usuarioRol.trim();
    final departamento = rolCrudo.isEmpty ? 'SIN ROL' : rolCrudo.toUpperCase();
    segmentos.add(SegmentoTiempoDash(
      ticketId: t.id,
      accion: actual.accion,
      departamento: departamento,
      usuarioNombre: actual.usuarioNombre,
      horas: _redondear2(horas),
      segmentoOperativo: segmentoOperativo,
    ));
  }
  return segmentos;
}


List<ResumenRepuestoDash> _calcularRankingRepuestosBloc(List<TicketEntity> tickets) {
  final Map<String, List<Map<String, dynamic>>> agrupados = {};

  for (final t in tickets) {
    for (final item in t.itemsDespachoBodega) {
      final cod = item.codigo.trim().toUpperCase();
      if (cod.isEmpty) continue;
      agrupados.putIfAbsent(cod, () => []).add({
        'desc': item.descripcion,
        'solicitada': item.cantidadSolicitada,
        'despachada': item.cantidadDespachada,
        'horasCompras': item.tiempoAbastecimientoCalculadoHoras,
        'horasBodega': item.tiempoReaccionBodegaCalculadoHoras,
      });
    }
  }

  final ranking = <ResumenRepuestoDash>[];

  agrupados.forEach((cod, lista) {
    final desc = lista.first['desc'] as String? ?? '';
    double totalSolicitada = 0.0;
    double totalDespachada = 0.0;
    double sumaHorasCompras = 0.0;
    int countCompras = 0;
    double sumaHorasBodega = 0.0;
    int countBodega = 0;

    for (final e in lista) {
      totalSolicitada += (e['solicitada'] as double? ?? 0.0);
      totalDespachada += (e['despachada'] as double? ?? 0.0);

      final hc = e['horasCompras'] as double?;
      if (hc != null && hc >= 0) {
        sumaHorasCompras += hc;
        countCompras++;
      }

      final hb = e['horasBodega'] as double?;
      if (hb != null && hb >= 0) {
        sumaHorasBodega += hb;
        countBodega++;
      }
    }

    final promCompras = countCompras > 0 ? (sumaHorasCompras / countCompras) : 0.0;
    final promBodega = countBodega > 0 ? (sumaHorasBodega / countBodega) : 0.0;

    ranking.add(ResumenRepuestoDash(
      codigo: cod,
      descripcion: desc,
      vecesSolicitado: lista.length,
      promedioHorasAbastecimiento: _redondear2(promCompras),
      promedioHorasDespachoBodega: _redondear2(promBodega),
      cantidadTotalSolicitada: totalSolicitada,
      cantidadTotalDespachada: totalDespachada,
      esCritico: promCompras > 48.0, // Más de 48 horas en compras = alerta de cuello de botella
    ));
  });

  // Ordenar de mayor demora de abastecimiento a menor (Top cuellos de botella)
  ranking.sort((a, b) => b.promedioHorasAbastecimiento.compareTo(a.promedioHorasAbastecimiento));

  return ranking;
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

  final ranking = _calcularRankingRepuestosBloc(tickets);

  return DashboardDatos(
    resumen: resumen,
    segmentos: segmentos,
    marcas: _valoresUnicosBloc(resumen.map((r) => r.marca)),
    equipos: _valoresUnicosBloc(resumen.map((r) => r.equipo)),
    sedes: _valoresUnicosBloc(resumen.map((r) => r.sede)),
    tiposGarantia: _valoresUnicosBloc(resumen.map((r) => r.tipoGarantia ?? '')),
    estadosBucket: _valoresUnicosBloc(resumen.map((r) => r.estadoBucket)),
    departamentos: _valoresUnicosBloc(segmentos.map((s) => s.departamento)),
    rankingRepuestos: ranking,
  );
}
