import 'package:aquaspot_postventa/core/errors/failures.dart';
import 'package:aquaspot_postventa/features/tickets/domain/repositories/ticket_repository.dart';
import 'package:dartz/dartz.dart';
import 'package:image_picker/image_picker.dart';

class SubirOrdenCompraUseCase {
  final ITicketRepository repository;
  SubirOrdenCompraUseCase(this.repository);

  Future<Either<Failure, String>> call(XFile file, String ticketId) {
    return repository.subirOrdenCompra(file, ticketId);
  }
}