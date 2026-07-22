// lib/features/tickets/presentation/bloc/ticket_bloc.dart

import 'dart:typed_data';
import 'package:aquaspot_postventa/core/errors/exceptions.dart';
import 'package:aquaspot_postventa/features/tickets/data/models/GestionComprasModel.dart';
import 'package:aquaspot_postventa/features/tickets/data/models/proforma_model.dart';
import 'package:aquaspot_postventa/features/tickets/data/models/ticket_model.dart';
import 'package:aquaspot_postventa/features/tickets/domain/entities/evaluacion_tecnica_entity.dart';
import 'package:aquaspot_postventa/features/tickets/domain/entities/evidencia_trabajo_entity.dart';
import 'package:aquaspot_postventa/features/tickets/domain/entities/gestion_compras_entity.dart';
import 'package:aquaspot_postventa/features/tickets/domain/entities/proforma_entity.dart';
import 'package:aquaspot_postventa/features/tickets/domain/repositories/ticket_repository.dart';
import 'package:aquaspot_postventa/features/tickets/domain/usecases/SubirOrdenVentaUseCase.dart';
import 'package:aquaspot_postventa/features/tickets/domain/usecases/subir_documento_comercial_usecase.dart';
import 'package:aquaspot_postventa/features/tickets/domain/usecases/subir_documento_evaluacion_usecase.dart';
import 'package:aquaspot_postventa/features/tickets/domain/usecases/subir_orden_compra_usecase.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
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
import '../../domain/usecases/notificar_y_generar_acta_usecase.dart';
import '../../domain/entities/ticket_entity.dart';
import '../../../../core/enum/ticket_enums.dart';
import 'dart:io';  
import 'dart:async';
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
  final NotificarYGenerarActaUseCase notificarYGenerarActaUseCase;
  final SubirDocumentoEvaluacionUseCase subirDocumentoEvaluacionUseCase;
  final SubirDocumentoComercialUseCase subirDocumentoComercialUseCase;
  final SubirOrdenVentaUseCase subirOrdenVentaUseCase;
  final SubirOrdenCompraUseCase subirOrdenCompraUseCase;
  final ITicketRepository ticketRepository;
  
  TicketBloc({
    required this.subirDocumentoEvaluacionUseCase,
    required this.obtenerClientes,
    required this.crearTicket,
    required this.notificarYGenerarActa,
    required this.obtenerTickets,
    required this.actualizarTicket,
    required this.subirEvidenciaUseCase,
    required this.subirActaPdfUseCase,
    required this.generarActaPdfUseCase,
    required this.notificarYGenerarActaUseCase,
    required this.subirDocumentoComercialUseCase,
    required this.subirOrdenVentaUseCase,
    required this.subirOrdenCompraUseCase,
    required this.ticketRepository,
  }) : super(const TicketState()) { // Inicializamos con el estado base unificado
    on<ObtenerClientesEvent>(_onObtenerClientes);
    on<CrearTicketEvent>(_onCrearTicket);
    on<ActualizarEvaluacionEvent>(_onActualizarEvaluacion);
    on<NotificarYGenerarActaEvent>(_onNotificarYGenerarActa);
    on<ObtenerHistorialTicketsEvent>(_onObtenerHistorialTickets);
    on<ConfirmarRecepcionEvent>(_onConfirmarRecepcion);
    on<SubirEvidenciaEvent>(_onSubirEvidencia);
    on<SeleccionarTipoRequerimientoEvent>(_onSeleccionarTipoRequerimiento);
    on<SeleccionarLugarAtencionEvent>(_onSeleccionarLugarAtencion);
    on<ProcesarEvaluacionDocumentalEvent>(_onProcesarEvaluacionDocumental);
    on<ReversarAComercialEvent>(_onReversarAComercial);
    on<ProcesarCotizacionEvent>(_onProcesarCotizacion);
    on<AprobarProformaComercialEvent>(_onAprobarProformaComercial);
    on<CompletarFaseCostosEvent>(_onCompletarCostos);
    on<CompletarFaseComprasEvent>(_onCompletarCompras);
    on<ConsumirRepuestosBodegaEvent>(_onConsumirRepuestosBodega);
    on<CompletarProcesoTrabajoEvent>(_onCompletarProcesoTrabajo);
    on<AnularTicketEvent>(_onAnularTicket);
    on<ProcesarGestionComprasEvent>(_onProcesarGestionCompras);
    on<ProcesarBodegaEvent>(_onProcesarBodega);
    on<ProcesarEvidenciaTrabajoEvent>(_onProcesarEvidenciaTrabajo);
    on<ActualizarEstadoTicketEvent>(_onActualizarEstadoTicket);
  }

 


 Future<void> _onProcesarEvidenciaTrabajo(
  ProcesarEvidenciaTrabajoEvent event, 
  Emitter<TicketState> emit
) async {
  emit(state.copyWith(
    status: TicketStatus.loading,
    message: 'Transmitiendo evidencia multimedia (Esto puede demorar)...'
  ));

  List<String> fotosSubidas = [];
  List<String> videosSubidos = [];
  bool huboFalla = false;
  String mensajeError = '';

  // 1. SUBIDA DE FOTOS
  for (final foto in event.fotos) {
    // ⚠️ Reemplace 'subirArchivoUseCase' por el nombre de su UseCase real
    final result = await subirDocumentoEvaluacionUseCase(foto, event.ticket.id, 'evidencia_trabajo/fotos');
    result.fold(
      (failure) { huboFalla = true; mensajeError = failure.message; },
      (url) => fotosSubidas.add(url),
    );
    if (huboFalla) break;
  }

  // 2. SUBIDA DE VIDEOS (Si no fallaron las fotos)
  if (!huboFalla) {
    for (final video in event.videos) {
      final result = await subirDocumentoEvaluacionUseCase(video, event.ticket.id, 'evidencia_trabajo/videos');
      result.fold(
        (failure) { huboFalla = true; mensajeError = failure.message; },
        (url) => videosSubidos.add(url),
      );
      if (huboFalla) break;
    }
  }

  if (huboFalla) {
    emit(state.copyWith(status: TicketStatus.error, message: 'Falla de telemetría: $mensajeError'));
    return; // Aborto de emergencia
  }

  emit(state.copyWith(status: TicketStatus.loading, message: 'Consolidando base de datos...'));

  // 3. ENSAMBLAJE DE ENTIDADES Y AUDITORÍA
  final evidencia = EvidenciaTrabajoEntity(
    fotosUrls: fotosSubidas,
    videosUrls: videosSubidos,
    notasTecnicas: event.notasTecnicas,
  );

  final eventoAuditoria = EventoAuditoriaEntity(
    accion: 'EVIDENCIA DE TRABAJO REGISTRADA. EQUIPO LISTO.',
    usuarioNombre: event.nombreUsuario, 
    usuarioRol: event.rolUsuario,
    timestamp: DateTime.now(),
  );

  // 4. MUTACIÓN DEL TICKET 
  final ticketActualizado = event.ticket.copyWith(
    evidenciaTrabajo: evidencia,
    estadoActual: EstadoTicket.finalizado, // 🚀 TRASPASO AL SIGUIENTE ESTADO LOGICO
    historialEventos: [...event.ticket.historialEventos, eventoAuditoria],
  );

  // 5. PERSISTENCIA Y HOT SWAP
  final dbResult = await actualizarTicket(ticketActualizado);

  dbResult.fold(
    (failure) => emit(state.copyWith(status: TicketStatus.error, message: 'Error al actualizar Firestore')),
    (ticketGuardado) {
      final listaActualizada = state.historial.map((t) => t.id == ticketGuardado.id ? ticketGuardado : t).toList();
      emit(state.copyWith(
        status: TicketStatus.operationSuccess,
        message: 'Evidencia procesada correctamente.',
        historial: listaActualizada,
        currentTicket: ticketGuardado,
      ));
    }
  );
}
  

void _onSeleccionarTipoRequerimiento(
    SeleccionarTipoRequerimientoEvent event,
    Emitter<TicketState> emit,
  ) {
    LugarAtencion nuevoLugar = LugarAtencion.noAplica;

    // ⚙️ ENCLAVAMIENTO DE SEGURIDAD:
    // Si el operador selecciona Reparación o Garantía, forzamos el lugar a 'pendiente'
    // Esto es lo que acciona el panel dinámico para que se abra el submenú de Taller/Campo.
    if (event.tipo == TipoRequerimiento.reparacion || 
        event.tipo == TipoRequerimiento.reclamoGarantia) {
      nuevoLugar = LugarAtencion.pendiente;
    }

    // Si el operador presiona el botón "Volver" (selecciona TipoRequerimiento.ninguno),
    // el lugar vuelve automáticamente a 'noAplica' y se resetea todo.
    
    emit(state.copyWith(
      tipoSeleccionado: event.tipo,
      lugarAtencion: nuevoLugar,
    ));
  }

void _onSeleccionarLugarAtencion(
    SeleccionarLugarAtencionEvent event,
    Emitter<TicketState> emit,
  ) {
    // Este es un simple bypass. Guarda si es Taller o Campo y cierra el submenú.
    emit(state.copyWith(
      lugarAtencion: event.lugar,
    ));
  }

  
Future<void> _onReversarAComercial(
    ReversarAComercialEvent event, 
    Emitter<TicketState> emit
  ) async {
    // 1. BALIZA DE CARGA
    emit(state.copyWith(
      status: TicketStatus.loading,
      message: 'Reversando ticket a estado comercial...'
    ));

    // 2. ENSAMBLAJE DE LA AUDITORÍA (Con la observación obligatoria)
    final eventoAuditoria = EventoAuditoriaEntity(
      accion: 'SOLICITUD DE MODIFICACIÓN: ${event.observacion.toUpperCase()}',
      usuarioNombre: event.nombreUsuario, 
      usuarioRol: event.rolUsuario,
      timestamp: DateTime.now(),
    );

    // 3. MUTACIÓN DEL TICKET (El Troquelado)
    final ticketActualizado = event.ticketActual.copyWith(
      estadoActual: EstadoTicket.comercial, // 🚀 TRASPASO DE REGRESO AL ESTADO ANTERIOR
      // ⚠️ Aplicando tu estándar estructural (el evento nuevo al final de la matriz)
      historialEventos: [...event.ticketActual.historialEventos, eventoAuditoria],
    );

    // 4. PERSISTENCIA EN FIRESTORE
    final dbResult = await actualizarTicket(ticketActualizado);

    dbResult.fold(
      (failure) => emit(state.copyWith(
        status: TicketStatus.error, 
        message: 'Error al reversar el ticket: ${_mapFailureToMessage(failure)}'
      )),
      (ticketGuardado) {
        // 5. HOT SWAP: Actualizamos la memoria RAM (Lazo cerrado para el HMI)
        final listaActualizada = state.historial.map((t) => 
          t.id == ticketGuardado.id ? ticketGuardado : t
        ).toList();

        // 6. EMISIÓN DE SEÑAL DE ÉXITO
        emit(state.copyWith(
          status: TicketStatus.operationSuccess,
          message: '✅ Ticket retornado a comercial para modificación.',
          historial: listaActualizada,
          currentTicket: ticketGuardado,
        ));
      }
    );
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

Future<void> _onProcesarEvaluacionDocumental(
    ProcesarEvaluacionDocumentalEvent event, 
    Emitter<TicketState> emit
  ) async {
    emit(state.copyWith(
      status: TicketStatus.loading,
      message: 'Transmitiendo documentos técnicos a la nube...'
    ));

    String? urlExcelSubido;
    List<String> urlsPdfsSubidos = [];
    bool huboFalla = false;
    String mensajeError = '';

    // ==========================================
    // 1A. SUBIDA DEL CANAL EXCLUSIVO (PROFORMA EXCEL)
    // ==========================================
    if (event.proformaExcel != null) {
      // Opcional: Puede enviar a una subcarpeta 'evaluaciones/proformas' para más orden en Storage
      final result = await subirDocumentoEvaluacionUseCase(event.proformaExcel!, event.ticket.id, 'evaluaciones');
      
      result.fold(
        (failure) {
          huboFalla = true;
          mensajeError = _mapFailureToMessage(failure);
        },
        (url) => urlExcelSubido = url,
      );

      if (huboFalla) {
        emit(state.copyWith(status: TicketStatus.error, message: 'Falla al subir Proforma: $mensajeError'));
        return; // 🛑 Aborto de emergencia
      }
    }

    // ==========================================
    // 1B. SUBIDA DEL CANAL GENERAL (EVIDENCIA PDF)
    // ==========================================
    if (event.documentosPdf.isNotEmpty) {
      for (final file in event.documentosPdf) {
        final result = await subirDocumentoEvaluacionUseCase(file, event.ticket.id, 'evaluaciones');
        
        result.fold(
          (failure) {
            huboFalla = true;
            mensajeError = _mapFailureToMessage(failure);
          },
          (url) => urlsPdfsSubidos.add(url),
        );

        if (huboFalla) {
          emit(state.copyWith(status: TicketStatus.error, message: 'Falla al subir PDF: $mensajeError'));
          return; // 🛑 Aborto de emergencia
        }
      }
    }

    emit(state.copyWith(
      status: TicketStatus.loading,
      message: 'Ensamblando reporte y consolidando base de datos...'
    ));

    // ==========================================
    // 2. ENSAMBLAJE DE LAS NUEVAS ENTIDADES (Estructura Determinista)
    // ==========================================
    final evaluacion = EvaluacionTecnicaEntity(
      urlProformaExcel: urlExcelSubido, // Puede ser null, la entidad lo acepta
      urlsAdjuntosPdf: urlsPdfsSubidos, // Arreglo, puede estar vacío
      observacion: event.observacion,
    );

    final eventoAuditoria = EventoAuditoriaEntity(
      accion: 'EVALUACIÓN TÉCNICA Y DOCUMENTAL REGISTRADA',
      usuarioNombre: event.nombreUsuario, 
      usuarioRol: event.rolUsuario,
      timestamp: DateTime.now(),
    );

    // ==========================================
    // 3. MUTACIÓN DEL TICKET (El Troquelado)
    // ==========================================
    final ticketActualizado = event.ticket.copyWith(
      evaluacionTecnica: evaluacion,
      estadoActual: EstadoTicket.comercial, // 🚀 TRASPASO DE ESTACIÓN
      historialEventos: [...event.ticket.historialEventos, eventoAuditoria],
    );

    // ==========================================
    // 4. PERSISTENCIA EN FIRESTORE
    // ==========================================
    final dbResult = await actualizarTicket(ticketActualizado);

    dbResult.fold(
      (failure) => emit(state.copyWith(
        status: TicketStatus.error, 
        message: 'Error al guardar la evaluación: ${_mapFailureToMessage(failure)}'
      )),
      (ticketGuardado) {
        // 5. HOT SWAP: Lazo cerrado para actualizar la HMI
        final listaActualizada = state.historial.map((t) => 
          t.id == ticketGuardado.id ? ticketGuardado : t
        ).toList();

        emit(state.copyWith(
          status: TicketStatus.operationSuccess,
          message: 'Reporte técnico guardado con éxito.',
          historial: listaActualizada,
          currentTicket: ticketGuardado,
        ));
      }
    );
  }

Future<void> _onProcesarBodega(
  ProcesarBodegaEvent event, 
  Emitter<TicketState> emit
) async {
  emit(state.copyWith(
    status: TicketStatus.loading,
    message: 'Validando orden de compra y liberando equipo...'
  ));

  // ==========================================
  // 1. ENSAMBLAJE DE LA AUDITORÍA (Estándar de la Planta)
  // ==========================================
  final eventoAuditoria = EventoAuditoriaEntity(
    accion: 'ORDEN DE COMPRA VALIDADA EN BODEGA',
    usuarioNombre: event.nombreUsuario, 
    usuarioRol: event.rolUsuario,
    timestamp: DateTime.now(),
  );

  // ==========================================
  // 2. MUTACIÓN DEL TICKET (El Troquelado)
  // ==========================================
  final ticketActualizado = event.ticket.copyWith(
    estadoActual: EstadoTicket.procesoTrabajo, // 🚀 TRASPASO DE ESTACIÓN
    historialEventos: [...event.ticket.historialEventos, eventoAuditoria],
  );

  // ==========================================
  // 3. PERSISTENCIA EN FIRESTORE
  // ==========================================
  final dbResult = await actualizarTicket(ticketActualizado);

  dbResult.fold(
    (failure) => emit(state.copyWith(
      status: TicketStatus.error, 
      message: 'Error al conmutar estado en Bodega: ${_mapFailureToMessage(failure)}'
    )),
    (ticketGuardado) {
      // ==========================================
      // 4. HOT SWAP: Lazo cerrado para actualizar la HMI
      // ==========================================
      final listaActualizada = state.historial.map((t) => 
        t.id == ticketGuardado.id ? ticketGuardado : t
      ).toList();

      emit(state.copyWith(
        status: TicketStatus.operationSuccess,
        message: 'Equipo liberado para proceso de trabajo exitosamente.',
        historial: listaActualizada,
        currentTicket: ticketGuardado,
      ));
    }
  );
}

Future<void> _onProcesarGestionCompras(
    ProcesarGestionComprasEvent event, 
    Emitter<TicketState> emit
  ) async {
    emit(state.copyWith(
      status: TicketStatus.loading,
      message: 'Transmitiendo Orden de Compra a la nube...'
    ));

    String? urlOrdenSubida;
    bool huboFalla = false;
    String mensajeError = '';

    // ==========================================
    // 1. SUBIDA DEL DOCUMENTO DE COMPRA
    // ==========================================
    // ⚙️ EMPALME CORREGIDO: (XFile, ticketId)
    final result = await subirOrdenCompraUseCase(
      event.archivoOrdenCompra, 
      event.ticket.id
    );
    
    result.fold(
      (failure) {
        huboFalla = true;
        mensajeError = _mapFailureToMessage(failure);
      },
      (url) => urlOrdenSubida = url,
    );

    if (huboFalla || urlOrdenSubida == null) {
      emit(state.copyWith(status: TicketStatus.error, message: 'Falla al subir Orden de Compra: $mensajeError'));
      return; 
    }

    emit(state.copyWith(
      status: TicketStatus.loading,
      message: 'Ensamblando orden y consolidando base de datos...'
    ));

    // ==========================================
    // 2. ENSAMBLAJE DE LAS NUEVAS ENTIDADES
    // ==========================================
    final gestionCompras = GestionComprasEntity(
      urlOrdenCompra: urlOrdenSubida!, 
      observacion: event.observacion,
    );

    final eventoAuditoria = EventoAuditoriaEntity(
      accion: 'ORDEN DE COMPRA REGISTRADA',
      usuarioNombre: event.nombreUsuario, 
      usuarioRol: event.rolUsuario,
      timestamp: DateTime.now(),
    );

    // ==========================================
    // 3. MUTACIÓN DEL TICKET (El Troquelado)
    // ==========================================
    final ticketActualizado = event.ticket.copyWith(
      gestionCompras: gestionCompras,
      estadoActual: EstadoTicket.bodega, 
      isComprasCompletado: true,         
      historialEventos: [...event.ticket.historialEventos, eventoAuditoria],
    );

    // ==========================================
    // 4. PERSISTENCIA EN FIRESTORE
    // ==========================================
    final dbResult = await actualizarTicket(ticketActualizado);

    dbResult.fold(
      (failure) => emit(state.copyWith(
        status: TicketStatus.error, 
        message: 'Cortocircuito al guardar la compra: ${_mapFailureToMessage(failure)}'
      )),
      (ticketGuardado) {
        final listaActualizada = state.historial.map((t) => 
          t.id == ticketGuardado.id ? ticketGuardado : t
        ).toList();

        emit(state.copyWith(
          status: TicketStatus.operationSuccess,
          message: 'Orden de compra transferida a Bodega.',
          historial: listaActualizada,
          currentTicket: ticketGuardado,
        ));
      }
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
    final result = await obtenerTickets(event.segmento); // Pásale los parámetros de segmento si los requiere

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



Future<void> _onProcesarCotizacion(
    ProcesarCotizacionEvent event,
    Emitter<TicketState> emit,
  ) async {
    emit(state.copyWith(status: TicketStatus.loading, message: 'Procesando cotización y subiendo lotes de documentos...'));

    try {
      List<String> urlsPdf = [];
      List<String> urlsExcel = [];

      // 1. MOTORES DE SUBIDA EN PARALELO (PDFs)
      if (event.archivosPdf.isNotEmpty) {
        // Creamos un array de tareas pendientes
        final tareasPdf = event.archivosPdf.map(
          (archivo) => subirDocumentoComercialUseCase(event.ticket.id, archivo, 'proforma_pdf')
        ).toList();

        // 🚀 Ejecutamos TODAS las subidas al mismo tiempo
        final resultadosPdf = await Future.wait(tareasPdf);
        
        for (var result in resultadosPdf) {
          result.fold(
            (failure) => throw ServerException(failure.message), 
            (url) => urlsPdf.add(url),
          );
        }
      }

      // 2. MOTORES DE SUBIDA EN PARALELO (Excels)
      if (event.archivosExcel.isNotEmpty) {
        final tareasExcel = event.archivosExcel.map(
          (archivo) => subirDocumentoComercialUseCase(event.ticket.id, archivo, 'proforma_excel')
        ).toList();

        final resultadosExcel = await Future.wait(tareasExcel);
        
        for (var result in resultadosExcel) {
          result.fold(
            (failure) => throw ServerException(failure.message),
            (url) => urlsExcel.add(url),
          );
        }
      }

      // 3. ENSAMBLAJE DE LA ENTIDAD COMERCIAL MULTIPLE
      final nuevaProforma = ProformaEntity(
        pdfUrls: urlsPdf, // 📦 Inyectamos el arreglo de URLs
        excelUrls: urlsExcel, // 📦 Inyectamos el arreglo de URLs
        observacion: event.observacion,
      );

       final proformaModel = ProformaModel.fromEntity(nuevaProforma);
       
      final eventoAuditoria = EventoAuditoriaEntity(
        accion: 'COTIZACIÓN GENERADA',
        usuarioNombre: event.nombreUsuario,
        usuarioRol: event.rolUsuario,
        timestamp: DateTime.now(),
      );

      // 4. TROQUELADO Y GUARDADO
      final ticketActualizado = event.ticket.copyWith(
        proforma: proformaModel,
        estadoActual: EstadoTicket.cotizado,
        historialEventos: [...event.ticket.historialEventos, eventoAuditoria],
      );

      final result = await actualizarTicket(ticketActualizado);

      result.fold(
        (failure) => emit(state.copyWith(status: TicketStatus.error, message: failure.message)),
        (_) => emit(state.copyWith(status: TicketStatus.operationSuccess, message: 'Cotización registrada con éxito en el SCADA.')),
      );
    } on ServerException catch (e) {
      emit(state.copyWith(status: TicketStatus.error, message: e.message));
    } catch (e) {
      emit(state.copyWith(status: TicketStatus.error, message: 'Cortocircuito multihilo en celda de cotización: $e'));
    }
  }


Future<void> _onCrearTicket(CrearTicketEvent event, Emitter<TicketState> emit) async {
  // 1. BALIZA DE CARGA
  emit(state.copyWith(status: TicketStatus.loading, message: 'Asignando número de serie en servidor...'));

  final marcaDeTiempo = DateTime.now();
  
  // ⚙️ 2. ZONA DE ENSAMBLAJE BASE
  final eventoAuditoria = EventoAuditoriaEntity(
    accion: 'CREACIÓN DE REQUERIMIENTO',
    usuarioNombre: event.nombreUsuario,
    usuarioRol: event.rolUsuario,
    timestamp: marcaDeTiempo,
  );

  final ticketBase = TicketEntity(
    id: 'TEMP', // 🔌 Será reemplazado por la Transacción en Firebase
    // 🚨 Nace SIEMPRE como 'creado' para preparar el salto de estado en el backend
    estadoActual: EstadoTicket.creado, 
    sede: event.sede, 
    clienteId: event.clienteId,
    campamento: event.campamento,
    nombreContacto: event.nombreContacto,
    telefonoContacto: event.telefonoContacto,
    emailContacto: event.emailContacto,
    equipo: event.equipo,
    equipoDetalle: event.equipoDetalle,
    accesoriosRecibidos: event.accesoriosRecibidos, 
    fallaReportada: event.fallaReportada,
    marca: event.marcaEquipo?.name ?? 'NO_ESPECIFICADA',
    notasRecepcion: event.notasRecepcion,
    numeroSerie: event.numeroSerie, 
    historialEventos: [eventoAuditoria],
    esRegistroCompleto: event.esRegistroCompleto,
    tipoRequerimiento: event.tipoRequerimiento,
    lugarAtencion: event.lugarAtencion,
    fotosUrls: const [], 
    pdfActaUrl: '',
  );

  // =========================================================
  // 🚀 FASE 1: OBTENER EL ID OFICIAL CONSECUTIVO
  // =========================================================
  final dbResult = await crearTicket(ticketBase);
  
  if (dbResult.isLeft()) {
    emit(state.copyWith(
      status: TicketStatus.error, 
      message: 'Fallo al troquelar el ticket en BD: ${_mapFailureToMessage(dbResult.fold((l) => l, (r) => throw Exception()))}'
    ));
    return;
  }

  // 💎 EXTRACCIÓN DEL TICKET OFICIAL
  final ticketOficial = dbResult.fold((l) => throw Exception(), (r) => r);
  final idReal = ticketOficial.id;
  final List<String> urlsSubidas = [];

  // =========================================================
  // 📸 FASE 2: SUBIDA DE EVIDENCIAS
  // =========================================================
  if (event.evidencias.isNotEmpty) {
    emit(state.copyWith(status: TicketStatus.loading, message: 'Subiendo evidencias a carpeta $idReal...'));
    
    for (final file in event.evidencias) {
      final uploadResult = await subirEvidenciaUseCase(file, idReal); 
      
      uploadResult.fold(
        (failure) => emit(state.copyWith(status: TicketStatus.error, message: _mapFailureToMessage(failure))),
        (url) => urlsSubidas.add(url),
      );
      if (state.status == TicketStatus.error) return; // Parada de emergencia
    }
  }

  // =========================================================
  // 🔀 FASE 3: COMPUERTA LÓGICA DE DERIVACIÓN
  // =========================================================
  if (event.esRegistroCompleto) {
    emit(state.copyWith(status: TicketStatus.loading, message: 'Generando PDF para $idReal...'));

    // A. Fabricación local del PDF en RAM
    final pdfBytesResult = await generarActaPdfUseCase(
      ticket: ticketOficial,
      tipoRequerimiento: event.tipoRequerimiento.name, 
      descripcion: event.fallaReportada, 
      evidencias: event.evidencias,
    );

    Uint8List? bytesGenerados;
    pdfBytesResult.fold(
      (failure) => emit(state.copyWith(status: TicketStatus.error, message: _mapFailureToMessage(failure))),
      (bytes) => bytesGenerados = bytes,
    );
    if (state.status == TicketStatus.error) return;

    // B. Subida del Acta PDF al Storage
    emit(state.copyWith(status: TicketStatus.loading, message: 'Subiendo PDF al servidor...'));
    final pdfUploadResult = await subirActaPdfUseCase(idReal, bytesGenerados!);
    
    String urlPdfFinal = '';
    pdfUploadResult.fold(
      (failure) => emit(state.copyWith(status: TicketStatus.error, message: _mapFailureToMessage(failure))),
      (url) => urlPdfFinal = url,
    );
    if (state.status == TicketStatus.error) return;

    // 🧠 UNIDAD DE CONTROL LÓGICO: Ruteo Dinámico por Sede
    final stringSede = event.sede.name.toLowerCase();
    final EstadoTicket estadoDestino = (stringSede == 'elguabo' || stringSede == 'el_guabo')
        ? EstadoTicket.enCamino
        : EstadoTicket.recepcionFisica;

    // C. ACTUALIZACIÓN FINAL EN BASE DE DATOS (El detonador de la Cloud Function)
    final ticketFinalActualizado = ticketOficial.copyWith(
      fotosUrls: urlsSubidas,
      pdfActaUrl: urlPdfFinal,
      // 🚀 INYECCIÓN DEL SALTO DE ESTADO CALCULADO
      estadoActual: estadoDestino, 
    );

    final updateResult = await actualizarTicket(ticketFinalActualizado);
    
    updateResult.fold(
      (failure) => emit(state.copyWith(status: TicketStatus.error, message: _mapFailureToMessage(failure))),
      (ticketGuardado) {
        emit(state.copyWith(
          status: TicketStatus.operationSuccess,
          message: '✅ $idReal registrado. El servidor despachará el correo.',
          historial: [ticketGuardado, ...state.historial],
          currentTicket: ticketGuardado,
          pdfBytes: bytesGenerados, 
        ));
      },
    );

  } else {
    // ⚙️ RUTA B: INCOMPLETO
    if (urlsSubidas.isNotEmpty) {
      final ticketParcialActualizado = ticketOficial.copyWith(fotosUrls: urlsSubidas);
      await actualizarTicket(ticketParcialActualizado);
      
      emit(state.copyWith(
        status: TicketStatus.operationSuccess, 
        message: '⚠️ $idReal guardado INCOMPLETO. Pendiente taller.',
        historial: [ticketParcialActualizado, ...state.historial],
        currentTicket: ticketParcialActualizado,
      ));
    } else {
       emit(state.copyWith(
        status: TicketStatus.operationSuccess, 
        message: '⚠️ $idReal guardado INCOMPLETO. Pendiente taller.',
        historial: [ticketOficial, ...state.historial],
        currentTicket: ticketOficial,
      ));
    }
  }
}

Future<void> _onActualizarEstadoTicket(ActualizarEstadoTicketEvent event, Emitter<TicketState> emit) async {
  emit(state.copyWith(status: TicketStatus.loading, message: 'Actualizando estado a ${event.nuevoEstado.name}...'));

  // ⚙️ 1. Ensamblaje de Auditoría (El mismo troquel que usa para anular y crear)
  final eventoAuditoria = EventoAuditoriaEntity(
    accion: event.accionAuditoria,
    usuarioNombre: event.nombreUsuario,
    usuarioRol: event.rolUsuario,
    timestamp: DateTime.now(),
  );

  // ⚙️ 2. Clonación Inmutable del Payload (Uso directo de su copyWith)
  final ticketActualizado = event.ticket.copyWith(
    estadoActual: event.nuevoEstado,
    historialEventos: [...event.ticket.historialEventos, eventoAuditoria],
  );

  // 📡 3. Transmisión Directa a BD (Sin capas de traducción inútiles)
  final updateResult = await actualizarTicket(ticketActualizado); 

  // 🔀 4. Evaluación de la respuesta
  updateResult.fold(
    (failure) => emit(state.copyWith(
      status: TicketStatus.error, 
      message: 'Fallo al actualizar: ${_mapFailureToMessage(failure)}'
    )),
    (ticketGuardado) {
      // 🔄 5. Refresco del búfer de memoria local
      final listaActualizada = state.historial.map((t) => 
        t.id == ticketGuardado.id ? ticketGuardado : t
      ).toList();

      emit(state.copyWith(
        status: TicketStatus.operationSuccess,
        message: '✅ Estado del ticket actualizado a ${event.nuevoEstado.name}.',
        historial: listaActualizada,
        currentTicket: ticketGuardado,
      ));
    }
  );
}

Future<void> _onAnularTicket(AnularTicketEvent event, Emitter<TicketState> emit) async {
  emit(state.copyWith(status: TicketStatus.loading, message: 'Anulando ticket...'));

  // ⚙️ Auditoría automática (Sin motivos, solo registro de acción)
  final eventoAuditoria = EventoAuditoriaEntity(
    accion: 'ANULACIÓN DE TICKET',
    usuarioNombre: event.nombreUsuario,
    usuarioRol: event.rolUsuario,
    timestamp: DateTime.now(),
  );

  // ⚙️ Preparación del payload (Estado nuevo + Historial actualizado)
  final ticketActualizado = event.ticket.copyWith(
    estadoActual: EstadoTicket.anulado,
    historialEventos: [...event.ticket.historialEventos, eventoAuditoria],
  );

  // ⚙️ Convertimos a Modelo para enviar al DataSource
  final model = TicketModel.fromEntity(ticketActualizado);

  final result = await actualizarTicket(model); 

  result.fold(
    (failure) => emit(state.copyWith(
      status: TicketStatus.error, 
      message: 'Fallo al anular: ${_mapFailureToMessage(failure)}'
    )),
    (ticketGuardado) {
      // ⚙️ Actualizamos la lista local
      final listaActualizada = state.historial.map((t) => 
        t.id == ticketGuardado.id ? ticketGuardado : t
      ).toList();

      emit(state.copyWith(
        status: TicketStatus.operationSuccess,
        message: 'Ticket anulado correctamente.',
        historial: listaActualizada,
        currentTicket: ticketGuardado,
      ));
    }
  );
}




Future<void> _onAprobarProformaComercial(AprobarProformaComercialEvent event, Emitter<TicketState> emit) async {
  List<String> urlsOrdenVenta = [];
  List<String> urlsOrdenCompra = [];

  emit(state.copyWith(
    status: TicketStatus.loading, 
    message: 'Procesando documentos comerciales e iniciando transición...'
  ));

  // =========================================================
  // 🚀 FASE 1: TELEMETRÍA DE ARCHIVOS (Subida a Storage)
  // =========================================================
  
 if (event.ordenesVentaArchivos.isNotEmpty) {
  for (final platformFile in event.ordenesVentaArchivos) {
    final xFile = platformFile.path != null
        ? XFile(platformFile.path!)
        : XFile.fromData(platformFile.bytes!, name: platformFile.name);

    // ✅ Llamada a la tubería de Venta
    final result = await subirOrdenVentaUseCase(xFile, event.ticket.id);

    result.fold(
      (f) => emit(state.copyWith(status: TicketStatus.error, message: _mapFailureToMessage(f))),
      (url) => urlsOrdenVenta.add(url),
    );
    
    // Si la carga falla, cortamos la ejecución antes de persistir
    if (state.status == TicketStatus.error) return;
  }

  // 🚀 Consolidación: Inyectamos el metadato y persistimos
  if (urlsOrdenVenta.isNotEmpty) {
    final ticketActualizado = event.ticket.copyWith(
      numeroOrdenVenta: event.ordenesVentaArchivos.first.name,
    );

    // Persistimos en la base de datos
    final resultActualizacion = await actualizarTicket(ticketActualizado);

    resultActualizacion.fold(
      (f) => emit(state.copyWith(
          status: TicketStatus.error,
          message: 'Error al vincular Orden de Venta: ${_mapFailureToMessage(f)}')),
      (_) => emit(state.copyWith(
        status: TicketStatus.operationSuccess,
        message: 'Orden de Venta procesada y vinculada exitosamente.',
        currentTicket: ticketActualizado,
      )),
    );
  }
}

  // --- 2. Subida de Órdenes de Compra ---
  if (event.ordenesCompraArchivos.isNotEmpty) {
    for (final platformFile in event.ordenesCompraArchivos) {
      final xFile = platformFile.path != null 
          ? XFile(platformFile.path!) 
          : XFile.fromData(platformFile.bytes!, name: platformFile.name);
      
      // ✅ Llamada a la tubería de Compra
      final result = await subirOrdenCompraUseCase(xFile, event.ticket.id);
      
      result.fold(
        (f) => emit(state.copyWith(status: TicketStatus.error, message: _mapFailureToMessage(f))),
        (url) => urlsOrdenCompra.add(url),
      );
      if (state.status == TicketStatus.error) return;
    }
  }

  // =========================================================
  // ⚙️ FASE 2: ENSAMBLAJE DEL NUEVO ESTADO DEL TICKET
  // =========================================================

  final eventoAuditoria = EventoAuditoriaEntity(
    accion: 'APROBACIÓN COMERCIAL - Órdenes anexadas',
    usuarioNombre: event.nombreUsuario,
    usuarioRol: event.rolUsuario,
    timestamp: DateTime.now(),
  );

  final ticketActualizado = event.ticket.copyWith(
    estadoActual: EstadoTicket.costos, 
    numeroOrdenVenta: event.numeroOrdenVenta,
    codigoOrdenVenta: urlsOrdenVenta,
    codigoOrdenCompra: urlsOrdenCompra,
    historialEventos: [...event.ticket.historialEventos, eventoAuditoria],
    isCostosCompletado: false, 
    isComprasCompletado: false,
  );



  emit(state.copyWith(status: TicketStatus.loading, message: 'Registrando mutación en base de datos...'));

  // =========================================================
  // 💾 FASE 3: ESCRITURA EN LA BASE DE DATOS
  // =========================================================
  final updateResult = await actualizarTicket(ticketActualizado); 
  
  updateResult.fold(
    (failure) {
      print("🚨 ERROR DE ESCRITURA DB: ${_mapFailureToMessage(failure)}");
      emit(state.copyWith(
        status: TicketStatus.error, 
        message: 'Fallo al escribir en la base de datos: ${_mapFailureToMessage(failure)}'
      ));
    },
    (ticketGuardado) {


      final listaActualizada = state.historial.map((t) => 
        t.id == ticketGuardado.id ? ticketGuardado : t
      ).toList();

      emit(state.copyWith(
        status: TicketStatus.operationSuccess, 
        message: 'Trámite comercial completado. Ticket derivado a Costos y Compras.',
        historial: listaActualizada,
        currentTicket: ticketGuardado,
      ));
    }
  );
}

// =========================================================================
// 🏭 RUTINA A: DEPARTAMENTO DE COSTOS
// =========================================================================
Future<void> _onCompletarCostos(CompletarFaseCostosEvent event, Emitter<TicketState> emit) async {
  emit(state.copyWith(status: TicketStatus.loading, message: 'Inyectando Código de Proyecto...'));

  // 1. EVALUACIÓN DE LA COMPUERTA LÓGICA (AND GATE)
  // Si Compras ya terminó antes que Costos, entonces este es el paso final.
  final bool comprasYaTermino = event.ticket.isComprasCompletado;

  // 2. ENSAMBLAJE
  final eventoAuditoria = EventoAuditoriaEntity(
    accion: 'FASE COSTOS - Código Proyecto Asignado: ${event.codigoProyecto}',
    usuarioNombre: event.nombreUsuario,
    usuarioRol: event.rolUsuario,
    timestamp: DateTime.now(),
  );

  final ticketActualizado = event.ticket.copyWith(
    codigoProyecto: event.codigoProyecto,
    isCostosCompletado: true, // 🔒 Cerramos la válvula de Costos
    estadoActual: EstadoTicket.compras,
    historialEventos: [...event.ticket.historialEventos, eventoAuditoria],
  );

  // 3. PERSISTENCIA
  final dbResult = await actualizarTicket(ticketActualizado);
  
  dbResult.fold(
    (failure) => emit(state.copyWith(status: TicketStatus.error, message: _mapFailureToMessage(failure))),
    (ticketGuardado) => emit(state.copyWith(
      status: TicketStatus.operationSuccess, 
      message: comprasYaTermino ? 'Costos finalizado. Ticket transferido a Bodega.' : 'Costos finalizado. Esperando a Compras.',
      historial: state.historial.map((t) => t.id == ticketGuardado.id ? ticketGuardado : t).toList(),
    ))
  );

  

}

// =========================================================================
// 🏭 RUTINA B: DEPARTAMENTO DE COMPRAS
// =========================================================================
Future<void> _onCompletarCompras(CompletarFaseComprasEvent event, Emitter<TicketState> emit) async {
  emit(state.copyWith(status: TicketStatus.loading, message: 'Procesando documentos de Compras...'));

  List<String> urlsNuevas = [];

  // 1. SUBIDA DE ARCHIVOS
  if (event.ordenesCompraInternaArchivos.isNotEmpty) {
    for (final file in event.ordenesCompraInternaArchivos) {
      final uploadResult = await subirEvidenciaUseCase(file, event.ticket.id);
      uploadResult.fold(
        (failure) => emit(state.copyWith(status: TicketStatus.error, message: _mapFailureToMessage(failure))),
        (url) => urlsNuevas.add(url),
      );
      if (state.status == TicketStatus.error) return; // Parada por error
    }
  }

  // 2. EVALUACIÓN DE LA COMPUERTA LÓGICA (AND GATE)
  // Si Costos ya terminó antes que Compras, entonces este es el paso final.
  final bool costosYaTermino = event.ticket.isCostosCompletado;
  final EstadoTicket nuevoEstado = costosYaTermino ? EstadoTicket.bodega : event.ticket.estadoActual;

  // 3. ENSAMBLAJE
  final eventoAuditoria = EventoAuditoriaEntity(
    accion: 'FASE COMPRAS - Órdenes Internas Anexadas',
    usuarioNombre: event.nombreUsuario,
    usuarioRol: event.rolUsuario,
    timestamp: DateTime.now(),
  );

  // Ojo aquí: sumamos las URLs nuevas a las que ya pudieran existir
  final ticketActualizado = event.ticket.copyWith(
    codigoOrdenCompra: [...event.ticket.codigoOrdenCompra, ...urlsNuevas],
    isComprasCompletado: true, // 🔒 Cerramos la válvula de Compras
    estadoActual: nuevoEstado, // 🔀 Solo salta a bodega si Costos ya había acabado
    historialEventos: [...event.ticket.historialEventos, eventoAuditoria],
  );

  // 4. PERSISTENCIA
  final dbResult = await actualizarTicket(ticketActualizado);
  
  dbResult.fold(
    (failure) => emit(state.copyWith(status: TicketStatus.error, message: _mapFailureToMessage(failure))),
    (ticketGuardado) => emit(state.copyWith(
      status: TicketStatus.operationSuccess, 
      message: costosYaTermino ? 'Compras finalizado. Ticket transferido a Bodega.' : 'Compras finalizado. Esperando a Costos.',
      historial: state.historial.map((t) => t.id == ticketGuardado.id ? ticketGuardado : t).toList(),
    ))
  );
}



// =========================================================================
// 🏭 RUTINA FINAL: TALLER (Proceso de Trabajo y Cierre)
// =========================================================================
Future<void> _onCompletarProcesoTrabajo(CompletarProcesoTrabajoEvent event, Emitter<TicketState> emit) async {
  // 1. ENCENDIDO DE BALIZA LUMINOSA
  emit(state.copyWith(status: TicketStatus.loading, message: 'Subiendo telemetría final del equipo...'));

  List<String> urlsSubidas = [];

  // 2. TRANSMISIÓN DE EVIDENCIAS (Subida al Storage)
  if (event.evidenciasFinales.isNotEmpty) {
    for (final file in event.evidenciasFinales) {
      final uploadResult = await subirEvidenciaUseCase(file, event.ticket.id); 
      
      uploadResult.fold(
        (failure) => emit(state.copyWith(status: TicketStatus.error, message: _mapFailureToMessage(failure))),
        (url) => urlsSubidas.add(url),
      );
      if (state.status == TicketStatus.error) return; // Parada de emergencia de la línea
    }
  }

  // 3. AUDITORÍA Y REGISTRO
  final eventoAuditoria = EventoAuditoriaEntity(
    accion: 'CIERRE DE TRABAJO - Reparación finalizada. Notas: ${event.notasFinales}',
    usuarioNombre: event.nombreUsuario,
    usuarioRol: event.rolUsuario,
    timestamp: DateTime.now(),
  );

  emit(state.copyWith(status: TicketStatus.loading, message: 'Registrando cierre definitivo en el servidor...'));

  // 4. ENSAMBLAJE FINAL DEL TICKET
  final ticketActualizado = event.ticket.copyWith(
    procesoTrabajoUrls: [...event.ticket.procesoTrabajoUrls, ...urlsSubidas],
    estadoActual: EstadoTicket.finalizado, // 🚀 DETONADOR DEL CORREO FINAL EN EL BACKEND
    historialEventos: [...event.ticket.historialEventos, eventoAuditoria],
  );

  // 5. ESCRITURA EN BASE DE DATOS (Actuador Maestro)
  final dbResult = await actualizarTicket(ticketActualizado);
  
  dbResult.fold(
    (failure) => emit(state.copyWith(
      status: TicketStatus.error, 
      message: 'Fallo al sellar el ticket en la base de datos: ${_mapFailureToMessage(failure)}'
    )),
    (ticketGuardado) {
      final listaActualizada = state.historial.map((t) => 
        t.id == ticketGuardado.id ? ticketGuardado : t
      ).toList();

      emit(state.copyWith(
        status: TicketStatus.operationSuccess, 
        message: '✅ Trabajo finalizado exitosamente. El servidor despachará el correo de cierre al cliente.',
        historial: listaActualizada,
        currentTicket: ticketGuardado,
      ));
    }
  );
}


// =========================================================================
// 🏭 RUTINA C: ESTACIÓN DE BODEGA (Consumo de Inventario)
// =========================================================================
Future<void> _onConsumirRepuestosBodega(ConsumirRepuestosBodegaEvent event, Emitter<TicketState> emit) async {
  emit(state.copyWith(status: TicketStatus.loading, message: 'Registrando consumo de inventario...'));

  // 1. SENSOR DE BARRIDO LÓGICO (Verifica si falta algún repuesto por entregar)
  // .every() retorna true solo si TODOS los elementos cumplen la condición.
  // Si la lista está vacía (no se compró nada), retorna true automáticamente.
  final bool inventarioCompletado = event.itemsActualizados.every((item) => item.consumidoPorBodega == true);
  
  // 🔀 Compuerta de salto de estado
  final EstadoTicket nuevoEstado = inventarioCompletado ? EstadoTicket.procesoTrabajo : event.ticket.estadoActual;

  // 2. AUDITORÍA DINÁMICA
  final eventoAuditoria = EventoAuditoriaEntity(
    accion: inventarioCompletado 
        ? 'BODEGA FINALIZADA - Todos los ítems despachados a Taller.' 
        : 'BODEGA PARCIAL - Actualización de entrega de repuestos.',
    usuarioNombre: event.nombreUsuario,
    usuarioRol: event.rolUsuario,
    timestamp: DateTime.now(),
  );

  // 3. ENSAMBLAJE DEL TICKET
  final ticketActualizado = event.ticket.copyWith(
    itemsCompra: event.itemsActualizados, // Inyectamos la matriz con los checkboxes actualizados
    estadoActual: nuevoEstado,
    historialEventos: [...event.ticket.historialEventos, eventoAuditoria],
  );

  // 4. ESCRITURA EN BASE DE DATOS
  final dbResult = await actualizarTicket(ticketActualizado);
  
  dbResult.fold(
    (failure) => emit(state.copyWith(status: TicketStatus.error, message: _mapFailureToMessage(failure))),
    (ticketGuardado) => emit(state.copyWith(
      status: TicketStatus.operationSuccess, 
      message: inventarioCompletado 
          ? 'Despacho completo. Ticket transferido a Taller (Proceso de Trabajo).' 
          : 'Inventario actualizado. Faltan repuestos por despachar.',
      historial: state.historial.map((t) => t.id == ticketGuardado.id ? ticketGuardado : t).toList(),
      currentTicket: ticketGuardado,
    ))
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

    // 🧠 UNIDAD DE CONTROL LÓGICO: Ruteo Dinámico por Sede
    // Evaluamos el sensor de ubicación para desviar el flujo
    final stringSede = event.ticket.sede.name.toLowerCase();
    final EstadoTicket estadoDestino = (stringSede == 'elguabo' || stringSede == 'el_guabo')
        ? EstadoTicket.enCamino
        : EstadoTicket.recepcionFisica;

    // ⚙️ AQUÍ SE HACE LA INGENIERÍA: Ensamblamos TODAS las piezas nuevas en la entidad
    final ticketActualizado = event.ticket.copyWith(
      estadoActual: estadoDestino, // 🔀 TRASPASO DE ESTADO DINÁMICO
      numeroSerie: event.numeroSerie,        
      fallaReportada: event.fallaReportada, 
      accesoriosRecibidos: event.accesoriosRecibidos, 
      
      // 🚨 LOS DOS CABLES QUE DEJASTE DESCONECTADOS:
      notasRecepcion: event.notasRecepcion, 
      esRegistroCompleto: event.esRegistroCompleto, // O ponle true directamente si siempre aplica
      
      fotosUrls: urlsTotales,                     
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