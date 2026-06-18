// lib/features/tickets/domain/repositories/ticket_repository.dart

import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/cliente_entity.dart';
import '../entities/ticket_entity.dart';

abstract class ITicketRepository {
  /// Obtiene la base maestra de clientes (El volcado del ERP)
  Future<Either<Failure, List<ClienteEntity>>> obtenerClientes();

  /// Etapa 1: Comercial/Operaciones registra el ingreso del equipo
  Future<Either<Failure, TicketEntity>> crearTicket(TicketEntity ticket);

  /// Etapa 2: Taller/Mantenimiento diagnostica e inyecta la evaluación
  Future<Either<Failure, TicketEntity>> actualizarEvaluacionTecnica(TicketEntity ticket);

  /// Etapa 3: Recepción Física y Gatillo al Backend (FastAPI)
  /// Este método es el que guardará el estado final en Firestore y además 
  /// disparará la petición HTTP a Python para escupir el PDF.
  Future<Either<Failure, TicketEntity>> notificarYGenerarActa(TicketEntity ticket);

  Future<Either<Failure, List<TicketEntity>>> obtenerTickets();

}