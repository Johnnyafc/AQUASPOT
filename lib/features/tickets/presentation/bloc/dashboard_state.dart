// lib/features/tickets/presentation/bloc/dashboard_state.dart
//
// Estado del Dashboard de Tickets, incluyendo los DTOs (Data Transfer
// Objects) 100% planos que viajan desde el isolate de cálculo
// (ver dashboard_bloc.dart) hasta la interfaz.
//
// ⚙️ Por qué son "planos" (solo String, double, int, DateTime, bool) y no
// envuelven TicketEntity: al calcular estos datos dentro de `compute()`
// (un isolate/hilo separado del de la interfaz), el resultado tiene que
// "viajar" de vuelta a la UI. Mandar objetos livianos y simples hace ese
// viaje más rápido y evita cualquier duda sobre si las clases anidadas de
// TicketEntity (evaluación técnica, proforma, gestión de compras, etc.)
// son transferibles entre isolates. También simplifica el código de la
// pantalla: ya no hay que navegar `r.ticket.campo.subcampo` en cada chart.

import 'package:equatable/equatable.dart';

enum DashboardStatus { inicial, cargando, listo, error }

// 🔍 Una falla diagnosticada en Proceso de Trabajo (ticket.diagnosticoFallas),
// aplanada para el dashboard "Diagnóstico de fallas".
class DiagnosticoFallaDash extends Equatable {
  final String categoria;
  final String subcategoria;
  final String falla;
  final List<String> razones;

  const DiagnosticoFallaDash({
    required this.categoria,
    required this.subcategoria,
    required this.falla,
    required this.razones,
  });

  @override
  List<Object?> get props => [categoria, subcategoria, falla, razones];
}

// 📦 Una fila resumida por ticket — ya con todas las etiquetas traducidas
// (nombre de estado, tipo de requerimiento, capitalización) calculadas UNA
// sola vez en el isolate, no en cada rebuild de la interfaz.
class ResumenTicketDash extends Equatable {
  final String id;
  final String clienteId;
  final String equipo;
  final String marca;
  final String fallaReportada;
  final String lugarAtencion;
  final String sede;
  final String? tipoGarantia;
  final String tipoRequerimientoEtiqueta;
  final bool esReclamoGarantia;
  // Garantía APROBADA por ingeniería (ticket.esGarantia).
  final bool garantiaAprobada;
  final DateTime? fechaCreacion;
  final DateTime? fechaActualizacion;
  final double horasTotales;
  final double diasTotales;
  final int numPasos;
  final String estadoBucket;
  final String estadoNombre;

  // Dictamen de un reclamo de garantía: 'Aprobada', 'Rechazada' o
  // 'Sin dictamen' (null si el ticket no es reclamo de garantía).
  final String? dictamenGarantia;

  // 🆕 Documentos del ticket, agrupados por trámite lógico (no por variable
  // cruda) para la columna de "links" del Dashboard. Cada lista puede venir
  // vacía si ese trámite todavía no tiene ningún documento subido — la
  // pantalla decide si muestra la columna según si HAY datos en alguna fila
  // ("no pongas columnas por gusto, solo si tienen lo pones sino no").
  final List<String> documentosActa; // pdfActaUrl (documento formal de recepción)
  final List<String> documentosEvidenciaRecepcion; // fotosUrls (evidencia fotográfica de recepción)
  final List<String> documentosEvaluacion; // evaluacionTecnica.* (pdf/excel/garantía)
  final List<String> documentosProforma; // proforma.pdfUrls + .excelUrls
  final List<String> documentosCompras; // gestionCompras.urlsOrdenCompra
  final List<String> documentosEvidenciaTrabajo; // procesoTrabajoUrls + evidenciaTrabajo.*
  // 🔍 Diagnóstico técnico de fallas (categoría / falla / razones).
  final List<DiagnosticoFallaDash> diagnosticos;
  final List<String> documentosEntrega; // urlGuiaRemision + urlFactura
  final List<String> documentosGarantia; // urlsEvidenciasGarantia

  const ResumenTicketDash({
    required this.id,
    required this.clienteId,
    required this.equipo,
    required this.marca,
    required this.fallaReportada,
    required this.lugarAtencion,
    required this.sede,
    required this.tipoGarantia,
    required this.tipoRequerimientoEtiqueta,
    required this.esReclamoGarantia,
    this.garantiaAprobada = false,
    required this.fechaCreacion,
    required this.fechaActualizacion,
    required this.horasTotales,
    required this.diasTotales,
    required this.numPasos,
    required this.estadoBucket,
    required this.estadoNombre,
    this.dictamenGarantia,
    this.documentosActa = const [],
    this.documentosEvidenciaRecepcion = const [],
    this.documentosEvaluacion = const [],
    this.documentosProforma = const [],
    this.documentosCompras = const [],
    this.documentosEvidenciaTrabajo = const [],
    this.documentosEntrega = const [],
    this.documentosGarantia = const [],
    this.diagnosticos = const [],
  });

  @override
  List<Object?> get props => [
        id,
        clienteId,
        equipo,
        marca,
        fallaReportada,
        lugarAtencion,
        sede,
        tipoGarantia,
        tipoRequerimientoEtiqueta,
        esReclamoGarantia,
        garantiaAprobada,
        fechaCreacion,
        fechaActualizacion,
        horasTotales,
        diasTotales,
        numPasos,
        estadoBucket,
        estadoNombre,
        dictamenGarantia,
        documentosActa,
        documentosEvidenciaRecepcion,
        documentosEvaluacion,
        documentosProforma,
        documentosCompras,
        documentosEvidenciaTrabajo,
        documentosEntrega,
        documentosGarantia,
        diagnosticos,
      ];
}

// ⏱️ Tiempo TOTAL que un proceso le dedicó a un ticket, atribuido a una
// persona (ver TiemposPorProcesoService). Hay uno por (ticket, proceso,
// persona): el dashboard promedia entre tickets, así cada ticket cuenta una
// sola vez por proceso aunque haya registrado varios eventos.
class SegmentoTiempoDash extends Equatable {
  final String ticketId;
  // Nombre del proceso (barra del dashboard): 'Compras', 'Despacho', etc.
  final String proceso;
  // Parte del proceso cuando se puede desplegar (ej. 'En camino (Guabo)'
  // dentro de Recepción); null si el proceso no se desglosa.
  final String? subproceso;
  final String departamento;
  final String usuarioNombre;
  final double horas;

  const SegmentoTiempoDash({
    required this.ticketId,
    required this.proceso,
    this.subproceso,
    required this.departamento,
    required this.usuarioNombre,
    required this.horas,
  });

  @override
  List<Object?> get props => [ticketId, proceso, subproceso, departamento, usuarioNombre, horas];
}


class DashboardDatos extends Equatable {
  final List<ResumenTicketDash> resumen;
  final List<SegmentoTiempoDash> segmentos;
  final List<String> marcas;
  final List<String> equipos;
  final List<String> sedes;
  final List<String> tiposGarantia;
  // Todos los estados del ticket (nombre legible, en orden del flujo).
  final List<String> estados;
  const DashboardDatos({
    required this.resumen,
    required this.segmentos,
    required this.marcas,
    required this.equipos,
    required this.sedes,
    required this.tiposGarantia,
    required this.estados,
  });

  @override
  List<Object?> get props => [
        resumen,
        segmentos,
        marcas,
        equipos,
        sedes,
        tiposGarantia,
        estados,
      ];
}

class DashboardState extends Equatable {
  final DashboardStatus status;
  final DashboardDatos? datos;
  final String mensaje;

  const DashboardState({
    this.status = DashboardStatus.inicial,
    this.datos,
    this.mensaje = '',
  });

  DashboardState copyWith({
    DashboardStatus? status,
    DashboardDatos? datos,
    String? mensaje,
  }) {
    return DashboardState(
      status: status ?? this.status,
      datos: datos ?? this.datos,
      mensaje: mensaje ?? this.mensaje,
    );
  }

  @override
  List<Object?> get props => [status, datos, mensaje];
}
