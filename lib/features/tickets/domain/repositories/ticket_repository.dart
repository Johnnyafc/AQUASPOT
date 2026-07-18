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