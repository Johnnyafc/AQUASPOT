// lib/features/tickets/domain/usecases/adjuntar_evidencias_mantenimiento_usecase.dart
//
// Guarda en el ticket de MANTENIMIENTO INTERNO las URLs de las fotos ya
// subidas (fotosUrls: aparecen en la Biblioteca y en el Dashboard).

import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/ticket_entity.dart';
import '../repositories/ticket_repository.dart';

class AdjuntarEvidenciasMantenimientoUseCase {
  final ITicketRepository repository;

  AdjuntarEvidenciasMantenimientoUseCase(this.repository);

  Future<Either<Failure, TicketEntity>> call(TicketEntity ticket, List<String> urls) {
    return repository.actualizarTicket(ticket.copyWith(fotosUrls: [...ticket.fotosUrls, ...urls]));
  }
}
