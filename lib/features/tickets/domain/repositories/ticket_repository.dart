// lib/features/tickets/domain/repositories/ticket_repository.dart

import 'package:dartz/dartz.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/errors/failures.dart';
import '../entities/cliente_entity.dart';
import '../entities/ticket_entity.dart';
import 'dart:io';
import 'dart:typed_data';
import '../../../../core/enum/segmento_operativo.dart';

abstract class ITicketRepository {
  Future<Either<Failure, List<ClienteEntity>>> obtenerClientes();
  Future<Either<Failure, List<TicketEntity>>> obtenerTickets({SegmentoOperativo? segmentoUsuario});
  Future<Either<Failure, TicketEntity>> crearTicket(TicketEntity ticket);
  
  // ✅ EL ÚNICO CONDUCTO DE ACTUALIZACIÓN PERMITIDO
  Future<Either<Failure, TicketEntity>> actualizarTicket(TicketEntity ticket);
  
  Future<Either<Failure, TicketEntity>> notificarYGenerarActa(TicketEntity ticket);
  // Añade esta línea dentro de tu abstract class TicketRepository:
Future<Either<Failure, String>> subirActaPdfStorage(String ticketId, Uint8List pdfBytes);
  // Añadir en ITicketRepository
  Future<Either<Failure, String>> subirEvidencia(XFile file, String ticketId);
}