// lib/features/tickets/domain/entities/ticket_entity.dart

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
    this.evaluacionTecnica,
    this.fotosUrls = const [],
    this.pdfActaUrl,
    required this.historialEventos,
    required this.tipoRequerimiento,
    required this.lugarAtencion,
    required this.esRegistroCompleto,
    this.notasRecepcion,
    this.proforma
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
    // 🚀 REPARACIÓN: Pines añadidos a los argumentos del clonador
    TipoRequerimiento? tipoRequerimiento,
    LugarAtencion? lugarAtencion,
    bool? esRegistroCompleto,
    String? notasRecepcion,
    ProformaEntity? proforma
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
      // 🚀 REPARACIÓN: Inyección de datos obligatorios al constructor del clon
      tipoRequerimiento: tipoRequerimiento ?? this.tipoRequerimiento,
      lugarAtencion: lugarAtencion ?? this.lugarAtencion,
      esRegistroCompleto: esRegistroCompleto ?? this.esRegistroCompleto,
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
        // 🚀 REPARACIÓN: Conectados al radar de Equatable para reactividad de UI
        tipoRequerimiento,
        lugarAtencion,
        esRegistroCompleto,
        proforma
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