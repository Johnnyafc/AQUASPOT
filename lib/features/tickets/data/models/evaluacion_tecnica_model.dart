// lib/features/tickets/data/models/evaluacion_tecnica_model.dart

import '../../domain/entities/evaluacion_tecnica_entity.dart';
import '../../domain/entities/ticket_enums.dart';

class EvaluacionTecnicaModel extends EvaluacionTecnicaEntity {
  const EvaluacionTecnicaModel({
    required super.serieEquipo,
    required super.diagnostico,
    required super.prioridad,
  });

  factory EvaluacionTecnicaModel.fromJson(Map<String, dynamic> json) {
    return EvaluacionTecnicaModel(
      serieEquipo: json['serieEquipo'] ?? '',
      diagnostico: json['diagnostico'] ?? '',
      prioridad: Prioridad.values.firstWhere(
        (e) => e.name == json['prioridad'],
        orElse: () => Prioridad.media,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'serieEquipo': serieEquipo,
      'diagnostico': diagnostico,
      'prioridad': prioridad.name,
    };
  }
}