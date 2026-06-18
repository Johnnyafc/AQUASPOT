// lib/features/tickets/data/models/ticket_model.dart

import '../../domain/entities/ticket_entity.dart';
import '../../domain/entities/ticket_enums.dart';
import 'evaluacion_tecnica_model.dart';
import 'evento_auditoria_model.dart';

class TicketModel extends TicketEntity {
  const TicketModel({
    required super.id,
    required super.estadoActual,
    required super.sede,
    required super.clienteId,
    required super.campamento,
    required super.nombreContacto,
    required super.telefonoContacto,
    required super.equipo,
    required super.fallaReportada,
    super.evaluacionTecnica,
    super.fotosUrls,
    super.pdfActaUrl,
    required super.historialEventos,
  });

  factory TicketModel.fromJson(Map<String, dynamic> json) {
    return TicketModel(
      id: json['id'] ?? '',
      estadoActual: EstadoTicket.values.firstWhere(
        (e) => e.name == json['estadoActual'],
        orElse: () => EstadoTicket.creado,
      ),
      sede: Sede.values.firstWhere(
        (e) => e.name == json['sede'],
        orElse: () => Sede.guayaquil,
      ),
      clienteId: json['clienteId'] ?? '',
      campamento: json['campamento'] ?? '',
      nombreContacto: json['nombreContacto'] ?? '',
      telefonoContacto: json['telefonoContacto'] ?? '',
      equipo: TipoEquipo.values.firstWhere(
        (e) => e.name == json['equipo'],
        orElse: () => TipoEquipo.maquina,
      ),
      fallaReportada: json['fallaReportada'] ?? '',
      evaluacionTecnica: json['evaluacionTecnica'] != null
          ? EvaluacionTecnicaModel.fromJson(json['evaluacionTecnica'])
          : null,
      fotosUrls: List<String>.from(json['fotosUrls'] ?? []),
      pdfActaUrl: json['pdfActaUrl'],
      historialEventos: (json['historialEventos'] as List?)
              ?.map((e) => EventoAuditoriaModel.fromJson(e))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'estadoActual': estadoActual.name,
      'sede': sede.name,
      'clienteId': clienteId,
      'campamento': campamento,
      'nombreContacto': nombreContacto,
      'telefonoContacto': telefonoContacto,
      'equipo': equipo.name,
      'fallaReportada': fallaReportada,
      'evaluacionTecnica': evaluacionTecnica != null
          ? (evaluacionTecnica as EvaluacionTecnicaModel).toJson()
          : null,
      'fotosUrls': fotosUrls,
      'pdfActaUrl': pdfActaUrl,
      'historialEventos': historialEventos
          .map((e) => (e as EventoAuditoriaModel).toJson())
          .toList(),
    };
  }
}