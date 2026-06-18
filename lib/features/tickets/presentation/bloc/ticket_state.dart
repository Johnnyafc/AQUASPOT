// lib/features/tickets/presentation/bloc/ticket_state.dart

import 'package:equatable/equatable.dart';
import '../../domain/entities/cliente_entity.dart';
import '../../domain/entities/ticket_entity.dart';

abstract class TicketState extends Equatable {
  const TicketState();
  
  @override
  List<Object?> get props => [];
}

// 1. Estado de Reposo (Máquina energizada pero sin orden de marcha)
class TicketInitial extends TicketState {}

// 2. Estado de Trabajo (Contactores cerrados, esperando respuesta de Firebase/FastAPI)
class TicketLoading extends TicketState {}

// 3. Estado de Lectura Exitosa (Datos cargados en el SCADA)
class TicketLoaded extends TicketState {
  final List<TicketEntity> tickets; // Para la bandeja de Tyron y Medardo
  final List<ClienteEntity> clientes; // Para llenar el Dropdown de la Etapa 1

  const TicketLoaded({this.tickets = const [], this.clientes = const []});

  @override
  List<Object?> get props => [tickets, clientes];
}

// 4. Estado de Ejecución Exitosa (Un pulso momentáneo para mostrar un "Toast" o cambiar de pantalla)
class TicketOperationSuccess extends TicketState {
  final String message;
  final TicketEntity? ticket;

  const TicketOperationSuccess({required this.message, this.ticket});

  @override
  List<Object?> get props => [message, ticket];
}

// 5. Estado de Alarma (Fallo de red, error de servidor, validación fallida)
class TicketError extends TicketState {
  final String message;

  const TicketError({required this.message});

  @override
  List<Object?> get props => [message];
}

class TicketHistorialCargado extends TicketState {
  final List<TicketEntity> tickets;
  const TicketHistorialCargado({required this.tickets});
  @override
  List<Object?> get props => [tickets];
}