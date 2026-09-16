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
  final DateTime? fechaCreacion;
  final DateTime? fechaActualizacion;
  final double horasTotales;
  final double diasTotales;
  final int numPasos;
  final String estadoBucket;
  final String estadoNombre;

  // ⏱️ Tiempos Operativos Netos vs Espera (Trazabilidad Concurrente Justa)
  final double? horasNetasCompras;
  final double? horasNetasBodega;
  final double? horasEsperaBodega;
  final double? horasNetasTaller;
  final double? horasEsperaTaller;
  final String? subEstadoCompras;
  final String? subEstadoBodega;
  final String? subEstadoTaller;

  // 🆕 Documentos del ticket, agrupados por trámite lógico (no por variable
  // cruda) para la columna de "links" del Dashboard. Cada lista puede venir
  // vacía si ese trámite todavía no tiene ningún documento subido — la
  // pantalla decide si muestra la columna según si HAY datos en alguna fila
  // ("no pongas columnas por gusto, solo si tienen lo pones sino no").
  final List<String> documentosActa; // pdfActaUrl + fotosUrls (recepción)
  final List<String> documentosEvaluacion; // evaluacionTecnica.* (pdf/excel/garantía)
  final List<String> documentosProforma; // proforma.pdfUrls + .excelUrls
  final List<String> documentosCompras; // gestionCompras.urlsOrdenCompra
  final List<String> documentosEvidenciaTrabajo; // procesoTrabajoUrls + evidenciaTrabajo.*
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
    required this.fechaCreacion,
    required this.fechaActualizacion,
    required this.horasTotales,
    required this.diasTotales,
    required this.numPasos,
    required this.estadoBucket,
    required this.estadoNombre,
    this.horasNetasCompras,
    this.horasNetasBodega,
    this.horasEsperaBodega,
    this.horasNetasTaller,
    this.horasEsperaTaller,
    this.subEstadoCompras,
    this.subEstadoBodega,
    this.subEstadoTaller,
    this.documentosActa = const [],
    this.documentosEvaluacion = const [],
    this.documentosProforma = const [],
    this.documentosCompras = const [],
    this.documentosEvidenciaTrabajo = const [],
    this.documentosEntrega = const [],
    this.documentosGarantia = const [],
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
        fechaCreacion,
        fechaActualizacion,
        horasTotales,
        diasTotales,
        numPasos,
        estadoBucket,
        estadoNombre,
        horasNetasCompras,
        horasNetasBodega,
        horasEsperaBodega,
        horasNetasTaller,
        horasEsperaTaller,
        subEstadoCompras,
        subEstadoBodega,
        subEstadoTaller,
        documentosActa,
        documentosEvaluacion,
        documentosProforma,
        documentosCompras,
        documentosEvidenciaTrabajo,
        documentosEntrega,
        documentosGarantia,
      ];
}

// ⏱️ Un "segmento" = el tiempo que transcurrió ENTRE dos pasos consecutivos
// del historial de un ticket. Se le atribuye al departamento (usuarioRol)
// que ejecutó el paso de LLEGADA: si el paso 2 lo marcó "ADMIN", el tiempo
// entre el paso 1 y el paso 2 es el tiempo que le tomó a ADMIN reaccionar
// / completar su actividad.
class SegmentoTiempoDash extends Equatable {
  final String ticketId;
  final String accion;
  final String departamento;
  final String usuarioNombre;
  final double horas;
  // 🆕 Segmento operativo del ticket (CARACOL / COSECHADORA / CONTADOR /
  // GENERAL), tomado de TicketEntity.equipo — permite separar el tiempo
  // de un departamento que atiende varios tipos de equipo (ej.
  // SUPERVISOR) en vez de mezclarlo todo en un solo promedio.
  final String segmentoOperativo;

  const SegmentoTiempoDash({
    required this.ticketId,
    required this.accion,
    required this.departamento,
    required this.usuarioNombre,
    required this.horas,
    required this.segmentoOperativo,
  });

  @override
  List<Object?> get props => [ticketId, accion, departamento, usuarioNombre, horas, segmentoOperativo];
}


// 📦 DTO para Lead Time de Repuestos y Evaluación de Abastecimiento (Proveedores)
class ResumenRepuestoDash extends Equatable {
  final String codigo;
  final String descripcion;
  final int vecesSolicitado;
  final double promedioHorasAbastecimiento;
  final double promedioHorasDespachoBodega;
  final double cantidadTotalSolicitada;
  final double cantidadTotalDespachada;
  final bool esCritico;

  const ResumenRepuestoDash({
    required this.codigo,
    required this.descripcion,
    required this.vecesSolicitado,
    required this.promedioHorasAbastecimiento,
    required this.promedioHorasDespachoBodega,
    required this.cantidadTotalSolicitada,
    required this.cantidadTotalDespachada,
    this.esCritico = false,
  });

  @override
  List<Object?> get props => [
        codigo,
        descripcion,
        vecesSolicitado,
        promedioHorasAbastecimiento,
        promedioHorasDespachoBodega,
        cantidadTotalSolicitada,
        cantidadTotalDespachada,
        esCritico,
      ];
}

class DashboardDatos extends Equatable {
  final List<ResumenTicketDash> resumen;
  final List<SegmentoTiempoDash> segmentos;
  final List<String> marcas;
  final List<String> equipos;
  final List<String> sedes;
  final List<String> tiposGarantia;
  final List<String> estadosBucket;
  final List<String> departamentos;
  final List<ResumenRepuestoDash> rankingRepuestos;

  const DashboardDatos({
    required this.resumen,
    required this.segmentos,
    required this.marcas,
    required this.equipos,
    required this.sedes,
    required this.tiposGarantia,
    required this.estadosBucket,
    required this.departamentos,
    this.rankingRepuestos = const [],
  });

  @override
  List<Object?> get props => [
        resumen,
        segmentos,
        marcas,
        equipos,
        sedes,
        tiposGarantia,
        estadosBucket,
        departamentos,
        rankingRepuestos,
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
