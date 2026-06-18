// lib/features/tickets/data/models/evento_auditoria_model.dart

import 'package:cloud_firestore/cloud_firestore.dart'; // ✅ Importación crítica
import '../../domain/entities/evento_auditoria_entity.dart';

class EventoAuditoriaModel extends EventoAuditoriaEntity {
  const EventoAuditoriaModel({
    required super.accion,
    required super.usuarioNombre,
    required super.usuarioRol,
    required super.timestamp,
  });

  factory EventoAuditoriaModel.fromJson(Map<String, dynamic> json) {
    // ✅ Conversión de Timestamp de Firestore a DateTime de Dart
    final timestamp = json['timestamp'] is Timestamp 
        ? (json['timestamp'] as Timestamp).toDate() 
        : DateTime.parse(json['timestamp']); // Fallback por si acaso

    return EventoAuditoriaModel(
      accion: json['accion'] ?? '',
      usuarioNombre: json['usuarioNombre'] ?? '',
      usuarioRol: json['usuarioRol'] ?? '',
      timestamp: timestamp,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'accion': accion,
      'usuarioNombre': usuarioNombre,
      'usuarioRol': usuarioRol,
      // ✅ Conversión de DateTime de Dart a Timestamp de Firestore
      // Esto elimina el error de "invalid-argument" en arrays
      'timestamp': Timestamp.fromDate(timestamp), 
    };
  }
}