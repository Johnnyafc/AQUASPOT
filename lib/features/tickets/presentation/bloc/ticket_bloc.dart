// lib/features/tickets/presentation/bloc/ticket_bloc.dart

import 'dart:typed_data';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/usecases/crear_ticket_usecase.dart';
import '../../domain/usecases/notificar_y_generar_acta_usecase.dart';
import '../../domain/usecases/obtener_clientes_usecase.dart';
import '../../domain/usecases/obtener_tickets_usecase.dart'; 
import '../../domain/usecases/ActualizarTicketUseCase.dart'; 
import '../../domain/usecases/subir_evidencia_usecase.dart'; 
import '../../domain/usecases/subir_acta_pdf_usecase.dart';
import '../../domain/usecases/generar_acta_pdf_usecase.dart'; 
import '../../domain/entities/evento_auditoria_entity.dart';
import '../../domain/entities/ticket_entity.dart';
import '../../domain/entities/ticket_enums.dart';
import 'dart:io';  
import 'ticket_event.dart';
import 'ticket_state.dart'; // Asegúrate de estar importando el nuevo TicketState unificado

class TicketBloc extends Bloc<TicketEvent, TicketState> {
  final ObtenerClientesUseCase obtenerClientes;
  final CrearTicketUseCase crearTicket;
  final NotificarYGenerarActaUseCase notificarYGenerarActa;
  final ObtenerTicketsUseCase obtenerTickets; 
  final ActualizarTicketUseCase actualizarTicket;
  final SubirEvidenciaUseCase subirEvidenciaUseCase; 
  final SubirActaPdfUseCase subirActaPdfUseCase;
  final GenerarActaPdfUseCase generarActaPdfUseCase;

  TicketBloc({
    required this.obtenerClientes,
    required this.crearTicket,
    required this.notificarYGenerarActa,
    required this.obtenerTickets,
    required this.actualizarTicket,
    required this.subirEvidenciaUseCase,
    required this.subirActaPdfUseCase,
    required this.generarActaPdfUseCase,
  }) : super(const TicketState()) { // Inicializamos con el estado base unificado
    on<ObtenerClientesEvent>(_onObtenerClientes);
    on<CrearTicketEvent>(_onCrearTicket);
    on<ActualizarEvaluacionEvent>(_onActualizarEvaluacion);
    on<NotificarYGenerarActaEvent>(_onNotificarYGenerarActa);
    on<ObtenerHistorialTicketsEvent>(_onObtenerHistorialTickets);
    on<ConfirmarRecepcionEvent>(_onConfirmarRecepcion);
    on<SubirEvidenciaEvent>(_onSubirEvidencia);
  }

Future<void> _onSubirEvidencia(SubirEvidenciaEvent event, Emitter<TicketState> emit) async {
    emit(state.copyWith(
      status: TicketStatus.loading, 
      message: 'Transmitiendo archivo pesado al Storage...'
    ));

    // Asumiendo que tu evento tiene event.file y event.ticketId
    final result = await subirEvidenciaUseCase(event.file, event.ticketId);

    result.fold(
      (failure) => emit(state.copyWith(
        status: TicketStatus.error,
        message: _mapFailureToMessage(failure)
      )),
      (urlDescarga) => emit(state.copyWith(
        status: TicketStatus.evidenceUploaded,
        message: 'Foto procesada y almacenada.',
        evidenciaUrl: urlDescarga, // ⚙️ Inyectamos la URL para que la UI la pinte inmediatamente
      )),
    );
  }


Future<void> _onNotificarYGenerarActa(NotificarYGenerarActaEvent event, Emitter<TicketState> emit) async {
    emit(state.copyWith(
      status: TicketStatus.loading, 
      message: 'Disparando webhook y consolidando estado final...'
    ));

    final result = await notificarYGenerarActa(event.ticket);

    result.fold(
      (failure) => emit(state.copyWith(
        status: TicketStatus.error,
        message: _mapFailureToMessage(failure)
      )),
      (ticketCerrado) {
        // ⚙️ HOT SWAP
        final listaActualizada = state.tickets.map((t) => 
          t.id == ticketCerrado.id ? ticketCerrado : t
        ).toList();

        emit(state.copyWith(
          status: TicketStatus.operationSuccess,
          message: 'Operación cerrada y backend notificado.',
          tickets: listaActualizada,
          currentTicket: ticketCerrado,
        ));
      },
    );
  }


Future<void> _onActualizarEvaluacion(ActualizarEvaluacionEvent event, Emitter<TicketState> emit) async {
    emit(state.copyWith(
      status: TicketStatus.loading, 
      message: 'Transmitiendo actualización de evaluación al servidor...'
    ));

    final result = await actualizarTicket(event.ticket);

    result.fold(
      (failure) => emit(state.copyWith(
        status: TicketStatus.error,
        message: _mapFailureToMessage(failure)
      )),
      (ticketActualizado) {
        // ⚙️ HOT SWAP: Buscamos el ticket desactualizado en memoria y lo reemplazamos
        final listaActualizada = state.tickets.map((t) => 
          t.id == ticketActualizado.id ? ticketActualizado : t
        ).toList();

        emit(state.copyWith(
          status: TicketStatus.operationSuccess,
          message: 'Evaluación técnica sincronizada con la matriz.',
          tickets: listaActualizada, // Mantenemos la lista, pero con el equipo actualizado
          currentTicket: ticketActualizado, // Por si la vista de detalle lo necesita
        ));
      },
    );
  }


  Future<void> _onObtenerHistorialTickets(ObtenerHistorialTicketsEvent event, Emitter<TicketState> emit) async {
    emit(state.copyWith(status: TicketStatus.loading, message: 'Consultando telemetría histórica...'));

    // Asumo que tu evento o caso de uso tiene la lógica para traer el historial
    final result = await obtenerTickets(); // Pásale los parámetros de segmento si los requiere

    result.fold(
      (failure) => emit(state.copyWith(
        status: TicketStatus.error,
        message: _mapFailureToMessage(failure)
      )),
      (listaTickets) => emit(state.copyWith(
        status: TicketStatus.loaded,
        historial: listaTickets, // O usar state.tickets dependiendo de tu UI
      )),
    );
  }

  Future<void> _onCrearTicket(CrearTicketEvent event, Emitter<TicketState> emit) async {
    emit(state.copyWith(
      status: TicketStatus.loading, 
      message: 'Transmitiendo nuevo ticket a la base de datos...'
    ));

    final result = await crearTicket(event.ticket);

    result.fold(
      (failure) => emit(state.copyWith(
        status: TicketStatus.error,
        message: _mapFailureToMessage(failure)
      )),
      (ticketCreado) {
        // ⚙️ Preservamos la memoria: Clonamos la lista actual y le sumamos el nuevo ticket
        final listaActualizada = List<TicketEntity>.from(state.tickets)..add(ticketCreado);
        
        emit(state.copyWith(
          status: TicketStatus.operationSuccess,
          message: 'Ticket generado con éxito en el sistema.',
          tickets: listaActualizada, // Inyectamos la lista actualizada
        ));
      },
    );
  }

Future<void> _onObtenerClientes(ObtenerClientesEvent event, Emitter<TicketState> emit) async {
    // Señal de arranque: Mantenemos lo que hay, pero pasamos a estado de carga
    emit(state.copyWith(status: TicketStatus.loading));

    final result = await obtenerClientes();

    result.fold(
      (failure) => emit(state.copyWith(
        status: TicketStatus.error,
        message: _mapFailureToMessage(failure)
      )),
      (clientesObtenidos) => emit(state.copyWith(
        status: TicketStatus.loaded,
        clientes: clientesObtenidos, // ⚙️ Inyectamos la lista en el estado
      )),
    );
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

  // ========================================================
  // 🚀 RUTINA DE RECEPCIÓN FÍSICA Y EMISIÓN DE ACTA (CORREGIDA)
  // ========================================================
Future<void> _onConfirmarRecepcion(ConfirmarRecepcionEvent event, Emitter<TicketState> emit) async {
    // ⚠️ ALERTA ARQUITECTÓNICA: Usamos state.copyWith para preservar las listas en memoria
    emit(state.copyWith(
      status: TicketStatus.loading, 
      message: 'Iniciando fase de transmisión de evidencias fotográficas...'
    ));

    List<String> urlsNuevas = [];

    // 1. FASE DE TRANSMISIÓN 1: Subida de evidencias (Fotos)
    if (event.evidencias.isNotEmpty) {
      for (final file in event.evidencias) {
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

        if (tieneFalla) {
          emit(state.copyWith(
            status: TicketStatus.error, 
            message: "Falla al subir fotos: $mensajeFalla"
          ));
          return; // Abortar secuencia, disparo de parada de emergencia
        }
      }
    }

    emit(state.copyWith(
      status: TicketStatus.loading, 
      message: 'Consolidando parámetros y fabricando documento PDF...'
    ));

    // 2. CONSOLIDACIÓN DE DATOS (EL CEREBRO DEL BLOC)
    final List<String> urlsTotales = [...event.ticket.fotosUrls, ...urlsNuevas];
    
    final eventoRecepcion = EventoAuditoriaEntity(
      accion: 'RECEPCIÓN FÍSICA Y EMISIÓN DE ACTA',
      usuarioNombre: event.nombreUsuario,
      usuarioRol: event.rolUsuario,
      timestamp: DateTime.now(),
    );

    // ⚙️ AQUÍ SE HACE LA INGENIERÍA: Ensamblamos todas las piezas nuevas en la entidad
    final ticketActualizado = event.ticket.copyWith(
      estadoActual: EstadoTicket.recepcionFisica, // 🚀 TRASPASO DE ESTADO
      numeroSerie: event.numeroSerie,        // Datos del evento
      fallaReportada: event.fallaReportada, // Datos del evento
      accesoriosRecibidos: event.accesoriosRecibidos, // Datos del evento
      fotosUrls: urlsTotales,                     // Fotos procesadas
      historialEventos: [...event.ticket.historialEventos, eventoRecepcion], 
    );

    // 3. FASE DE FABRICACIÓN: El Dominio genera el PDF con el ticket ya mutado
    final pdfBytesResult = await generarActaPdfUseCase(
      ticket: ticketActualizado,
      tipoRequerimiento: event.tipoRequerimiento, 
      descripcion: event.notasRecepcion,
      evidencias: event.evidencias,
    );

    Uint8List? bytesGenerados;
    bool falloGeneracion = false;
    String mensajeFalloGeneracion = '';

    pdfBytesResult.fold(
      (failure) {
        falloGeneracion = true;
        mensajeFalloGeneracion = _mapFailureToMessage(failure);
      },
      (bytes) => bytesGenerados = bytes,
    );

    if (falloGeneracion || bytesGenerados == null) {
      emit(state.copyWith(
        status: TicketStatus.error, 
        message: "Fallo crítico al renderizar el documento PDF: $mensajeFalloGeneracion"
      ));
      return;
    }

    emit(state.copyWith(
      status: TicketStatus.loading, 
      message: 'Transmitiendo acta al servidor de almacenamiento...'
    ));

    // 4. FASE DE TRANSMISIÓN 2: Subida del Acta PDF a Firestore Storage
    final pdfUploadResult = await subirActaPdfUseCase(ticketActualizado.id, bytesGenerados!);
    
    String urlPdfFinal = '';
    bool falloPdf = false;
    String mensajeFalloPdf = '';

    pdfUploadResult.fold(
      (failure) {
        falloPdf = true;
        mensajeFalloPdf = _mapFailureToMessage(failure);
      },
      (url) => urlPdfFinal = url,
    );

    if (falloPdf) {
      emit(state.copyWith(
        status: TicketStatus.error, 
        message: "Falla de telemetría al guardar el documento PDF: $mensajeFalloPdf"
      ));
      return;
    }

    // 5. ENSAMBLAJE FINAL Y PERSISTENCIA (Actuador de BD)
    final ticketFinal = ticketActualizado.copyWith(
      pdfActaUrl: urlPdfFinal,
    );

    final dbResult = await actualizarTicket(ticketFinal); 
    
    dbResult.fold(
      (failure) => emit(state.copyWith(
        status: TicketStatus.error, 
        message: _mapFailureToMessage(failure)
      )),
      (ticketGuardado) {
        // ⚙️ HOT SWAP: Actualizamos la memoria RAM de la lista de tickets
        final listaActualizada = state.historial.map((t) => 
          t.id == ticketGuardado.id ? ticketGuardado : t
        ).toList();

        emit(state.copyWith(
          status: TicketStatus.operationSuccess, 
          message: 'Recepción confirmada y acta generada con éxito.',
          historial: listaActualizada, // Inyectamos la nueva matriz
          currentTicket: ticketGuardado,
          pdfBytes: bytesGenerados, // ¡Inyectado directo al estado para impresión!
        ));
      }
    );
  }
}