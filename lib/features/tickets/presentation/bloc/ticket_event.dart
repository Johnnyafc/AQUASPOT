import 'dart:io';

import 'package:aquaspot_postventa/core/enum/marca_equipo.dart';
import 'package:aquaspot_postventa/features/tickets/domain/entities/item_compra_entity.dart';
import 'package:equatable/equatable.dart';
import 'package:image_picker/image_picker.dart';
import '../../domain/entities/ticket_entity.dart';
import '../../../../core/enum/ticket_enums.dart'; 
import '../../../../core/enum/segmento_operativo.dart';
import 'package:file_picker/file_picker.dart';

abstract class TicketEvent extends Equatable {
  const TicketEvent();

  @override
  List<Object?> get props => [];
}

// ==========================================
// MÓDULO DE RECEPCIÓN Y EVIDENCIAS
// ==========================================
class SubirEvidenciaEvent extends TicketEvent {
  final XFile file;
  final String ticketId;

  const SubirEvidenciaEvent({required this.file, required this.ticketId});

  @override
  List<Object> get props => [file, ticketId];
}

// ⚙️ SEÑALES CRUDAS AISLADAS: La UI envía los datos sin procesar, el BLoC los ensambla.
class ConfirmarRecepcionEvent extends TicketEvent {
  final TicketEntity ticket; // 🚀 El estado previo del equipo
  final String numeroSerie;     // 🚀 La lectura del escáner en taller
  final String fallaReportada;
  final Map<String, bool> accesoriosRecibidos;
  final String nombreUsuario;
  final String rolUsuario;
  final String tipoRequerimiento; 
  final Prioridad prioridad;      
  final String notasRecepcion;
  final List<XFile> evidencias; 
  final bool esRegistroCompleto;

  const ConfirmarRecepcionEvent({
    required this.ticket,
    required this.numeroSerie,
    required this.fallaReportada,
    required this.accesoriosRecibidos,
    required this.nombreUsuario,
    required this.rolUsuario,
    required this.tipoRequerimiento,
    required this.prioridad,
    this.notasRecepcion = '',
    this.evidencias = const [],
    this.esRegistroCompleto = true,
    
  });

  @override
  // 🛑 IMPORTANTE: Equatable necesita todas las variables de instancia aquí para el comparador de memoria.
  List<Object> get props => [
    ticket, 
    numeroSerie,
    fallaReportada,
    accesoriosRecibidos,
    nombreUsuario, 
    rolUsuario, 
    tipoRequerimiento, 
    prioridad, 
    notasRecepcion, 
    evidencias,
  ]; 
}

// ==========================================
// MÓDULO ERP Y CONTROL DE FLUJO
// ==========================================

// 1. Pulsador de Arranque: Carga inicial de datos del ERP
class ObtenerClientesEvent extends TicketEvent {}

// 2. Etapa 1: Comercial ingresa un equipo nuevo
class CrearTicketEvent extends TicketEvent {
  final Sede sede;
  final String clienteId;
  final String campamento;
  final String nombreContacto;
  final String telefonoContacto;
  final String emailContacto;
  final TipoEquipo equipo;
  final String? equipoDetalle;
  final String fallaReportada;
  final String nombreUsuario;
  final String rolUsuario;
  final List<XFile> evidencias;
  
  // 🚀 LOS DOS NUEVOS SENSORES
  final TipoRequerimiento tipoRequerimiento;
  final LugarAtencion lugarAtencion;
  final String? numeroSerie;
  final Map<String, bool>? accesoriosRecibidos;
  final bool esRegistroCompleto;
   final String? notasRecepcion;
   final MarcaEquipo? marcaEquipo;

  const CrearTicketEvent({
    required this.sede,
    required this.clienteId,
    required this.campamento,
    required this.nombreContacto,
    required this.telefonoContacto,
    required this.emailContacto,
    required this.equipo,
    this.equipoDetalle,
    required this.fallaReportada,
    required this.nombreUsuario,
    required this.rolUsuario,
    this.evidencias = const [],
    // 🚀 OBLIGATORIOS EN LA TRANSMISIÓN
    required this.tipoRequerimiento,
    required this.lugarAtencion,
    this.numeroSerie,
    this.accesoriosRecibidos,
    required this.esRegistroCompleto,
    this.marcaEquipo,
    this.notasRecepcion
  });

  @override
  List<Object?> get props => [
        sede, clienteId, campamento, nombreContacto, telefonoContacto, 
        emailContacto, equipo, equipoDetalle, fallaReportada, 
        nombreUsuario, rolUsuario, evidencias,
        tipoRequerimiento, lugarAtencion,numeroSerie,accesoriosRecibidos,esRegistroCompleto,marcaEquipo,notasRecepcion // 🚀 Añadidos a las props
      ];
}

// 3. Etapa 2: Técnico en el taller emite su diagnóstico
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

class ObtenerHistorialTicketsEvent extends TicketEvent {
  final SegmentoOperativo segmento;

  const ObtenerHistorialTicketsEvent({required this.segmento});

  @override
  List<Object> get props => [segmento];
}

class SeleccionarTipoRequerimientoEvent extends TicketEvent {
  final TipoRequerimiento tipo;

  const SeleccionarTipoRequerimientoEvent(this.tipo);

  @override
  List<Object> get props => [tipo];
}

// ⚙️ COMANDO 2: Selección de submenú (Taller/Campo)
class SeleccionarLugarAtencionEvent extends TicketEvent {
  final LugarAtencion lugar;

  const SeleccionarLugarAtencionEvent(this.lugar);

  @override
  List<Object> get props => [lugar];
}
// 🚀 EVENTO: Procesar la evaluación técnica y subir documentos
class ProcesarEvaluacionDocumentalEvent extends TicketEvent {
  final TicketEntity ticket;
  final List<PlatformFile> documentos;
  final String observacion;
  final String nombreUsuario; 
  final String rolUsuario;

  const ProcesarEvaluacionDocumentalEvent({
    required this.ticket,
    required this.documentos,
    required this.observacion,
    required this.nombreUsuario,
    required this.rolUsuario,
  });

  @override
List<Object?> get props => [ticket, documentos, observacion, nombreUsuario, rolUsuario];
}

class ProcesarCotizacionEvent extends TicketEvent {
  final TicketEntity ticket;
  final List<PlatformFile> archivosPdf; // 📦 Actualizado a Lista
  final List<PlatformFile> archivosExcel; // 📦 Actualizado a Lista
  final String observacion;
  final String nombreUsuario;
  final String rolUsuario;

  const ProcesarCotizacionEvent({
    required this.ticket,
    required this.archivosPdf,
    required this.archivosExcel,
    required this.observacion,
    required this.nombreUsuario,
    required this.rolUsuario,
  });

  @override
  List<Object?> get props => [
    ticket, archivosPdf, archivosExcel, observacion, nombreUsuario, rolUsuario
  ];
}
class ObtenerTicketsEvent extends TicketEvent {
  final EstadoTicket? estadoFiltro; // ⚙️ Válvula reguladora opcional

  const ObtenerTicketsEvent({this.estadoFiltro});

  @override
  List<Object?> get props => [estadoFiltro];
}
class ReversarAComercialEvent extends TicketEvent {
  final TicketEntity ticketActual;
  final String nombreUsuario;
  final String rolUsuario;
  final String observacion;

  const ReversarAComercialEvent({
    required this.ticketActual,
    required this.nombreUsuario,
    required this.rolUsuario,
    required this.observacion,
  });

  @override
  List<Object?> get props => [ticketActual, nombreUsuario, rolUsuario, observacion];
}
class AprobarProformaComercialEvent extends TicketEvent {
  final TicketEntity ticket;
  final List<dynamic> ordenesVentaArchivos; // Archivos físicos (File o XFile)
  final List<dynamic> ordenesCompraArchivos; // Archivos físicos opcionales
  final String nombreUsuario; // Para la baliza de auditoría
  final String rolUsuario;
  final String numeroOrdenVenta;

  const AprobarProformaComercialEvent({
    required this.ticket,
    required this.ordenesVentaArchivos,
    required this.ordenesCompraArchivos,
    required this.nombreUsuario,
    required this.rolUsuario,
    required this.numeroOrdenVenta,
  });

  @override
  List<Object?> get props => [
        ticket,
        ordenesVentaArchivos,
        ordenesCompraArchivos,
        nombreUsuario,
        rolUsuario,
        numeroOrdenVenta,
      ];
}

// ⚙️ EVENTO PARA EL TABLERO DE COSTOS
class CompletarFaseCostosEvent extends TicketEvent {
  final TicketEntity ticket;
  final String codigoProyecto;
  final String nombreUsuario;
  final String rolUsuario;

  const CompletarFaseCostosEvent({
    required this.ticket,
    required this.codigoProyecto,
    required this.nombreUsuario,
    required this.rolUsuario,
  });

  @override
  List<Object?> get props => [ticket, codigoProyecto, nombreUsuario, rolUsuario];
}

// ⚙️ EVENTO PARA EL TABLERO DE COMPRAS
class CompletarFaseComprasEvent extends TicketEvent {
  final TicketEntity ticket;
  final List<dynamic> ordenesCompraInternaArchivos; // Los PDFs que sube Compras
  final String nombreUsuario;
  final String rolUsuario;

  const CompletarFaseComprasEvent({
    required this.ticket,
    required this.ordenesCompraInternaArchivos,
    required this.nombreUsuario,
    required this.rolUsuario,
  });

  @override
  List<Object?> get props => [ticket, ordenesCompraInternaArchivos, nombreUsuario, rolUsuario];
}

class ConsumirRepuestosBodegaEvent extends TicketEvent {
  final TicketEntity ticket;
  final List<ItemCompraEntity> itemsActualizados;
  final String nombreUsuario;
  final String rolUsuario;

  const ConsumirRepuestosBodegaEvent({
    required this.ticket,
    required this.itemsActualizados,
    required this.nombreUsuario,
    required this.rolUsuario,
  });

  @override
  List<Object?> get props => [ticket, itemsActualizados, nombreUsuario, rolUsuario];
}

class CompletarProcesoTrabajoEvent extends TicketEvent {
  final TicketEntity ticket;
  final List<dynamic> evidenciasFinales; // Archivos físicos (Fotos/Videos)
  final String notasFinales;
  final String nombreUsuario;
  final String rolUsuario;

  const CompletarProcesoTrabajoEvent({
    required this.ticket,
    required this.evidenciasFinales,
    this.notasFinales = '',
    required this.nombreUsuario,
    required this.rolUsuario,
  });

  @override
  List<Object?> get props => [ticket, evidenciasFinales, notasFinales, nombreUsuario, rolUsuario];
}
class AnularTicketEvent extends TicketEvent {
  final TicketEntity ticket;
  final String nombreUsuario;
  final String rolUsuario;

  const AnularTicketEvent({
    required this.ticket, 
    required this.nombreUsuario, 
    required this.rolUsuario
  });
}
class SubirExcelComercialEvent extends TicketEvent {
  final String ticketId;
  final PlatformFile archivo;

  const SubirExcelComercialEvent({
    required this.ticketId,
    required this.archivo,
  });

  @override
  List<Object> get props => [ticketId, archivo];
}

/// Evento interno del BLoC disparado por el sensor (Stream) de Firestore.
/// Informa si el actuador remoto (Node.js) terminó su trabajo con o sin fallas.
class ExcelProcesadoEvento extends TicketEvent {
  final bool exito;
  final String? error;

  const ExcelProcesadoEvento({
    required this.exito,
    this.error,
  });

  @override
  List<Object?> get props => [exito, error];
}