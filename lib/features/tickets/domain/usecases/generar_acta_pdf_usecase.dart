import 'dart:io';
import 'dart:typed_data';
import 'package:dartz/dartz.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/errors/failures.dart';
import '../entities/ticket_entity.dart';
import '../repositories/ticket_repository.dart'; // O el servicio de PDF que uses

class GenerarActaPdfUseCase {
  // Inyectamos la interfaz, no la implementación concreta
  final ITicketRepository repository;

  GenerarActaPdfUseCase(this.repository);

  // Ejecutamos la orden pasando los planos (parámetros)
  Future<Either<Failure, Uint8List>> call({
    required TicketEntity ticket,
    required String tipoRequerimiento,
    required String descripcion,
    required List<XFile> evidencias,
  }) async {
    
    // Validación de seguridad antes de mandar a procesar
    if (ticket.id.isEmpty) {
      return Left(ServerFailure("El ticket no tiene un ID válido para generar el acta."));
    }

    // Delegamos la fabricación del PDF al repositorio/servicio de infraestructura
    return await repository.generarActaPdf(
      ticket: ticket,
      tipoRequerimiento: tipoRequerimiento,
      descripcion: descripcion,
      evidencias: evidencias,
    );
  }
}