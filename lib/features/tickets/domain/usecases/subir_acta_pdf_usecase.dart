import 'dart:typed_data';
import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../repositories/ticket_repository.dart';

class SubirActaPdfUseCase {
  final ITicketRepository  repository;

  SubirActaPdfUseCase(this.repository);

  Future<Either<Failure, String>> call(String ticketId, Uint8List pdfBytes) async {
    return await repository.subirActaPdfStorage(ticketId, pdfBytes);
  }
}