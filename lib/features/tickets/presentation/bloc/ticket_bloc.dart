// lib/features/tickets/presentation/bloc/ticket_bloc.dart

import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/usecases/aprobar_evaluacion_usecase.dart';
import '../../domain/usecases/crear_ticket_usecase.dart';
import '../../domain/usecases/notificar_y_generar_acta_usecase.dart';
import '../../domain/usecases/obtener_clientes_usecase.dart';
// ✅ NUEVO: Importación del caso de uso de lectura (Deberás crearlo en domain/usecases)
import '../../domain/usecases/obtener_tickets_usecase.dart'; 
import '../../domain/entities/evento_auditoria_entity.dart';
import '../../domain/entities/ticket_entity.dart';
import 'ticket_event.dart';
import 'ticket_state.dart';

class TicketBloc extends Bloc<TicketEvent, TicketState> {
  final ObtenerClientesUseCase obtenerClientes;
  final CrearTicketUseCase crearTicket;
  final AprobarEvaluacionUseCase aprobarEvaluacion;
  final NotificarYGenerarActaUseCase notificarYGenerarActa;
  
  // ✅ NUEVO: Canal de entrada para la señal de historial
  final ObtenerTicketsUseCase obtenerTickets; 

  TicketBloc({
    required this.obtenerClientes,
    required this.crearTicket,
    required this.aprobarEvaluacion,
    required this.notificarYGenerarActa,
    required this.obtenerTickets,
  }) : super(TicketInitial()) {
    // Mapeo de borneras: Evento -> Función Ejecutora
    on<ObtenerClientesEvent>(_onObtenerClientes);
    on<CrearTicketEvent>(_onCrearTicket);
    on<ActualizarEvaluacionEvent>(_onActualizarEvaluacion);
    on<NotificarYGenerarActaEvent>(_onNotificarYGenerarActa);
    
    // ✅ NUEVO: Conexión del evento de historial
    on<ObtenerHistorialTicketsEvent>(_onObtenerHistorialTickets);
  }

  // Traductor ÚNICO de fallos técnicos a mensajes de Interfaz Humano-Máquina (HMI)
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

  // ✅ NUEVO: Ejecutor de la lectura de historial
  Future<void> _onObtenerHistorialTickets(ObtenerHistorialTicketsEvent event, Emitter<TicketState> emit) async {
    emit(TicketLoading());
    
    final failureOrTickets = await obtenerTickets();
    
    failureOrTickets.fold(
      (failure) => emit(TicketError(message: _mapFailureToMessage(failure))),
      (tickets) => emit(TicketHistorialCargado(tickets: tickets)),
    );
  }
}