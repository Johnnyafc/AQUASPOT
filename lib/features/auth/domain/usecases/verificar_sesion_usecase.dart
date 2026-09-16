import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/usuario_entity.dart';
import '../repositories/auth_repository.dart';

class VerificarSesionUseCase {
  final AuthRepository repository;

  VerificarSesionUseCase(this.repository);

  Future<Either<Failure, UsuarioEntity>> call() async {
    return await repository.verificarSesion();
  }
}