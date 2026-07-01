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
// 🚀 NUEVO: Inyectamos la máquina de fabricación de PDFs
import '../../domain/usecases/generar_acta_pdf_usecase.dart'; 
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
  final SubirActaPdfUseCase subirActaPdfUseCase;
  final GenerarActaPdfUseCase generarActaPdfUseCase; // ⚙️ NUEVO

  TicketBloc({
    required this.obtenerClientes,
    required this.crearTicket,
    required this.notificarYGenerarActa,
    required this.obtenerTickets,
    required this.actualizarTicket,
    required this.subirEvidenciaUseCase,
    required this.subirActaPdfUseCase,
    required this.generarActaPdfUseCase, // ⚙️ NUEVO
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

  // ... (Tus métodos _onObtenerClientes, _onCrearTicket, _onActualizarEvaluacion, 
  // _onNotificarYGenerarActa, _onObtenerHistorialTickets, _onSubirEvidencia quedan exactamente igual) ...

  // ========================================================
  // 🚀 RUTINA DE RECEPCIÓN FÍSICA CORREGIDA
  // ========================================================
  Future<void> _onConfirmarRecepcion(ConfirmarRecepcionEvent event, Emitter<TicketState> emit) async {
    emit(TicketLoading());

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
          emit(TicketError(message: "Falla al subir fotos: $mensajeFalla"));
          return; 
        }
      }
    }

    // 2. CONSOLIDACIÓN DE DATOS
    // Integramos las nuevas fotos y creamos la auditoría
    final List<String> urlsTotales = [...event.ticket.fotosUrls, ...urlsNuevas];
    
    final eventoRecepcion = EventoAuditoriaEntity(
      accion: 'RECEPCIÓN FÍSICA Y EMISIÓN DE ACTA',
      usuarioNombre: event.nombreUsuario,
      usuarioRol: event.rolUsuario,
      notas: event.notasRecepcion,
      timestamp: DateTime.now(),
    );

    // ⚙️ INYECCIÓN DE DATOS AL TICKET ANTES DE GENERAR EL PDF
    // Actualizamos el ticket con los datos logísticos y las nuevas evidencias
    final ticketActualizado = event.ticket.copyWith(
      fotosUrls: urlsTotales,
      historialEventos: [...event.ticket.historialEventos, eventoRecepcion], 
      // Si tu entidad TicketEntity soporta prioridad y tipoRequerimiento, inyéctalos aquí:
      // prioridad: event.prioridad,
      // tipoRequerimiento: event.tipoRequerimiento,
    );

    // 3. FASE DE FABRICACIÓN: El Dominio genera el PDF
    // Delegamos la renderización al UseCase correspondiente.
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
      emit(TicketError(message: "Fallo crítico al renderizar el documento PDF: $mensajeFalloGeneracion"));
      return;
    }

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
      emit(TicketError(message: "Falla de telemetría al guardar el documento PDF: $mensajeFalloPdf"));
      return;
    }

    // 5. ENSAMBLAJE FINAL Y PERSISTENCIA
    // Añadimos la URL del PDF validado al ticket
    final ticketFinal = ticketActualizado.copyWith(
      pdfActaUrl: urlPdfFinal,
    );

    final dbResult = await actualizarTicket(ticketFinal); 
    
    dbResult.fold(
      (failure) => emit(TicketError(message: _mapFailureToMessage(failure))),
      (ticketGuardado) => emit(TicketRecepcionExitosa(pdfBytes: bytesGenerados!)), 
    );
  }
}