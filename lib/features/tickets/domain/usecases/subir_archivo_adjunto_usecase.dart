// lib/features/tickets/domain/usecases/subir_archivo_adjunto_usecase.dart
//
// Sube un ArchivoAdjunto (bytes + nombre) a la carpeta del ticket y devuelve
// su URL. Reemplaza a SubirEvidenciaUseCase en el código nuevo (sin XFile
// en el dominio).

import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/archivo_adjunto.dart';
import '../repositories/ticket_repository.dart';

class SubirArchivoAdjuntoUseCase {
  final ITicketRepository repository;

  SubirArchivoAdjuntoUseCase(this.repository);

  Future<Either<Failure, String>> call(ArchivoAdjunto archivo, String ticketId, {String carpeta = 'evidencia'}) {
    return repository.subirArchivoAdjunto(archivo, ticketId, carpeta);
  }
}
