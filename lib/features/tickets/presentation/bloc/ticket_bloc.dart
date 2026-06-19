// lib/features/tickets/presentation/bloc/ticket_bloc.dart

import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/usecases/crear_ticket_usecase.dart';
import '../../domain/usecases/notificar_y_generar_acta_usecase.dart';
import '../../domain/usecases/obtener_clientes_usecase.dart';
import '../../domain/usecases/obtener_tickets_usecase.dart'; 
import '../../domain/usecases/ActualizarTicketUseCase.dart'; 
import '../../domain/entities/evento_auditoria_entity.dart';
import '../../domain/entities/ticket_entity.dart';
import '../../domain/entities/ticket_enums.dart'; 
import 'ticket_event.dart';
import 'ticket_state.dart';

class TicketBloc extends Bloc<TicketEvent, TicketState> {
  final ObtenerClientesUseCase obtenerClientes;
  final CrearTicketUseCase crearTicket;
  final NotificarYGenerarActaUseCase notificarYGenerarActa;
  final ObtenerTicketsUseCase obtenerTickets; 
  final ActualizarTicketUseCase actualizarTicket; 

  TicketBloc({
    required this.obtenerClientes,
    required this.crearTicket,
    required this.notificarYGenerarActa,
    required this.obtenerTickets,
    required this.actualizarTicket, 
  }) : super(TicketInitial()) {
    on<ObtenerClientesEvent>(_onObtenerClientes);
    on<CrearTicketEvent>(_onCrearTicket);
    on<ActualizarEvaluacionEvent>(_onActualizarEvaluacion);
    on<NotificarYGenerarActaEvent>(_onNotificarYGenerarActa);
    on<ObtenerHistorialTicketsEvent>(_onObtenerHistorialTickets);
    on<ConfirmarRecepcionEvent>(_onConfirmarRecepcion);
  }

  String _mapFailureToMessage(Failure failure) {
    switch (failure.runtimeType) {
      case ServerFailure: 
        return 'Fallo de comunicación con los servidores SCADA (Firebase).';
      case NetworkFailure:
        return 'Sin conexión a internet en el campamento.';
      default:
        return 'Error de sistema no clasificado.';
    }
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

    final marcaDeTiempo = DateTime.now();
    final idGenerado = 'REQ-${marcaDeTiempo.millisecondsSinceEpoch}';

    final eventoAuditoria = EventoAuditoriaEntity(
      accion: 'CREACIÓN DE REQUERIMIENTO',
      usuarioNombre: event.nombreUsuario,
      usuarioRol: event.rolUsuario,
      timestamp: marcaDeTiempo,
    );

    final ticketFinal = TicketEntity(
      id: idGenerado,
      estadoActual: event.ticket.estadoActual,
      sede: event.ticket.sede,
      clienteId: event.ticket.clienteId,
      campamento: event.ticket.campamento,
      nombreContacto: event.ticket.nombreContacto,
      telefonoContacto: event.ticket.telefonoContacto,
      equipo: event.ticket.equipo,
      fallaReportada: event.ticket.fallaReportada,
      numeroSerie: event.ticket.numeroSerie,
      historialEventos: [eventoAuditoria], 
    );

    final failureOrTicket = await crearTicket(ticketFinal);

    failureOrTicket.fold(
      (failure) {
        emit(TicketError(message: _mapFailureToMessage(failure))); 
      },
      (ticketCreado) {
        emit(TicketOperationSuccess(message: 'Requerimiento registrado con éxito'));
      },
    );
  }

  Future<void> _onActualizarEvaluacion(ActualizarEvaluacionEvent event, Emitter<TicketState> emit) async {
    emit(TicketLoading());
    final failureOrTicket = await actualizarTicket(event.ticket);
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

  Future<void> _onObtenerHistorialTickets(ObtenerHistorialTicketsEvent event, Emitter<TicketState> emit) async {
    emit(TicketLoading());
    
    final failureOrTickets = await obtenerTickets();
    
    failureOrTickets.fold(
      (failure) => emit(TicketError(message: _mapFailureToMessage(failure))),
      (tickets) => emit(TicketHistorialCargado(tickets: tickets)),
    );
  }

  Future<void> _onConfirmarRecepcion(ConfirmarRecepcionEvent event, Emitter<TicketState> emit) async {
    emit(TicketLoading());

    // 1. Registro de Auditoría (Con notas integradas si existen)
    final detallesNotas = event.notasRecepcion.isNotEmpty ? ' - Notas: ${event.notasRecepcion}' : '';
    final eventoAuditoria = EventoAuditoriaEntity(
      accion: 'RECEPCIÓN FÍSICA EN TALLER$detallesNotas',
      usuarioNombre: event.nombreUsuario, 
      usuarioRol: event.rolUsuario,
      timestamp: DateTime.now(),
    );

    // 2. Transición de Estado
    final ticketActualizado = event.ticket.copyWith(
      estadoActual: EstadoTicket.evaluacionTecnica, 
      historialEventos: [...event.ticket.historialEventos, eventoAuditoria],
    );

    // 3. Ejecución a través del canal genérico
    final failureOrTicket = await actualizarTicket(ticketActualizado);

    failureOrTicket.fold(
      (failure) => emit(TicketError(message: _mapFailureToMessage(failure))),
      (ticket) => emit(TicketOperationSuccess(
        message: 'Equipo recibido en planta. Encolado para diagnóstico.', 
        ticket: ticket,
      )),
    );
  }
}