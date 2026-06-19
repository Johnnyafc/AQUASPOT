// lib/features/tickets/domain/repositories/ticket_repository.dart

import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/cliente_entity.dart';
import '../entities/ticket_entity.dart';
import 'dart:io';

abstract class ITicketRepository {
  Future<Either<Failure, List<ClienteEntity>>> obtenerClientes();
  Future<Either<Failure, List<TicketEntity>>> obtenerTickets();
  Future<Either<Failure, TicketEntity>> crearTicket(TicketEntity ticket);
  
  // ✅ EL ÚNICO CONDUCTO DE ACTUALIZACIÓN PERMITIDO
  Future<Either<Failure, TicketEntity>> actualizarTicket(TicketEntity ticket);
  
  Future<Either<Failure, TicketEntity>> notificarYGenerarActa(TicketEntity ticket);
  // Añadir en ITicketRepository
}