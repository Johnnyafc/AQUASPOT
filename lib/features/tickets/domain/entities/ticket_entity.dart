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
  final String telefonoContacto;
  final TipoEquipo equipo;
  final String fallaReportada;
  
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
    required this.telefonoContacto,
    required this.equipo,
    required this.fallaReportada,
    this.evaluacionTecnica,
    this.fotosUrls = const [],
    this.pdfActaUrl,
    required this.historialEventos,
  });

  @override
  List<Object?> get props => [
        id,
        estadoActual,
        sede,
        clienteId,
        campamento,
        nombreContacto,
        telefonoContacto,
        equipo,
        fallaReportada,
        evaluacionTecnica,
        fotosUrls,
        pdfActaUrl,
        historialEventos,
      ];
}