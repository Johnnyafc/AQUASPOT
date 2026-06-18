// lib/features/tickets/domain/usecases/crear_ticket_usecase.dart

import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/ticket_entity.dart';
import '../repositories/ticket_repository.dart';

class CrearTicketUseCase {
  final ITicketRepository repository;

  CrearTicketUseCase(this.repository);

  Future<Either<Failure, TicketEntity>> call(TicketEntity ticket) async {
    // Aquí en el futuro puedes inyectar lógica pura: 
    // ej. if (ticket.fallaReportada.isEmpty) return Left(ValidationFailure());
    return await repository.crearTicket(ticket);
  }
}