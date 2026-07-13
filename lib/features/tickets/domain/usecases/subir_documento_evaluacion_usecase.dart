// En lib/features/tickets/domain/usecases/subir_documento_evaluacion_usecase.dart
import 'dart:io';
import 'package:dartz/dartz.dart';
import 'package:file_picker/file_picker.dart';
import '../../../../core/errors/failures.dart';
import '../repositories/ticket_repository.dart';

class SubirDocumentoEvaluacionUseCase {
  final ITicketRepository repository;

  SubirDocumentoEvaluacionUseCase(this.repository);

  Future<Either<Failure, String>> call(PlatformFile archivo, String ticketId, String subcarpeta) async {
    return await repository.subirArchivoDocumental(archivo, ticketId, subcarpeta);
  }
}