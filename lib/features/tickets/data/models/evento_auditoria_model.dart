// lib/features/tickets/data/models/evento_auditoria_model.dart

import '../../domain/entities/evento_auditoria_entity.dart';

class EventoAuditoriaModel extends EventoAuditoriaEntity {
  const EventoAuditoriaModel({
    required super.accion,
    required super.usuarioNombre,
    required super.usuarioRol,
    required super.timestamp,
  });

  factory EventoAuditoriaModel.fromJson(Map<String, dynamic> json) {
    return EventoAuditoriaModel(
      accion: json['accion'] ?? '',
      usuarioNombre: json['usuarioNombre'] ?? '',
      usuarioRol: json['usuarioRol'] ?? '',
      timestamp: DateTime.parse(json['timestamp']), // Asumimos ISO-8601
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'accion': accion,
      'usuarioNombre': usuarioNombre,
      'usuarioRol': usuarioRol,
      'timestamp': timestamp.toIso8601String(), // Estándar industrial para fechas
    };
  }
}