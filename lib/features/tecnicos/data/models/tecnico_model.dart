// lib/features/tecnicos/data/models/tecnico_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/tecnico_entity.dart';

class TecnicoModel extends TecnicoEntity {
  const TecnicoModel({
    required super.id,
    required super.nombre,
    required super.rol,
    super.activo = true,
    required super.fechaRegistro,
  });

  factory TecnicoModel.fromJson(Map<String, dynamic> json, {String? docId}) {
    DateTime fecha = DateTime.now();
    if (json['fechaRegistro'] != null) {
      if (json['fechaRegistro'] is Timestamp) {
        fecha = (json['fechaRegistro'] as Timestamp).toDate();
      } else if (json['fechaRegistro'] is String) {
        fecha = DateTime.tryParse(json['fechaRegistro'] as String) ?? DateTime.now();
      }
    }

    return TecnicoModel(
      id: docId ?? json['id']?.toString() ?? '',
      nombre: json['nombre']?.toString() ?? '',
      rol: json['rol']?.toString() ?? 'Técnico General',
      activo: json['activo'] as bool? ?? true,
      fechaRegistro: fecha,
    );
  }

  factory TecnicoModel.fromEntity(TecnicoEntity entity) {
    return TecnicoModel(
      id: entity.id,
      nombre: entity.nombre,
      rol: entity.rol,
      activo: entity.activo,
      fechaRegistro: entity.fechaRegistro,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nombre': nombre,
      'rol': rol,
      'activo': activo,
      'fechaRegistro': Timestamp.fromDate(fechaRegistro),
    };
  }
}
