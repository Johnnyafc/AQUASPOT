// lib/features/tickets/domain/usecases/adjuntar_evidencias_mantenimiento_usecase.dart
//
// Guarda en el ticket de MANTENIMIENTO INTERNO las URLs de las evidencias ya
// subidas: fotos en fotosUrls; videos y la foto del horómetro / kilometraje
// en mantenimientoInterno (aparecen en la Biblioteca y en el Dashboard).

import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/ticket_entity.dart';
import '../repositories/ticket_repository.dart';

class AdjuntarEvidenciasMantenimientoUseCase {
  final ITicketRepository repository;

  AdjuntarEvidenciasMantenimientoUseCase(this.repository);

  Future<Either<Failure, TicketEntity>> call(
    TicketEntity ticket,
    List<String> urls, {
    List<String> videosUrls = const [],
    String? urlFotoLectura,
  }) {
    final mantenimiento = ticket.mantenimientoInterno;
    return repository.actualizarTicket(ticket.copyWith(
      fotosUrls: [...ticket.fotosUrls, ...urls],
      mantenimientoInterno: mantenimiento?.copyWith(
        urlFotoLectura: urlFotoLectura,
        videosUrls: [...mantenimiento.videosUrls, ...videosUrls],
      ),
    ));
  }
}
