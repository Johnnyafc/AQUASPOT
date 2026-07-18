// lib/features/tickets/domain/entities/ticket_entity.dart

import 'package:aquaspot_postventa/features/tickets/domain/entities/item_compra_entity.dart';
import 'package:aquaspot_postventa/features/tickets/domain/entities/proforma_entity.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/enum/ticket_enums.dart';
import 'evaluacion_tecnica_entity.dart';
import 'evento_auditoria_entity.dart';

// lib/features/tickets/domain/entities/ticket_entity.dart

import 'package:equatable/equatable.dart';
import '../../../../core/enum/ticket_enums.dart'; // ⚙️ Asegúrate de apuntar a tus enums unificados
import 'evaluacion_tecnica_entity.dart';
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
  });

  // ⚙️ CLONADOR INDUSTRIAL CORREGIDO (Mutación Segura)
  TicketEntity copyWith({
    String? id,
    EstadoTicket? estadoActual,
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
      ];
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
}