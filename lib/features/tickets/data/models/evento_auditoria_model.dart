// lib/features/tickets/data/models/evento_auditoria_model.dart

import 'package:cloud_firestore/cloud_firestore.dart'; // ✅ Importación crítica
import '../../domain/entities/evento_auditoria_entity.dart';
import '../../../../core/enum/proceso_auditoria.dart';

class EventoAuditoriaModel extends EventoAuditoriaEntity {
  const EventoAuditoriaModel({
    required super.accion,
    required super.usuarioNombre,
    required super.usuarioRol,
    required super.timestamp,
    super.proceso,
    super.hito,
    super.habilita = const [],
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
      proceso: ProcesoAuditoria.values.cast<ProcesoAuditoria?>().firstWhere(
        (p) => p?.name == json['proceso'],
        orElse: () => null,
      ),
      hito: HitoProceso.values.cast<HitoProceso?>().firstWhere(
        (h) => h?.name == json['hito'],
        orElse: () => null,
      ),
      habilita: (json['habilita'] as List?)
              ?.map((n) => ProcesoAuditoria.values.cast<ProcesoAuditoria?>().firstWhere(
                    (p) => p?.name == n,
                    orElse: () => null,
                  ))
              .whereType<ProcesoAuditoria>()
              .toList() ??
          const [],
    );
  }

  factory EventoAuditoriaModel.fromEntity(EventoAuditoriaEntity entity) {
    return EventoAuditoriaModel(
      accion: entity.accion,
      usuarioNombre: entity.usuarioNombre,
      usuarioRol: entity.usuarioRol,
      timestamp: entity.timestamp,
      proceso: entity.proceso,
      hito: entity.hito,
      habilita: entity.habilita,
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
      // Solo se escriben si existen: los eventos sin etiqueta quedan con
      // la misma forma de siempre en Firestore.
      if (proceso != null) 'proceso': proceso!.name,
      if (hito != null) 'hito': hito!.name,
      if (habilita.isNotEmpty) 'habilita': habilita.map((p) => p.name).toList(),
    };
  }
}