// lib/features/tickets/domain/entities/evaluacion_tecnica_entity.dart

import 'package:equatable/equatable.dart';
import 'ticket_enums.dart';

class EvaluacionTecnicaEntity extends Equatable {
  final String serieEquipo;
  final String diagnostico;
  final Prioridad prioridad;

  const EvaluacionTecnicaEntity({
    required this.serieEquipo,
    required this.diagnostico,
    required this.prioridad,
  });

  @override
  List<Object?> get props => [serieEquipo, diagnostico, prioridad];
}