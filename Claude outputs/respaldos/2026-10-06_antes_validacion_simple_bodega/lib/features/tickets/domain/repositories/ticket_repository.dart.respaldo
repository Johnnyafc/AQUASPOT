// lib/features/tickets/domain/repositories/ticket_repository.dart

import 'package:dartz/dartz.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/errors/failures.dart';
import '../entities/cliente_entity.dart';
import '../entities/ticket_entity.dart';
import 'dart:io';
import 'dart:typed_data';
import '../../../../core/enum/segmento_operativo.dart';

abstract class ITicketRepository {
  Future<Either<Failure, List<ClienteEntity>>> obtenerClientes();
  Future<Either<Failure, List<TicketEntity>>> obtenerTickets(SegmentoOperativo segmento);
  Future<Either<Failure, TicketEntity>> crearTicket(TicketEntity ticket);
  
  // ✅ EL ÚNICO CONDUCTO DE ACTUALIZACIÓN PERMITIDO
  Future<Either<Failure, TicketEntity>> actualizarTicket(TicketEntity ticket);
  // NUEVO: escritura parcial por campos (ver ITicketRepository / datasource).
  Future<Either<Failure, TicketEntity>> actualizarCampos(String ticketId, Map<String, dynamic> campos);
  // NUEVO: escritura parcial con candado de estado (ver datasource).
  Future<Either<Failure, void>> actualizarCamposConGuardaEstado({
    required String ticketId,
    required Map<String, dynamic> campos,
    required List<String> estadosPermitidos,
  });

  // NUEVO: evidencias de despacho de bodega + descuento automatico de
  // stock (ver datasource / ticket_bloc._onActualizarEvidenciasDespacho).
  Future<Either<Failure, void>> guardarEvidenciasDespachoConDescuentoStock({
    required String ticketId,
    required String despachoId,
    required Map<String, dynamic> campos,
    required List<Map<String, dynamic>> itemsADescontar,
    required bool liberarReserva,
  });

  // NUEVO: reserva de stock (Caracol) -- ver datasource.
  Future<Either<Failure, void>> guardarEvaluacionTecnicaConReservaStock({
    required TicketEntity ticket,
    required List<Map<String, dynamic>> itemsAReservar,
  });

  Future<Either<Failure, void>> actualizarCamposConGuardaEstadoYAjusteReserva({
    required String ticketId,
    required Map<String, dynamic> campos,
    required List<String> estadosPermitidos,
    required List<Map<String, dynamic>> repuestosTallerNuevos,
  });

  Future<Either<Failure, void>> anularTicketConLiberacionReserva({
    required TicketEntity ticket,
  });

  
  Future<Either<Failure, TicketEntity>> notificarYGenerarActa(TicketEntity ticket);
  // Añade esta línea dentro de tu abstract class TicketRepository:
Future<Either<Failure, String>> subirActaPdfStorage(String ticketId, Uint8List pdfBytes);
  // Añadir en ITicketRepository
  Future<Either<Failure, String>> subirEvidencia(XFile file, String ticketId);
  Future<Either<Failure, Uint8List>> generarActaPdf({
    required TicketEntity ticket,
    required String tipoRequerimiento,
    required String descripcion,
    required List<XFile> evidencias,
  });
  Future<Either<Failure, String>> subirArchivoDocumental(PlatformFile archivo, String ticketId, String subcarpeta);
  // 🔧 NUEVO CONTRATO COMERCIAL
  Future<Either<Failure, String>> subirDocumentoComercial(String ticketId, PlatformFile archivo, String tipoDocumento);
  Future<Either<Failure, String>> subirOrdenCompra(XFile file, String ticketId);
  Future<Either<Failure, String>> subirOrdenVenta(XFile file, String ticketId);
  Future<Either<Failure, void>> anularTicket(String ticketId, Map<String, dynamic> data);
  Stream<String?> escucharEstadoProcesamientoExcel(String ticketId);
}