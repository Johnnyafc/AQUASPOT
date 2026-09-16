import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/cliente_entity.dart';
import '../repositories/cliente_repository.dart';

class ActualizarClienteUseCase {
  final ClienteRepository repository;

  ActualizarClienteUseCase(this.repository);

  Future<Either<Failure, void>> call(ClienteEntity cliente) async {
    if (cliente.id.trim().isEmpty) {
      return Left(ServerFailure('ID de cliente inválido para actualización.'));
    }
    if (cliente.direccion.trim().isEmpty || cliente.camaronera.trim().isEmpty) {
      return Left(ServerFailure('La Razón Social (dirección) y la Camaronera son campos obligatorios.'));
    }

    return await repository.actualizarCliente(cliente);
  }
}
