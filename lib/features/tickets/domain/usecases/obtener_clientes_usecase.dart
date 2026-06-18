// lib/features/tickets/domain/usecases/obtener_clientes_usecase.dart

import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/cliente_entity.dart';
import '../repositories/ticket_repository.dart';

class ObtenerClientesUseCase {
  final ITicketRepository repository;

  ObtenerClientesUseCase(this.repository);

  Future<Either<Failure, List<ClienteEntity>>> call() async {
    return await repository.obtenerClientes();
  }
}