// lib/features/tickets/presentation/bloc/ticket_event.dart

import 'package:equatable/equatable.dart';
import '../../domain/entities/ticket_entity.dart';

abstract class TicketEvent extends Equatable {
  const TicketEvent();

  @override
  List<Object> get props => [];
}

// 1. Pulsador de Arranque: Carga inicial de datos del ERP
class ObtenerClientesEvent extends TicketEvent {}

// 2. Etapa 1: Comercial ingresa un equipo nuevo
class CrearTicketEvent extends TicketEvent {
  final TicketEntity ticket;
  final String nombreUsuario;
  final String rolUsuario;

  const CrearTicketEvent({
    required this.ticket,
    required this.nombreUsuario,
    required this.rolUsuario,
  });

  @override
  List<Object> get props => [ticket, nombreUsuario, rolUsuario];
}

// 3. Etapa 2: Tyron en el taller emite su diagnóstico
class ActualizarEvaluacionEvent extends TicketEvent {
  final TicketEntity ticket;

const ActualizarEvaluacionEvent({required this.ticket});

  @override
  List<Object> get props => [ticket];
}

// 4. Etapa 3: Gatillo final para Firebase y el Webhook de Python
class NotificarYGenerarActaEvent extends TicketEvent {
  final TicketEntity ticket;

  const NotificarYGenerarActaEvent(this.ticket);

  @override
  List<Object> get props => [ticket];
}

class ObtenerHistorialTicketsEvent extends TicketEvent {}

// Añadir al final de lib/features/tickets/presentation/bloc/ticket_event.dart

class ConfirmarRecepcionEvent extends TicketEvent {
  final TicketEntity ticket;
  final String nombreUsuario;
  final String rolUsuario;
  final String notasRecepcion;

  const ConfirmarRecepcionEvent({
    required this.ticket,
    required this.nombreUsuario,
    required this.rolUsuario,
    this.notasRecepcion = '',
  });

  @override
  List<Object> get props => [ticket, nombreUsuario, rolUsuario, notasRecepcion];
}