// lib/features/tickets/domain/entities/evento_auditoria_entity.dart

import 'package:equatable/equatable.dart';
import '../../../../core/enum/proceso_auditoria.dart';

class EventoAuditoriaEntity extends Equatable {
  final String accion;
  final String usuarioNombre;
  final String usuarioRol;
  final DateTime timestamp;

  // 🏷️ Etiquetas para medir tiempos por proceso (ver proceso_auditoria.dart).
  // Opcionales: los eventos antiguos no las tienen.
  final ProcesoAuditoria? proceso;
  final HitoProceso? hito;
  final List<ProcesoAuditoria> habilita;

  const EventoAuditoriaEntity({
    required this.accion,
    required this.usuarioNombre,
    required this.usuarioRol,
    required this.timestamp,
    this.proceso,
    this.hito,
    this.habilita = const [],
  });

  @override
  List<Object?> get props => [accion, usuarioNombre, usuarioRol, timestamp, proceso, hito, habilita];
}