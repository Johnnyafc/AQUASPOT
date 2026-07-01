// lib/features/tickets/data/models/ticket_model.dart

import 'dart:math';

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
    required super.emailContacto,
    required super.equipo,
    required super.equipoDetalle,
    required super.fallaReportada,
    super.accesoriosRecibidos,
    super.numeroSerie, // ✅ CONSTRUCTOR: Parámetro aceptado
    super.evaluacionTecnica,
    super.fotosUrls = const [],
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
      emailContacto: json['emailContacto'] ?? '',
      equipoDetalle: json['equipoDetalle'] as String?,
      equipo: TipoEquipo.values.firstWhere(
        (e) => e.name == json['equipo'],
        orElse: () => TipoEquipo.Cosechadora_standart,
      ),
      accesoriosRecibidos: json['accesoriosRecibidos'] != null 
          ? Map<String, bool>.from(json['accesoriosRecibidos'] as Map)
          : null,
      fallaReportada: json['fallaReportada'] ?? '',
      numeroSerie: json['numeroSerie'] ?? (json['evaluacionTecnica'] != null ? json['evaluacionTecnica']['serieEquipo'] : null),// ✅ LECTURA: Recuperamos el dato del JSON de Firebase
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

  factory TicketModel.fromEntity(TicketEntity entity) {
    return TicketModel(
      id: entity.id,
      estadoActual: entity.estadoActual,
      sede: entity.sede,
      clienteId: entity.clienteId,
      campamento: entity.campamento,
      nombreContacto: entity.nombreContacto,
      telefonoContacto: entity.telefonoContacto,
      emailContacto: entity.emailContacto,
      equipo: entity.equipo,
      equipoDetalle: entity.equipoDetalle,
      fallaReportada: entity.fallaReportada,
      accesoriosRecibidos:entity.accesoriosRecibidos,
      numeroSerie: entity.numeroSerie, // ✅ MAPEO: De la entidad abstracta al modelo concreto
      evaluacionTecnica: entity.evaluacionTecnica != null
          ? EvaluacionTecnicaModel.fromEntity(entity.evaluacionTecnica!)
          : null,
      fotosUrls: entity.fotosUrls,
      pdfActaUrl: entity.pdfActaUrl,
      historialEventos: entity.historialEventos
          .map((e) => EventoAuditoriaModel.fromEntity(e))
          .toList(),
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
      'emailContacto': emailContacto,
      'equipo': equipo.name,
      'equipoDetalle': equipoDetalle,
      'fallaReportada': fallaReportada,
      'numeroSerie': numeroSerie, // ✅ ESCRITURA: Empaquetamos el dato para enviarlo a Firebase
      'accesoriosRecibidos': accesoriosRecibidos,
      
      'evaluacionTecnica': evaluacionTecnica != null
          ? EvaluacionTecnicaModel.fromEntity(evaluacionTecnica!).toJson()
          : null,
          
      'fotosUrls': fotosUrls,
      'pdfActaUrl': pdfActaUrl,
      
      'historialEventos': historialEventos
          .map((e) => EventoAuditoriaModel.fromEntity(e).toJson())
          .toList(),
    };
  }
}