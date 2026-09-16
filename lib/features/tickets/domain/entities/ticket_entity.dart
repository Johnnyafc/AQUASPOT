import 'tiempos_operativos_entity.dart';
// lib/features/tickets/domain/entities/ticket_entity.dart

import 'package:aquaspot_postventa/features/tickets/domain/entities/evidencia_trabajo_entity.dart';
import 'package:aquaspot_postventa/features/tickets/domain/entities/gestion_compras_entity.dart';
import 'package:aquaspot_postventa/features/tickets/domain/entities/item_compra_entity.dart';
import 'package:aquaspot_postventa/features/tickets/domain/entities/proforma_entity.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/enum/ticket_enums.dart';
import 'evaluacion_tecnica_entity.dart';
import 'item_despacho_bodega_entity.dart';
import 'registro_despacho_entity.dart';
import '../../../fallas/domain/entities/metrica_falla_entity.dart';

import 'evento_auditoria_entity.dart';

class TicketEntity extends Equatable {
  final String id; 
  final EstadoTicket estadoActual;
  
  // Etapa 1
  final Sede sede;
  final String clienteId;
  final String campamento;
  final String nombreContacto;
  final String emailContacto;
  final String telefonoContacto;
  final TipoEquipo equipo;
  final String fallaReportada;
  final String? numeroSerie;
  final String? equipoDetalle;
  final Map<String, bool>? accesoriosRecibidos;
  


final String marca; // 🚨 El que te habías olvidado
  final String? codigoProyecto;
  final List<String> codigoOrdenVenta;
  final List<String> codigoOrdenCompra;
  final List<String> procesoTrabajoUrls;
  
  // 🔒 VÁLVULAS DE SEGURIDAD (Enclavamientos)
  final bool isCostosCompletado;
  final bool isComprasCompletado;

  
  // Etapa 2 (Opcional al inicio)
  final EvaluacionTecnicaEntity? evaluacionTecnica;
  final bool esRegistroCompleto;
  
  // Etapa 3 (Opcional al inicio)
  final List<String> fotosUrls;
  final String? pdfActaUrl;
  
  // Trazabilidad
  final List<EventoAuditoriaEntity> historialEventos;

  // 🚀 SENSORES DE CONTROL DE REQUERIMIENTO ACTIVOS
  final TipoRequerimiento tipoRequerimiento;
  final LugarAtencion lugarAtencion;
  final String? notasRecepcion;
  final ProformaEntity? proforma;
  final List<ItemCompraEntity>? itemsCompra;
  final String? numeroOrdenVenta;
  final GestionComprasEntity? gestionCompras;
  final EvidenciaTrabajoEntity? evidenciaTrabajo;
  final String? tipoGarantia;
  final String? responsableFacturacion;
  final bool? esGarantia;
  final double? horometro;
  final List<String>? urlsEvidenciasGarantia;
  final bool fueModificado;
  final String? urlGuiaRemision;
  final String? urlFactura;
  final bool trabajoIniciado;

  // 🛑 CONTROL DE EXCEPCIÓN: SUPERVISOR DECLARA NO REQUIERE COMPRAS
  final bool noRequiereCompras;
  final String? motivoNoRequiereCompras;
  final String? supervisorNoRequiereCompras;
  final DateTime? fechaNoRequiereCompras;

  // 📦 GESTIÓN Y DESPACHO BODEGA (Enclavamiento de Stock y Despacho)
  final List<ItemDespachoBodegaEntity> itemsDespachoBodega;
  final List<RegistroDespachoEntity> historialDespachos;

  // ⏱️ TRAZABILIDAD CONCURRENTE Y TIEMPOS OPERATIVOS (Tiempos Netos vs Esperas)
  final TiemposOperativosEntity? tiemposOperativos;

  // 👥 TÉCNICOS ASIGNADOS (Gestión en Taller)
  final List<String> tecnicosAsignados;

  // 🔍 DIAGNÓSTICO DE FALLAS (Causas Raíz por Categoría)
  final List<DiagnosticoFallaEntity> diagnosticoFallas;

  // 📄 INFORME TÉCNICO ADJUNTO (Contador / Cosechadora)
  final String? urlInformeTecnico;

const TicketEntity({
    required this.id,
    required this.estadoActual,
    required this.sede,
    required this.clienteId,
    required this.campamento,
    required this.nombreContacto,
    required this.emailContacto,
    required this.telefonoContacto,
    required this.equipoDetalle,
    required this.accesoriosRecibidos,
    required this.equipo,
    required this.fallaReportada,
    required this.numeroSerie,
    required this.historialEventos,
    required this.tipoRequerimiento,
    required this.lugarAtencion,
    required this.esRegistroCompleto,
    this.evaluacionTecnica,
    this.fotosUrls = const [],
    this.pdfActaUrl,
    this.notasRecepcion,
    this.proforma,
    // ⚙️ EXPANSIÓN INDUSTRIAL: Pines para Costos, Compras y Taller
    this.marca = 'NO ESPECIFICADA', // Tolerancia a fallos para tickets antiguos
    this.codigoProyecto,
    this.codigoOrdenVenta = const [],
    this.codigoOrdenCompra = const [],
    this.itemsCompra = const [], // 🚨 Requiere que fabriques la clase ItemCompraEntity
    this.procesoTrabajoUrls = const [],
    this.isCostosCompletado = false,
    this.isComprasCompletado = false,
    this.numeroOrdenVenta,
    this.gestionCompras,
    this.evidenciaTrabajo,
    this.tipoGarantia,
    this.responsableFacturacion,
    this.esGarantia,
    this.horometro,
    this.urlsEvidenciasGarantia,
    this.fueModificado=false,
    this.urlFactura,
    this.urlGuiaRemision,
    this.trabajoIniciado = false,
    this.noRequiereCompras = false,
    this.motivoNoRequiereCompras,
    this.supervisorNoRequiereCompras,
    this.fechaNoRequiereCompras,
    this.itemsDespachoBodega = const [],
    this.historialDespachos = const [],
    this.tiemposOperativos,
    this.tecnicosAsignados = const [],
    this.diagnosticoFallas = const [],
    this.urlInformeTecnico,
  });

  // ⚙️ CLONADOR INDUSTRIAL CORREGIDO (Mutación Segura)
  TicketEntity copyWith({
    String? id,
    EstadoTicket? estadoActual,
    bool? trabajoIniciado,
    Sede? sede,
    String? clienteId,
    String? campamento,
    String? nombreContacto,
    String? emailContacto,
    String? telefonoContacto,
    String? equipoDetalle,
    TipoEquipo? equipo,
    String? fallaReportada,
    String? numeroSerie,
    Map<String, bool>? accesoriosRecibidos,
    EvaluacionTecnicaEntity? evaluacionTecnica,
    List<String>? fotosUrls,
    String? pdfActaUrl,
    List<EventoAuditoriaEntity>? historialEventos,
    TipoRequerimiento? tipoRequerimiento,
    LugarAtencion? lugarAtencion,
    bool? esRegistroCompleto,
    String? notasRecepcion,
    ProformaEntity? proforma,
    // 🚀 EXPANSIÓN: Añadidos a los argumentos del clonador
    String? marca,
    String? codigoProyecto,
    List<String>? codigoOrdenVenta,
    List<String>? codigoOrdenCompra,
    List<ItemCompraEntity>? itemsCompra, 
    List<String>? procesoTrabajoUrls,
    bool? isCostosCompletado,
    bool? isComprasCompletado,
    String? numeroOrdenVenta,
    GestionComprasEntity? gestionCompras,
    EvidenciaTrabajoEntity? evidenciaTrabajo,
    String? tipoGarantia,
    String? responsableFacturacion,
    bool? esGarantia,
    double? horometro,
    List<String>? urlsEvidenciasGarantia,
    bool? fueModificado,
    String? urlFactura,
    String? urlGuiaRemision,
    bool? noRequiereCompras,
    String? motivoNoRequiereCompras,
    String? supervisorNoRequiereCompras,
    DateTime? fechaNoRequiereCompras,
    List<ItemDespachoBodegaEntity>? itemsDespachoBodega,
    List<RegistroDespachoEntity>? historialDespachos,
    TiemposOperativosEntity? tiemposOperativos,
    List<String>? tecnicosAsignados,
    List<DiagnosticoFallaEntity>? diagnosticoFallas,
    String? urlInformeTecnico,
  }) {
    return TicketEntity(
      id: id ?? this.id,
      estadoActual: estadoActual ?? this.estadoActual,
      sede: sede ?? this.sede,
      clienteId: clienteId ?? this.clienteId,
      campamento: campamento ?? this.campamento,
      nombreContacto: nombreContacto ?? this.nombreContacto,
      emailContacto: emailContacto ?? this.emailContacto,
      telefonoContacto: telefonoContacto ?? this.telefonoContacto,
      equipoDetalle: equipoDetalle ?? this.equipoDetalle,
      equipo: equipo ?? this.equipo,
      fallaReportada: fallaReportada ?? this.fallaReportada,
      notasRecepcion: notasRecepcion ?? this.notasRecepcion,
      proforma: proforma ?? this.proforma,
      numeroSerie: numeroSerie ?? this.numeroSerie,
      accesoriosRecibidos: accesoriosRecibidos ?? this.accesoriosRecibidos,
      evaluacionTecnica: evaluacionTecnica ?? this.evaluacionTecnica,
      fotosUrls: fotosUrls ?? this.fotosUrls,
      pdfActaUrl: pdfActaUrl ?? this.pdfActaUrl,
      historialEventos: historialEventos ?? this.historialEventos,
      tipoRequerimiento: tipoRequerimiento ?? this.tipoRequerimiento,
      lugarAtencion: lugarAtencion ?? this.lugarAtencion,
      esRegistroCompleto: esRegistroCompleto ?? this.esRegistroCompleto,
      fueModificado: fueModificado ?? this.fueModificado,
      // 🚀 EXPANSIÓN: Inyección al constructor del clon
      marca: marca ?? this.marca,
      codigoProyecto: codigoProyecto ?? this.codigoProyecto,
      codigoOrdenVenta: codigoOrdenVenta ?? this.codigoOrdenVenta,
      codigoOrdenCompra: codigoOrdenCompra ?? this.codigoOrdenCompra,
      itemsCompra: itemsCompra ?? this.itemsCompra,
      procesoTrabajoUrls: procesoTrabajoUrls ?? this.procesoTrabajoUrls,
      isCostosCompletado: isCostosCompletado ?? this.isCostosCompletado,
      isComprasCompletado: isComprasCompletado ?? this.isComprasCompletado,
      numeroOrdenVenta: numeroOrdenVenta ?? this.numeroOrdenVenta,
      gestionCompras: gestionCompras ?? this.gestionCompras,
      evidenciaTrabajo: evidenciaTrabajo ?? this.evidenciaTrabajo,
      tipoGarantia: tipoGarantia ?? this.tipoGarantia,
      responsableFacturacion: responsableFacturacion ?? this.responsableFacturacion,
      esGarantia: esGarantia ?? this.esGarantia,
      horometro:horometro ?? this.horometro,
      urlsEvidenciasGarantia: urlsEvidenciasGarantia ?? this.urlsEvidenciasGarantia,
      urlFactura:urlFactura ?? this.urlFactura, 
      urlGuiaRemision: urlGuiaRemision ?? this.urlGuiaRemision,
      trabajoIniciado: trabajoIniciado ?? this.trabajoIniciado,
      noRequiereCompras: noRequiereCompras ?? this.noRequiereCompras,
      motivoNoRequiereCompras: motivoNoRequiereCompras ?? this.motivoNoRequiereCompras,
      supervisorNoRequiereCompras: supervisorNoRequiereCompras ?? this.supervisorNoRequiereCompras,
      fechaNoRequiereCompras: fechaNoRequiereCompras ?? this.fechaNoRequiereCompras,
      itemsDespachoBodega: itemsDespachoBodega ?? this.itemsDespachoBodega,
      historialDespachos: historialDespachos ?? this.historialDespachos,
      tiemposOperativos: tiemposOperativos ?? this.tiemposOperativos,
      tecnicosAsignados: tecnicosAsignados ?? this.tecnicosAsignados,
      diagnosticoFallas: diagnosticoFallas ?? this.diagnosticoFallas,
      urlInformeTecnico: urlInformeTecnico ?? this.urlInformeTecnico,
    );
  }

  @override
  List<Object?> get props => [
        id,
        estadoActual,
        sede,
        clienteId,
        campamento,
        nombreContacto,
        emailContacto,
        telefonoContacto,
        equipo,
        equipoDetalle,
        fallaReportada,
        notasRecepcion,
        numeroSerie, 
        accesoriosRecibidos,
        evaluacionTecnica,
        fotosUrls,
        pdfActaUrl,
        historialEventos,
        tipoRequerimiento,
        lugarAtencion,
        esRegistroCompleto,
        proforma,
        // 🚀 EXPANSIÓN: Conectados al radar de Equatable (CRÍTICO para redibujar la HMI)
        marca,
        codigoProyecto,
        codigoOrdenVenta,
        codigoOrdenCompra,
        itemsCompra,
        procesoTrabajoUrls,
        isCostosCompletado,
        isComprasCompletado,
        numeroOrdenVenta,
        gestionCompras,
        evidenciaTrabajo,
        tipoGarantia,
        responsableFacturacion,
        esGarantia,
        horometro,
        urlsEvidenciasGarantia,
        fueModificado,
        urlFactura,
        urlGuiaRemision,
        trabajoIniciado,
        noRequiereCompras,
        motivoNoRequiereCompras,
        supervisorNoRequiereCompras,
        fechaNoRequiereCompras,
        itemsDespachoBodega,
        historialDespachos,
        tiemposOperativos,
        tecnicosAsignados,
        diagnosticoFallas,
        urlInformeTecnico,
      ];

  /// Obtiene el nombre formateado y estandarizado del responsable de facturación (ej: AGRISPOTSA)
  String get responsableFacturacionLegible => formatearResponsableFacturacion(responsableFacturacion);

  // ============================================================================
  // 📦 ENCLAVAMIENTOS Y SENSORES DE BODEGA / DESPACHO / COMPRAS
  // ============================================================================

  /// Retorna verdadero si Compras ya marcó con check al menos un repuesto
  /// (Gatillo para visualización temprana en la bandeja de Bodega / Despacho)
  bool get tieneAlMenosUnCheckCompras =>
      itemsDespachoBodega.any((item) => item.validadoPorCompras);

  /// Retorna verdadero si Bodega ya despachó al menos una unidad de algún ítem
  /// (Gatillo para visualización temprana en la bandeja de Proceso de Trabajo / Taller)
  bool get tieneAlMenosUnDespachoBodega =>
      itemsDespachoBodega.any((item) => item.cantidadDespachada > 0);

  /// Válvula de seguridad: Compras solo puede cerrar/transferir definitivamente si
  /// el 100% de los ítems requeridos tienen su check de validación.
  bool get comprasValidacionCompleta =>
      itemsDespachoBodega.isNotEmpty &&
      itemsDespachoBodega.every((item) => item.validadoPorCompras);

  /// Válvula de seguridad: Bodega solo transfiere formalmente a Proceso de Trabajo si
  /// el 100% de los materiales requeridos han sido despachados en su totalidad.
  bool get bodegaDespachoCompleto =>
      itemsDespachoBodega.isNotEmpty &&
      itemsDespachoBodega.every((item) => item.despachadoCompletamente);

  /// Ítems que ya han sido despachados desde bodega (total o parcialmente)
  List<ItemDespachoBodegaEntity> get itemsDespachados =>
      itemsDespachoBodega.where((item) => item.cantidadDespachada > 0).toList();

  /// Ítems que todavía tienen cantidades pendientes por despachar
  List<ItemDespachoBodegaEntity> get itemsFaltantesDespacho =>
      itemsDespachoBodega.where((item) => item.cantidadFaltante > 0).toList();
}

extension TicketMetrics on TicketEntity {
  // ⚙️ Cálculo de tiempo de proceso (Lead Time de Creación a Recepción)
  Duration? get tiempoDePasoARecepcion {
    
    // 1. Buscamos todas las coincidencias en el historial de telemetría sin forzar tipos
    final eventosInicio = historialEventos.where((e) => e.accion == 'CREACIÓN DE REQUERIMIENTO');
    final eventosFin = historialEventos.where((e) => e.accion == 'RECEPCIÓN FÍSICA Y EMISIÓN DE ACTA');

    // 2. Enclavamiento de seguridad: Si no existen ambos eventos, abortamos el cálculo
    if (eventosInicio.isEmpty || eventosFin.isEmpty) {
      return null;
    }

    // 3. Calculamos el delta de tiempo usando el primer registro cronológico encontrado
    return eventosFin.first.timestamp.difference(eventosInicio.first.timestamp);
  }

  // 🆕 Fecha en que el ticket entró a su estado ACTUAL: el timestamp más
  // reciente de su historial. Se usa para mostrar, en tiempo real, cuánto
  // lleva el ticket en el paso donde está ahora mismo (ver
  // TiempoEnCursoWidget). No requiere ningún campo nuevo en Firestore: se
  // deriva de historialEventos, que ya se guarda en cada paso.
  DateTime? get fechaInicioEstadoActual {
    if (historialEventos.isEmpty) return null;
    DateTime? masReciente;
    for (final evento in historialEventos) {
      if (masReciente == null || evento.timestamp.isAfter(masReciente)) {
        masReciente = evento.timestamp;
      }
    }
    return masReciente;
  }
}