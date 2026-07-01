// lib/features/tickets/presentation/bloc/ticket_event.dart

import 'package:equatable/equatable.dart';
import 'package:image_picker/image_picker.dart';
import '../../domain/entities/ticket_entity.dart';
import '../../../../core/enum/segmento_operativo.dart';
import 'dart:io';
import 'dart:typed_data';

abstract class TicketEvent extends Equatable {
  const TicketEvent();

  @override
  List<Object> get props => [];
}

class SubirEvidenciaEvent extends TicketEvent {
  final XFile file;
  final String ticketId;

  const SubirEvidenciaEvent({required this.file, required this.ticketId});

  @override
  List<Object> get props => [file, ticketId];
}

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
  List<Object> get props => [ticket, nombreUsuario, rolUsuario];
}

// 3. Etapa 2: Tyron en el taller emite su diagnóstico
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

// Añadir al final de lib/features/tickets/presentation/bloc/ticket_event.dart

class ConfirmarRecepcionEvent extends TicketEvent {
  final TicketEntity ticket;
  final String nombreUsuario;
  final String rolUsuario;
  final String notasRecepcion;
  final List<XFile> evidencias; // ✅ NUEVO: Puerto para la telemetría visual
  final Uint8List pdfBytes;

  const ConfirmarRecepcionEvent({
    required this.ticket,
    required this.nombreUsuario,
    required this.rolUsuario,
    required this.pdfBytes,
    this.notasRecepcion = '',
    this.evidencias = const [], // Valor por defecto vacío para no quebrar otras partes
  });

  @override
  // No olvides agregarlo a las props para que Equatable detecte los cambios
  List<Object> get props => [ticket, nombreUsuario, rolUsuario, notasRecepcion, evidencias]; 
}