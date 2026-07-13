// lib/features/tickets/presentation/bloc/ticket_bloc.dart

import 'dart:typed_data';
import 'package:aquaspot_postventa/core/errors/exceptions.dart';
import 'package:aquaspot_postventa/features/tickets/domain/entities/evaluacion_tecnica_entity.dart';
import 'package:aquaspot_postventa/features/tickets/domain/entities/proforma_entity.dart';
import 'package:aquaspot_postventa/features/tickets/domain/usecases/subir_documento_comercial_usecase.dart';
import 'package:aquaspot_postventa/features/tickets/domain/usecases/subir_documento_evaluacion_usecase.dart';
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
import '../../domain/usecases/notificar_y_generar_acta_usecase.dart';
import '../../domain/entities/ticket_entity.dart';
import '../../../../core/enum/ticket_enums.dart';
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
  final NotificarYGenerarActaUseCase notificarYGenerarActaUseCase;
  final SubirDocumentoEvaluacionUseCase subirDocumentoEvaluacionUseCase;
  final SubirDocumentoComercialUseCase subirDocumentoComercialUseCase;

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
    required this.subirDocumentoComercialUseCase
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
    on<ProcesarCotizacionEvent>(_onProcesarCotizacion);
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

    List<String> urlsSubidas = [];
    bool huboFalla = false;
    String mensajeError = '';

    // 1. SUBIDA DE ARCHIVOS BINARIOS A STORAGE
    if (event.documentos.isNotEmpty) {
      for (final file in event.documentos) {
        // ⚠️ ATENCIÓN: Aquí usas tu método real del repositorio/usecase para subir a Storage.
        // Ejemplo: final result = await subirDocumentoUseCase(file, event.ticket.id);
       final result = await subirDocumentoEvaluacionUseCase(file, event.ticket.id, 'evaluaciones');
        result.fold(
          (failure) {
            huboFalla = true;
            mensajeError = _mapFailureToMessage(failure);
          },
          (url) => urlsSubidas.add(url),
        );

        if (huboFalla) {
          emit(state.copyWith(status: TicketStatus.error, message: 'Falla al subir archivo: $mensajeError'));
          return; // Abortar secuencia
        }
      }
    }

    emit(state.copyWith(
      status: TicketStatus.loading,
      message: 'Ensamblando reporte y consolidando base de datos...'
    ));

    // 2. ENSAMBLAJE DE LAS NUEVAS ENTIDADES
    final evaluacion = EvaluacionTecnicaEntity(
      documentosUrls: urlsSubidas,
      observacion: event.observacion,
    );

    // TODO: Extraer usuario real si tienes AuthBloc inyectado en este BLoC. 
    // Si no, pon valores por defecto temporales o inyecta el nombre en el evento.
    final eventoAuditoria = EventoAuditoriaEntity(
      accion: 'EVALUACIÓN TÉCNICA Y DOCUMENTAL REGISTRADA',
      usuarioNombre: event.nombreUsuario, // Cambiar por usuario real
      usuarioRol: event.rolUsuario,
      timestamp: DateTime.now(),
    );

    // 3. MUTACIÓN DEL TICKET (El Troquelado)
    final ticketActualizado = event.ticket.copyWith(
      evaluacionTecnica: evaluacion,
      estadoActual: EstadoTicket.comercial, // 🚀 TRASPASO AL NUEVO ESTADO
      historialEventos: [...event.ticket.historialEventos, eventoAuditoria],
    );

    // 4. PERSISTENCIA EN FIRESTORE
    final dbResult = await actualizarTicket(ticketActualizado);

    dbResult.fold(
      (failure) => emit(state.copyWith(
        status: TicketStatus.error, 
        message: 'Error al guardar la evaluación: ${_mapFailureToMessage(failure)}'
      )),
      (ticketGuardado) {
        // 5. HOT SWAP: Actualizamos la memoria RAM (Lazo cerrado para el HMI)
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

      final eventoAuditoria = EventoAuditoriaEntity(
        accion: 'COTIZACIÓN MÚLTIPLE GENERADA',
        usuarioNombre: event.nombreUsuario,
        usuarioRol: event.rolUsuario,
        timestamp: DateTime.now(),
      );

      // 4. TROQUELADO Y GUARDADO
      final ticketActualizado = event.ticket.copyWith(
        proforma: nuevaProforma,
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
  // 1. Activamos la baliza de carga mutando el estado actual
  emit(state.copyWith(
    status: TicketStatus.loading, 
    message: 'Transmitiendo datos...'
  ));

  // 2. Generación de telemetría interna (Tu lógica inmutable de ID)
  final marcaDeTiempo = DateTime.now();
  final idGenerado = 'REQ-${marcaDeTiempo.millisecondsSinceEpoch}';

  final eventoAuditoria = EventoAuditoriaEntity(
    accion: 'CREACIÓN DE REQUERIMIENTO',
    usuarioNombre: event.nombreUsuario,
    usuarioRol: event.rolUsuario,
    timestamp: marcaDeTiempo,
  );

  final List<String> urlsSubidas = [];

  // 3. Lazo de transmisión de imágenes
  if (event.evidencias.isNotEmpty) {
    for (final file in event.evidencias) {
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

      // 🛑 PARADA DE EMERGENCIA: Emitimos el error usando copyWith
      if (tieneFalla) {
        emit(state.copyWith(
          status: TicketStatus.error, 
          message: mensajeFalla
        ));
        return; 
      }
    }
  }

  // ⚙️ 4. ZONA DE ENSAMBLAJE BASE
  final ticketBase = TicketEntity(
    id: idGenerado,
    // Ajuste de Arquitecto: Si nace completo pasa directo a 'recepcionFisica'
    estadoActual: event.esRegistroCompleto ? EstadoTicket.recepcionFisica : EstadoTicket.creado,
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
    notasRecepcion: event.notasRecepcion,
    numeroSerie: event.numeroSerie, 
    historialEventos: [eventoAuditoria],
    esRegistroCompleto: event.esRegistroCompleto,
    tipoRequerimiento: event.tipoRequerimiento,
    lugarAtencion: event.lugarAtencion,
    fotosUrls: urlsSubidas,
  );

  // =========================================================
  // 🔀 5. COMPUERTA LÓGICA DE DERIVACIÓN (LOGICA MAESTRA)
  // =========================================================
  print("🛠️ ENTIDAD ARMADA CON: ${ticketBase.esRegistroCompleto}");

  if (event.esRegistroCompleto) {
    // 🚀 RUTA A: REGISTRO COMPLETO -> GENERAR LOCALMENTE, SUBIR PDF Y NOTIFICAR VIA WEBHOOK
    emit(state.copyWith(
      status: TicketStatus.loading, 
      message: 'Consolidando parámetros y fabricando documento PDF...'
    ));

    // A. Fabricación local del PDF (Utilizamos la falla como descripción base)
    final pdfBytesResult = await generarActaPdfUseCase(
      ticket: ticketBase,
      tipoRequerimiento: event.tipoRequerimiento.name, 
      descripcion: event.fallaReportada, 
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

    // B. Subida del Acta PDF a Firebase Storage
    final pdfUploadResult = await subirActaPdfUseCase(ticketBase.id, bytesGenerados!);
    
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

    // C. Ensamblaje final con la URL del PDF y guardado en base de datos
    final ticketFinal = ticketBase.copyWith(
      pdfActaUrl: urlPdfFinal,
    );

    final dbResult = await crearTicket(ticketFinal);
    
    // Usamos await porque dentro llamaremos a la API asíncrona de notificación
    await dbResult.fold(
      (failure) async => emit(state.copyWith(
        status: TicketStatus.error, 
        message: _mapFailureToMessage(failure)
      )),
      (ticketGuardado) async {
        emit(state.copyWith(
          status: TicketStatus.loading, 
          message: 'Ticket registrado. Disparando notificación de correo...'
        ));

        // D. Disparo del Webhook hacia Python para enviar por correo el acta
        final actaResult = await notificarYGenerarActaUseCase(ticketGuardado);
        
        actaResult.fold(
          (actaFailure) => emit(state.copyWith(
            status: TicketStatus.error, 
            message: 'Ticket creado, pero falló el envío del correo: ${_mapFailureToMessage(actaFailure)}'
          )),
          (ticketProcesado) {
            // ⚙️ HOT SWAP RAM: Introducir el nuevo elemento al inicio de la matriz
            final listaActualizada = [ticketProcesado, ...state.historial];
            
            emit(state.copyWith(
              status: TicketStatus.operationSuccess,
              message: '✅ Requerimiento Completo: Ticket registrado, acta enviada al correo y lista en pantalla.',
              historial: listaActualizada,
              currentTicket: ticketProcesado,
              pdfBytes: bytesGenerados, // ⚡ PIN ENERGIZADO: Ahora la UI sí abrirá la pantalla de impresión
            ));
          },
        );
      },
    );

  } else {
    // ⚙️ RUTA B: INCOMPLETO -> SOLO GUARDAR EN BASE DE DATOS (Tu lógica base original)
    emit(state.copyWith(
      status: TicketStatus.loading, 
      message: 'Guardando registro parcial en el sistema...'
    ));

    final dbResult = await crearTicket(ticketBase);

    dbResult.fold(
      (failure) => emit(state.copyWith(
        status: TicketStatus.error, 
        message: _mapFailureToMessage(failure)
      )),
      (ticketGuardado) {
        final listaActualizada = [ticketGuardado, ...state.historial];

        emit(state.copyWith(
          status: TicketStatus.operationSuccess, 
          message: '⚠️ Requerimiento guardado como INCOMPLETO. Pendiente revisión en taller.',
          historial: listaActualizada,
          currentTicket: ticketGuardado,
          pdfBytes: null, // Válvula cerrada, cero bytes pasados al HMI
        ));
      },
    );
  }
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

    // ⚙️ AQUÍ SE HACE LA INGENIERÍA: Ensamblamos TODAS las piezas nuevas en la entidad
    final ticketActualizado = event.ticket.copyWith(
      estadoActual: EstadoTicket.recepcionFisica, // 🚀 TRASPASO DE ESTADO
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