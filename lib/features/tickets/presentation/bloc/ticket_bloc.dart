// lib/features/tickets/presentation/bloc/ticket_bloc.dart

import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/usecases/crear_ticket_usecase.dart';
import '../../domain/usecases/notificar_y_generar_acta_usecase.dart';
import '../../domain/usecases/obtener_clientes_usecase.dart';
import '../../domain/usecases/obtener_tickets_usecase.dart'; 
import '../../domain/usecases/ActualizarTicketUseCase.dart'; 
import '../../domain/usecases/subir_evidencia_usecase.dart'; 
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
  final SubirEvidenciaUseCase subirEvidenciaUseCase; 

  TicketBloc({
    required this.obtenerClientes,
    required this.crearTicket,
    required this.notificarYGenerarActa,
    required this.obtenerTickets,
    required this.actualizarTicket,
    required this.subirEvidenciaUseCase, 
  }) : super(TicketInitial()) {
    on<ObtenerClientesEvent>(_onObtenerClientes);
    on<CrearTicketEvent>(_onCrearTicket);
    on<ActualizarEvaluacionEvent>(_onActualizarEvaluacion);
    on<NotificarYGenerarActaEvent>(_onNotificarYGenerarActa);
    on<ObtenerHistorialTicketsEvent>(_onObtenerHistorialTickets);
    on<ConfirmarRecepcionEvent>(_onConfirmarRecepcion);
    on<SubirEvidenciaEvent>(_onSubirEvidencia);
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

  // 1. Sincronización de tiempos e identificación única del requerimiento
  final marcaDeTiempo = DateTime.now();
  final idGenerado = 'REQ-${marcaDeTiempo.millisecondsSinceEpoch}';

  // 2. Registro del bloque de auditoría interna
  final eventoAuditoria = EventoAuditoriaEntity(
    accion: 'CREACIÓN DE REQUERIMIENTO',
    usuarioNombre: event.nombreUsuario,
    usuarioRol: event.rolUsuario,
    timestamp: marcaDeTiempo,
  );

  // Buffer para almacenar los enlaces de descarga de las imágenes
  final List<String> urlsSubidas = [];

  // 3. LAZO DE TRANSMISIÓN: Subida secuencial de evidencias físicas
  // Accedemos a la lista de archivos que viene en tu 'event.evidencias'
  if (event.evidencias.isNotEmpty) {
    for (final file in event.evidencias) {
      // Usamos el idGenerado para estructurar la jerarquía del bucket
      final uploadResult = await subirEvidenciaUseCase(file, idGenerado);
      
      bool tieneFalla = false;
      String mensajeFalla = '';

      uploadResult.fold(
        (failure) {
          tieneFalla = true;
          mensajeFalla = _mapFailureToMessage(failure);
        },
        (url) => urlsSubidas.add(url),
      );

      // INTERRUPCIÓN POR FALLA: Si una foto falla, paramos el proceso para evitar JSONs corruptos
      if (tieneFalla) {
        emit(TicketError(message: mensajeFalla));
        return; 
      }
    }
  }

  // 4. ENSAMBLAJE FINAL DEL OBJETO (Con todas tus variables intactas + el vector de URLs)
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
    fotosUrls: urlsSubidas, // ✅ Vinculación de los archivos multimedia al requerimiento
  );

  // 5. PERSISTENCIA EN FIRESTORE
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

Future<void> _onSubirEvidencia(SubirEvidenciaEvent event, Emitter<TicketState> emit) async {
    emit(TicketLoading()); // Mostramos un loader en la UI
    final failureOrUrl = await subirEvidenciaUseCase(event.file, event.ticketId);
    
    failureOrUrl.fold(
      (failure) => emit(TicketError(message: _mapFailureToMessage(failure))),
      (url) => emit(TicketEvidenciaSubida(url: url)),
    );
  }


// lib/features/tickets/presentation/bloc/ticket_bloc.dart

Future<void> _onConfirmarRecepcion(ConfirmarRecepcionEvent event, Emitter<TicketState> emit) async {
  emit(TicketLoading());

  List<String> urlsNuevas = [];

  // 1. FASE DE TRANSMISIÓN: Subida secuencial de evidencias al bucket
  if (event.evidencias.isNotEmpty) {
    for (final file in event.evidencias) {
      // ✅ Usamos el ID del ticket original para guardarlo en su carpeta correcta
      final uploadResult = await subirEvidenciaUseCase(file, event.ticket.id);
      
      bool tieneFalla = false;
      String mensajeFalla = '';

      uploadResult.fold(
        (failure) {
          tieneFalla = true;
          mensajeFalla = _mapFailureToMessage(failure);
        },
        (url) => urlsNuevas.add(url),
      );

      // PARADA DE EMERGENCIA: Si falla una foto, abortamos la actualización
      if (tieneFalla) {
        emit(TicketError(message: mensajeFalla));
        return; 
      }
    }
  }

  // 2. ENSAMBLAJE: Fusionamos las URLs que ya tenía el ticket con las nuevas
final List<String> urlsTotales = [...event.ticket.fotosUrls, ...urlsNuevas];
  
  // ✅ CREAMOS EL REGISTRO DE AUDITORÍA
  final eventoRecepcion = EventoAuditoriaEntity(
    accion: 'RECEPCIÓN FÍSICA Y CAPTURA DE EVIDENCIA',
    usuarioNombre: event.nombreUsuario,
    usuarioRol: event.rolUsuario,
    timestamp: DateTime.now(),
  );

  final ticketListoParaActualizar = event.ticket.copyWith(
    fotosUrls: urlsTotales,
    // ✅ AÑADIMOS EL EVENTO AL LOG HISTÓRICO
    historialEventos: [...event.ticket.historialEventos, eventoRecepcion], 
  );

  // 3. PERSISTENCIA: Ejecutamos la sobrescritura en Firestore
  // ✅ Usamos actualizarTicket en lugar de crearTicket
  final dbResult = await actualizarTicket(ticketListoParaActualizar); 
  
  dbResult.fold(
    (failure) => emit(TicketError(message: _mapFailureToMessage(failure))),
    (ticketActualizado) => emit(TicketOperationSuccess(message: 'Recepción confirmada y evidencias subidas con éxito')), 
  );
}
}