// lib/features/tickets/domain/entities/evento_auditoria_entity.dart

import 'package:equatable/equatable.dart';

class EventoAuditoriaEntity extends Equatable {
  final String accion;
  final String usuarioNombre;
  final String usuarioRol;
  final DateTime timestamp;

  const EventoAuditoriaEntity({
    required this.accion,
    required this.usuarioNombre,
    required this.usuarioRol,
    required this.timestamp,
  });

  @override
  List<Object?> get props => [accion, usuarioNombre, usuarioRol, timestamp];
}