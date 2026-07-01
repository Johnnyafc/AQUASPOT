import 'dart:io';
import 'package:dartz/dartz.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/errors/failures.dart';
import '../repositories/ticket_repository.dart';

class SubirEvidenciaUseCase {
  final ITicketRepository repository;

  SubirEvidenciaUseCase(this.repository);

  Future<Either<Failure, String>> call(XFile file, String ticketId) async {
    return await repository.subirEvidencia(file, ticketId);
  }
}