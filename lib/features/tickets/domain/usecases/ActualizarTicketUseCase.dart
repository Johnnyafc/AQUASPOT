// lib/features/tickets/domain/usecases/aprobar_evaluacion_usecase.dart

import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/ticket_entity.dart';
import '../repositories/ticket_repository.dart';

class ActualizarTicketUseCase {
  final ITicketRepository repository;

  ActualizarTicketUseCase(this.repository);

  Future<Either<Failure, TicketEntity>> call(TicketEntity ticket) async {
    return await repository.actualizarTicket(ticket);
  }
}