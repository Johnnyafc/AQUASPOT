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
import 'orden_recepcion_repuestos_entity.dart';
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

  // 🚚 RECEPCIÓN DE REPUESTOS EN BODEGA Y VALIDACIÓN DE TALLER
  final List<OrdenRecepcionRepuestosEntity> ordenesRecepcion;
  final bool materialesValidadosEnTaller;
  final String? supervisorValidoMateriales;
  final DateTime? fechaValidacionMaterialesTaller;

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
    this.ordenesRecepcion = const [],
    this.materialesValidadosEnTaller = false,
    this.supervisorValidoMateriales,
    this.fechaValidacionMaterialesTaller,
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
    List<OrdenRecepcionRepuestosEntity>? ordenesRecepcion,
    bool? materialesValidadosEnTaller,
    String? supervisorValidoMateriales,
    DateTime? fechaValidacionMaterialesTaller,
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
      ordenesRecepcion: ordenesRecepcion ?? this.ordenesRecepcion,
      materialesValidadosEnTaller: materialesValidadosEnTaller ?? this.materialesValidadosEnTaller,
      supervisorValidoMateriales: supervisorValidoMateriales ?? this.supervisorValidoMateriales,
      fechaValidacionMaterialesTaller: fechaValidacionMaterialesTaller ?? this.fechaValidacionMaterialesTaller,
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
        ordenesRecepcion,
        materialesValidadosEnTaller,
        supervisorValidoMateriales,
        fechaValidacionMaterialesTaller,
      ];

  /// Obtiene el nombre formateado y estandarizado del responsable de facturación (ej: AGRISPOTSA)
  String get responsableFacturacionLegible => formatearResponsableFacturacion(responsableFacturacion);

  // ============================================================================
  // 📦 ENCLAVAMIENTOS Y SENSORES DE BODEGA / DESPACHO / COMPRAS / RECEPCIÓN
  // ============================================================================

  /// Retorna verdadero si Compras ya marcó con check al menos un repuesto
  /// (Gatillo para visualización temprana en la bandeja de Bodega / Despacho)
  bool get tieneAlMenosUnCheckCompras =>
      itemsDespachoBodega.any((item) => item.validadoPorCompras || item.tieneStockSuficiente);

  /// Retorna verdadero si Bodega ya despachó al menos una unidad de algún ítem
  /// (Gatillo para visualización temprana en la bandeja de Proceso de Trabajo / Taller)
  bool get tieneAlMenosUnDespachoBodega =>
      itemsDespachoBodega.any((item) => item.cantidadDespachada > 0);

  /// Válvula de seguridad: Compras solo puede cerrar/transferir definitivamente si
  /// el 100% de los ítems requeridos tienen su check de validación (o stock local).
  bool get comprasValidacionCompleta =>
      itemsDespachoBodega.isNotEmpty &&
      itemsDespachoBodega.every((item) => item.validadoPorCompras || item.tieneStockSuficiente);

  /// Válvula de seguridad: Bodega solo transfiere formalmente a Proceso de Trabajo si
  /// el 100% de los materiales requeridos han sido despachados en su totalidad.
  bool get bodegaDespachoCompleto =>
      itemsDespachoBodega.isNotEmpty &&
      itemsDespachoBodega.every((item) => item.despachadoCompletamente);

  /// Ítems que ya han sido despachados desde bodega (total o parcialmente)
  List<ItemDespachoBodegaEntity> get itemsDespachados =>
      itemsDespachoBodega.where((item) => item.cantidadDespachada > 0).toList();

  /// Ítems que todavía tienen cantidades pendientes por despachar en bodega
  List<ItemDespachoBodegaEntity> get itemsFaltantesDespacho =>
      itemsDespachoBodega.where((item) => item.cantidadFaltante > 0).toList();

  // ============================================================================
  // 🚚 CADENA DE CUSTODIA Y RECEPCIÓN DE REPUESTOS EN TALLER
  // ============================================================================

  /// Sumatoria de la cantidad de un ítem que ha sido recibida físicamente en taller por los técnicos
  double cantidadTotalRecibidaEnTaller(String codigo) {
    final cod = codigo.trim().toUpperCase();
    double total = 0.0;
    for (final orden in ordenesRecepcion) {
      if (orden.estaCompletada) {
        total += orden.cantidadRecibidaDeItem(cod);
      }
    }
    return total;
  }

  /// Cantidad asignada actualmente a órdenes de retiro pendientes de ser recogidas
  double cantidadEnOrdenesPendientes(String codigo) {
    final cod = codigo.trim().toUpperCase();
    double total = 0.0;
    for (final orden in ordenesRecepcion) {
      if (orden.estado == EstadoOrdenRecepcion.pendienteRecoger) {
        final match = orden.items.where((i) => i.codigo.trim().toUpperCase() == cod);
        for (final item in match) {
          total += item.cantidadDespachadaBodega;
        }
      }
    }
    return total;
  }

  /// Cantidad que Bodega ya preparó/despachó pero que aún no ha sido recibida físicamente en taller
  double cantidadPendienteRecogerEnBodega(String codigo) {
    final cod = codigo.trim().toUpperCase();
    final match = itemsDespachoBodega.where((i) => i.codigo.trim().toUpperCase() == cod);
    if (match.isEmpty) return 0.0;
    final item = match.first;
    final cantDespachada = item.cantidadDespachada;
    final cantRecibida = cantidadTotalRecibidaEnTaller(cod);
    final diff = cantDespachada - cantRecibida;
    return diff > 0 ? diff : 0.0;
  }

  /// Saldo real en bodega que aún NO ha sido asignado a ninguna orden de retiro activa
  double cantidadDisponibleParaAsignarRetiro(String codigo) {
    final saldo = cantidadPendienteRecogerEnBodega(codigo);
    final enTransito = cantidadEnOrdenesPendientes(codigo);
    final disponible = saldo - enTransito;
    return disponible > 0 ? disponible : 0.0;
  }

  /// Ítems que Bodega ya despachó y que tienen saldo pendiente de ser recogido por un técnico
  List<ItemDespachoBodegaEntity> get itemsPendientesDeRecogerEnBodega {
    return itemsDespachoBodega.where((item) {
      return cantidadDisponibleParaAsignarRetiro(item.codigo) > 0;
    }).toList();
  }

  /// Retorna true si hay materiales en bodega alistados que aún pueden asignarse a un técnico para retiro
  bool get hayMaterialesDespachadosPorAsignar {
    return itemsDespachoBodega.any((item) {
      return cantidadDisponibleParaAsignarRetiro(item.codigo) > 0;
    });
  }

  /// 🛑 ENCLAVAMIENTO DE SEGURIDAD EN BODEGA:
  /// Retorna true si existe algún despacho en el historial que NO cuenta con fotos de evidencia de respaldo
  bool get tieneDespachoPendienteDeEvidencia =>
      historialDespachos.any((d) => d.fotosEvidenciasUrls.isEmpty);

  /// Retorna el despacho pendiente de regularizar fotos de evidencia (si existe)
  RegistroDespachoEntity? get despachoPendienteDeEvidencia =>
      historialDespachos.where((d) => d.fotosEvidenciasUrls.isEmpty).lastOrNull;

  /// Retorna verdadero si el 100% de los repuestos solicitados ya fueron recibidos físicamente en el taller
  bool get todosRepuestosRecibidosEnTaller {
    if (itemsDespachoBodega.isEmpty) return true;
    return itemsDespachoBodega.every((item) {
      return cantidadTotalRecibidaEnTaller(item.codigo) >= item.cantidadSolicitada;
    });
  }

  /// Válvula del Supervisor para certificación total (100%):
  /// Solo se certifica la totalidad si todos los repuestos requeridos están recibidos en el taller
  bool get puedeSupervisorValidarMateriales {
    if (itemsDespachoBodega.isEmpty) return true;
    return todosRepuestosRecibidosEnTaller && itemsPendientesDeRecogerEnBodega.isEmpty;
  }

  /// Retorna true si ya se recibió físicamente al menos un lote de repuestos en el taller
  bool get tieneAlMenosUnLoteRecibidoEnTaller {
    if (noRequiereCompras || itemsDespachoBodega.isEmpty) return true;
    return ordenesRecepcion.any((o) => o.estaCompletada);
  }

  /// Retorna true si al menos una orden recibida ya fue validada en consumo por el supervisor
  bool get tieneConsumoValidadoEnTaller {
    if (noRequiereCompras || itemsDespachoBodega.isEmpty) return true;
    return ordenesRecepcion.any((o) => o.estaCompletada && o.validadoSupervisor);
  }

  /// Retorna true si Compras terminó y Bodega terminó el 100% de los repuestos requeridos
  bool get comprasYBodegaTotalmenteCompletados {
    if (noRequiereCompras || itemsDespachoBodega.isEmpty) return true;
    return bodegaDespachoCompleto;
  }

  /// Enclavamiento final de Proceso de Trabajo:
  /// Solo puede enviar evidencia y liberar a Facturación si:
  /// 1) Inició el trabajo físico
  /// 2) Si requiere repuestos: que haya llegado al menos un lote a taller y se haya validado consumo
  bool get puedeLiberarEnTaller {
    if (!trabajoIniciado) return false;
    if (noRequiereCompras || itemsDespachoBodega.isEmpty) return true;
    return tieneAlMenosUnLoteRecibidoEnTaller &&
        (tieneConsumoValidadoEnTaller || materialesValidadosEnTaller);
  }
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