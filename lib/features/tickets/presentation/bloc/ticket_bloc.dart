// lib/features/tickets/presentation/bloc/ticket_bloc.dart

import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/usecases/aprobar_evaluacion_usecase.dart';
import '../../domain/usecases/crear_ticket_usecase.dart';
import '../../domain/usecases/notificar_y_generar_acta_usecase.dart';
import '../../domain/usecases/obtener_clientes_usecase.dart';
import 'ticket_event.dart';
import 'ticket_state.dart';

class TicketBloc extends Bloc<TicketEvent, TicketState> {
  final ObtenerClientesUseCase obtenerClientes;
  final CrearTicketUseCase crearTicket;
  final AprobarEvaluacionUseCase aprobarEvaluacion;
  final NotificarYGenerarActaUseCase notificarYGenerarActa;

  TicketBloc({
    required this.obtenerClientes,
    required this.crearTicket,
    required this.aprobarEvaluacion,
    required this.notificarYGenerarActa,
  }) : super(TicketInitial()) {
    // Mapeo de borneras: Evento -> Función Ejecutora
    on<ObtenerClientesEvent>(_onObtenerClientes);
    on<CrearTicketEvent>(_onCrearTicket);
    on<ActualizarEvaluacionEvent>(_onActualizarEvaluacion);
    on<NotificarYGenerarActaEvent>(_onNotificarYGenerarActa);
  }

  // Traductor de fallos técnicos a mensajes de Interfaz Humano-Máquina (HMI)
  String _mapFailureToMessage(Failure failure) {
    if (failure is ServerFailure) return failure.message;
    if (failure is NetworkFailure) return failure.message;
    return 'Error catastrófico en el circuito lógico.';
  }

Future<void> _onObtenerClientes(ObtenerClientesEvent event, Emitter<TicketState> emit) async {
    emit(TicketLoading()); 
    
    final failureOrClientes = await obtenerClientes(); 
    
    failureOrClientes.fold(
      (failure) => emit(TicketError(message: _mapFailureToMessage(failure))),
      (clientes) => emit(TicketLoaded(clientes: clientes)),
    );
  }

  Future<void> _onCrearTicket(CrearTicketEvent event, Emitter<TicketState> emit) async {
    emit(TicketLoading());
    final failureOrTicket = await crearTicket(event.ticket);
    failureOrTicket.fold(
      (failure) => emit(TicketError(message: _mapFailureToMessage(failure))),
      (ticket) => emit(TicketOperationSuccess(
        message: 'Ticket registrado con éxito en el servidor.', 
        ticket: ticket,
      )),
    );
  }

  Future<void> _onActualizarEvaluacion(ActualizarEvaluacionEvent event, Emitter<TicketState> emit) async {
    emit(TicketLoading());
    final failureOrTicket = await aprobarEvaluacion(event.ticket);
    failureOrTicket.fold(
      (failure) => emit(TicketError(message: _mapFailureToMessage(failure))),
      (ticket) => emit(TicketOperationSuccess(
        message: 'Evaluación técnica del equipo guardada.', 
        ticket: ticket,
      )),
    );
  }

  Future<void> _onNotificarYGenerarActa(NotificarYGenerarActaEvent event, Emitter<TicketState> emit) async {
    emit(TicketLoading());
    final failureOrTicket = await notificarYGenerarActa(event.ticket);
    failureOrTicket.fold(
      (failure) => emit(TicketError(message: _mapFailureToMessage(failure))),
      (ticket) => emit(TicketOperationSuccess(
        message: 'Acta PDF generada y notificada por correo al cliente.', 
        ticket: ticket,
      )),
    );
  }
}