// lib/features/auth/domain/usecases/iniciar_sesion_usecase.dart

import 'package:dartz/dartz.dart';
import '../../../../../core/errors/failures.dart';
import '../entities/usuario_entity.dart';
import '../repositories/auth_repository.dart';

class IniciarSesionUseCase {
  final AuthRepository repository;

  IniciarSesionUseCase(this.repository);

  // El método call() permite ejecutar la clase como si fuera una función pura
  Future<Either<Failure, UsuarioEntity>> call(String email, String password) async {
    return await repository.iniciarSesion(email, password);
  }
}