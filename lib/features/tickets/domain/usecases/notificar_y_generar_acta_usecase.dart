// lib/features/tickets/domain/usecases/notificar_y_generar_acta_usecase.dart

import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/ticket_entity.dart';
import '../repositories/ticket_repository.dart';

class NotificarYGenerarActaUseCase {
  final ITicketRepository repository;

  NotificarYGenerarActaUseCase(this.repository);

  Future<Either<Failure, TicketEntity>> call(TicketEntity ticket) async {
    return await repository.notificarYGenerarActa(ticket);
  }
}