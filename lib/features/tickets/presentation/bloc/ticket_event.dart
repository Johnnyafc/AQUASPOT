import 'package:equatable/equatable.dart';
import 'package:image_picker/image_picker.dart';
import '../../domain/entities/ticket_entity.dart';
import '../../domain/entities/ticket_enums.dart'; 
import '../../../../core/enum/segmento_operativo.dart';

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
    evidencias
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
  });

  @override
  List<Object?> get props => [
        sede, clienteId, campamento, nombreContacto, telefonoContacto, 
        emailContacto, equipo, equipoDetalle, fallaReportada, 
        nombreUsuario, rolUsuario, evidencias
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