import 'dart:io';
import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../repositories/ticket_repository.dart';

class SubirEvidenciaUseCase {
  final ITicketRepository repository;

  SubirEvidenciaUseCase(this.repository);

  Future<Either<Failure, String>> call(File file, String ticketId) async {
    return await repository.subirEvidencia(file, ticketId);
  }
}