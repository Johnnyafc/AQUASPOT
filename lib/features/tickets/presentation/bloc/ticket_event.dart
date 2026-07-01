import 'package:equatable/equatable.dart';
import 'package:image_picker/image_picker.dart';
import '../../domain/entities/ticket_entity.dart';
import '../../domain/entities/ticket_enums.dart'; // ✅ Requerido para usar Prioridad
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

class ConfirmarRecepcionEvent extends TicketEvent {
  final TicketEntity ticket;
  final String nombreUsuario;
  final String rolUsuario;
  final String tipoRequerimiento; // ✅ Agregado: Para saber si es Garantía o Mantenimiento
  final Prioridad prioridad;      // ✅ Agregado: Para el nivel de urgencia
  final String notasRecepcion;
  final List<XFile> evidencias; 

  const ConfirmarRecepcionEvent({
    required this.ticket,
    required this.nombreUsuario,
    required this.rolUsuario,
    required this.tipoRequerimiento,
    required this.prioridad,
    this.notasRecepcion = '',
    this.evidencias = const [],
  });

  @override
  // 🛑 IMPORTANTE: Equatable necesita todas las variables de instancia aquí para evitar repintados fantasma.
  List<Object> get props => [
    ticket, 
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
  final TicketEntity ticket;
  final List<XFile> evidencias;
  final String nombreUsuario;
  final String rolUsuario;

  const CrearTicketEvent({
    required this.ticket,
    required this.nombreUsuario,
    required this.evidencias,
    required this.rolUsuario,
  });

  @override
  List<Object> get props => [ticket, nombreUsuario, rolUsuario, evidencias];
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