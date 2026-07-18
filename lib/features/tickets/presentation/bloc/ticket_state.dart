import 'dart:typed_data';
import 'package:equatable/equatable.dart';
import '../../domain/entities/cliente_entity.dart';
import '../../domain/entities/ticket_entity.dart';
// ⚙️ Asegúrate de importar tu archivo de Enums
import '../../../../core/enum/ticket_enums.dart'; 

enum TicketStatus { 
  initial, 
  loading, 
  loaded, 
  operationSuccess, 
  evidenceUploaded, 
  error 
}

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
  final Uint8List? pdfBytes;

  // 🚀 LOS NUEVOS SENSORES DE REQUERIMIENTO
  final TipoRequerimiento tipoSeleccionado;
  final LugarAtencion lugarAtencion;

  final List<String> codigoOrdenVenta;
  final List<String> codigoOrdenCompra;

  const TicketState({
    this.status = TicketStatus.initial,
    this.tickets = const [],
    this.clientes = const [],
    this.historial = const [],
    this.message = '',
    this.currentTicket,
    this.evidenciaUrl,
    this.pdfBytes,
    // ⚙️ Valores neutros de fábrica para que el menú arranque cerrado
    this.tipoSeleccionado = TipoRequerimiento.ninguno,
    this.lugarAtencion = LugarAtencion.noAplica,
    this.codigoOrdenVenta = const [],
    this.codigoOrdenCompra = const [],
  });

  List<TicketEntity> get ticketsComerciales => 
      historial.where((t) => t.estadoActual == EstadoTicket.comercial).toList();
  
  List<TicketEntity> get proformasEnviadas => 
      historial.where((t) => t.estadoActual == EstadoTicket.cotizado).toList();

  TicketState copyWith({
    TicketStatus? status,
    List<TicketEntity>? tickets,
    List<ClienteEntity>? clientes,
    List<TicketEntity>? historial,
    String? message,
    TicketEntity? currentTicket,
    String? evidenciaUrl,
    Uint8List? pdfBytes,
    // 🚀 Añadimos los parámetros al mutador
    TipoRequerimiento? tipoSeleccionado,
    LugarAtencion? lugarAtencion,
    List<String>? codigoOrdenVenta,
    List<String>? codigoOrdenCompra,
  }) {
    return TicketState(
      status: status ?? this.status,
      tickets: tickets ?? this.tickets,
      clientes: clientes ?? this.clientes,
      historial: historial ?? this.historial,
      message: message ?? this.message,
      currentTicket: currentTicket ?? this.currentTicket,
      evidenciaUrl: evidenciaUrl ?? this.evidenciaUrl,
      pdfBytes: pdfBytes ?? this.pdfBytes,
      // 🚀 Asignamos la mutación
      tipoSeleccionado: tipoSeleccionado ?? this.tipoSeleccionado,
      lugarAtencion: lugarAtencion ?? this.lugarAtencion,
      codigoOrdenVenta: codigoOrdenVenta ?? this.codigoOrdenVenta,
      codigoOrdenCompra: codigoOrdenCompra ?? this.codigoOrdenCompra,
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
        pdfBytes,
        // 🚀 Vital para que el AnimatedSwitcher del UI detecte el cambio y se mueva
        tipoSeleccionado,
        lugarAtencion,
        codigoOrdenVenta,
        codigoOrdenCompra,
      ];
}