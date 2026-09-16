// lib/features/tickets/data/models/actividad_registrada_model.dart
import '../../domain/entities/actividad_registrada_entity.dart';

class ActividadRegistradaModel extends ActividadRegistradaEntity {
  const ActividadRegistradaModel({
    required super.codigo,
    required super.nombre,
    required super.horasHombre,
    required super.observacion,
    super.fotosUrls = const [],
    super.incluye,
  });

  factory ActividadRegistradaModel.fromJson(Map<String, dynamic> json) {
    return ActividadRegistradaModel(
      codigo: json['codigo'] as String? ?? '',
      nombre: json['nombre'] as String? ?? '',
      horasHombre: (json['horasHombre'] as num?)?.toDouble() ?? 0.0,
      observacion: json['observacion'] as String? ?? '',
      fotosUrls: List<String>.from(json['fotosUrls'] ?? []),
      incluye: json['incluye'] as String?,
    );
  }

  factory ActividadRegistradaModel.fromEntity(ActividadRegistradaEntity entity) {
    return ActividadRegistradaModel(
      codigo: entity.codigo,
      nombre: entity.nombre,
      horasHombre: entity.horasHombre,
      observacion: entity.observacion,
      fotosUrls: entity.fotosUrls,
      incluye: entity.incluye,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'codigo': codigo,
      'nombre': nombre,
      'horasHombre': horasHombre,
      'observacion': observacion,
      'fotosUrls': fotosUrls,
      'incluye': incluye,
    };
  }
}
