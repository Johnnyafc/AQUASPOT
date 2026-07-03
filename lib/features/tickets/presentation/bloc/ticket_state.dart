import 'dart:typed_data'; // ⚙️ CRÍTICO: Necesitas esto para Uint8List
import 'package:equatable/equatable.dart';
import '../../domain/entities/cliente_entity.dart';
import '../../domain/entities/ticket_entity.dart';

// 1. El Enum de Estado
enum TicketStatus { 
  initial, 
  loading, 
  loaded, 
  operationSuccess, 
  evidenceUploaded, 
  error 
}

// 2. El Estado Único
class TicketState extends Equatable {
  final TicketStatus status;
  
  // Datos persistentes en memoria
  final List<TicketEntity> tickets;
  final List<ClienteEntity> clientes;
  final List<TicketEntity> historial;
  
  // Datos transitorios
  final String message;
  final TicketEntity? currentTicket;
  final String? evidenciaUrl;
  final Uint8List? pdfBytes; // 🚀 AQUÍ ESTÁ EL CAMPO QUE FALTABA

  const TicketState({
    this.status = TicketStatus.initial,
    this.tickets = const [],
    this.clientes = const [],
    this.historial = const [],
    this.message = '',
    this.currentTicket,
    this.evidenciaUrl,
    this.pdfBytes, // 🚀 Añadido al constructor
  });

  // 3. El copyWith
  TicketState copyWith({
    TicketStatus? status,
    List<TicketEntity>? tickets,
    List<ClienteEntity>? clientes,
    List<TicketEntity>? historial,
    String? message,
    TicketEntity? currentTicket,
    String? evidenciaUrl,
    Uint8List? pdfBytes, // 🚀 Añadido a los parámetros
  }) {
    return TicketState(
      status: status ?? this.status,
      tickets: tickets ?? this.tickets,
      clientes: clientes ?? this.clientes,
      historial: historial ?? this.historial,
      message: message ?? this.message,
      currentTicket: currentTicket ?? this.currentTicket,
      evidenciaUrl: evidenciaUrl ?? this.evidenciaUrl,
      pdfBytes: pdfBytes ?? this.pdfBytes, // 🚀 Añadida la mutación
    );
  }

  @override
  List<Object?> get props => [
        status,
        tickets,
        clientes,
        historial,
        message,
        currentTicket,
        evidenciaUrl,
        pdfBytes, // 🚀 Añadido a las props para que Equatable lo detecte
      ];
}