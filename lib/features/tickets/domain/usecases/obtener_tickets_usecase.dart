// lib/features/tickets/domain/usecases/obtener_tickets_usecase.dart

import 'package:aquaspot_postventa/core/enum/segmento_operativo.dart';
import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/ticket_entity.dart';
import '../repositories/ticket_repository.dart';

class ObtenerTicketsUseCase {
  // ✅ CORRECCIÓN: La interfaz lleva la "I" que definiste en tu arquitectura
  final ITicketRepository repository;

  // Inyección de dependencias estricta.
  ObtenerTicketsUseCase(this.repository);

  // El método call() permite ejecutar la clase como si fuera una función
Future<Either<Failure, List<TicketEntity>>> call({SegmentoOperativo? segmentoUsuario}) async {
   return await repository.obtenerTickets(segmentoUsuario: segmentoUsuario);
  }
}