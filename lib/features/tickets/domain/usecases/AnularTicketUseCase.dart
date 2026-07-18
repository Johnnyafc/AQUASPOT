import 'package:aquaspot_postventa/core/errors/failures.dart';
import 'package:aquaspot_postventa/features/tickets/domain/repositories/ticket_repository.dart';
import 'package:dartz/dartz.dart';

class AnularTicketUseCase {
  final ITicketRepository repository;
  AnularTicketUseCase(this.repository);

  Future<Either<Failure, void>> call(String ticketId, Map<String, dynamic> data) {
    return repository.anularTicket(ticketId, data);
  }
}