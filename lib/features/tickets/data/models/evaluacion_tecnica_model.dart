// lib/features/tickets/data/models/evaluacion_tecnica_model.dart

import '../../domain/entities/evaluacion_tecnica_entity.dart';

class EvaluacionTecnicaModel extends EvaluacionTecnicaEntity {
  const EvaluacionTecnicaModel({
    required super.documentosUrls,
    super.observacion = '',
  });

  factory EvaluacionTecnicaModel.fromJson(Map<String, dynamic> json) {
    return EvaluacionTecnicaModel(
      // ⚙️ CASTEO ESTRICTO: Prevenimos fallos si Firestore devuelve null o un tipo dinámico
      documentosUrls: List<String>.from(json['documentosUrls'] ?? []),
      observacion: json['observacion'] ?? '',
    );
  }

  factory EvaluacionTecnicaModel.fromEntity(EvaluacionTecnicaEntity entity) {
    return EvaluacionTecnicaModel(
      documentosUrls: entity.documentosUrls,
      observacion: entity.observacion,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'documentosUrls': documentosUrls,
      'observacion': observacion,
    };
  }
}