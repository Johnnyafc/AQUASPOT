import 'package:aquaspot_postventa/core/errors/failures.dart';
import 'package:aquaspot_postventa/features/tickets/domain/repositories/ticket_repository.dart';
import 'package:dartz/dartz.dart';
import 'package:image_picker/image_picker.dart';

class SubirOrdenVentaUseCase {
  final ITicketRepository repository;
  SubirOrdenVentaUseCase(this.repository);

  Future<Either<Failure, String>> call(XFile file, String ticketId) {
    return repository.subirOrdenVenta(file, ticketId);
  }
}