import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/cliente_entity.dart';
import '../repositories/cliente_repository.dart';

class ObtenerTodosClientesUseCase {
  final ClienteRepository repository;

  ObtenerTodosClientesUseCase(this.repository);

  Future<Either<Failure, List<ClienteEntity>>> call() async {
    return await repository.obtenerClientes();
  }
}
