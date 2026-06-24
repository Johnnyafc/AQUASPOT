// lib/features/tickets/domain/entities/ticket_entity.dart

import 'package:equatable/equatable.dart';
import 'ticket_enums.dart';
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
  
  
  // Etapa 2 (Opcional al inicio)
  final EvaluacionTecnicaEntity? evaluacionTecnica;
  
  // Etapa 3 (Opcional al inicio)
  final List<String> fotosUrls;
  final String? pdfActaUrl;
  
  // Trazabilidad
  final List<EventoAuditoriaEntity> historialEventos;

  const TicketEntity({
    required this.id,
    required this.estadoActual,
    required this.sede,
    required this.clienteId,
    required this.campamento,
    required this.nombreContacto,
    required this.emailContacto,
    required this.telefonoContacto,
    required this.equipo,
    required this.fallaReportada,
    required this.numeroSerie,
    this.evaluacionTecnica,
    this.fotosUrls = const [],
    this.pdfActaUrl,
    required this.historialEventos,
  });

  TicketEntity copyWith({
    String? id,
    EstadoTicket? estadoActual,
    Sede? sede,
    String? clienteId,
    String? campamento,
    String? nombreContacto,
    String? emailContacto,
    String? telefonoContacto,
    TipoEquipo? equipo,
    String? fallaReportada,
    String? numeroSerie, // <-- CORRECCIÓN: Agregado como parámetro
    EvaluacionTecnicaEntity? evaluacionTecnica,
    List<String>? fotosUrls,
    String? pdfActaUrl,
    List<EventoAuditoriaEntity>? historialEventos,
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
      equipo: equipo ?? this.equipo,
      fallaReportada: fallaReportada ?? this.fallaReportada,
      numeroSerie: numeroSerie ?? this.numeroSerie, // <-- CORRECCIÓN: Asignación en el clon
      evaluacionTecnica: evaluacionTecnica ?? this.evaluacionTecnica,
      fotosUrls: fotosUrls ?? this.fotosUrls,
      pdfActaUrl: pdfActaUrl ?? this.pdfActaUrl,
      historialEventos: historialEventos ?? this.historialEventos,
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
        fallaReportada,
        numeroSerie, // <-- CORRECCIÓN: Agregado al radar de Equatable
        evaluacionTecnica,
        fotosUrls,
        pdfActaUrl,
        historialEventos,
      ];
}