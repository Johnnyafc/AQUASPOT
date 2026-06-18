// lib/features/auth/domain/usecases/cerrar_sesion_usecase.dart

import 'package:dartz/dartz.dart';
import '../../../../../core/errors/failures.dart';
import '../repositories/auth_repository.dart';

class CerrarSesionUseCase {
  final AuthRepository repository;

  CerrarSesionUseCase(this.repository);

  Future<Either<Failure, void>> call() async {
    return await repository.cerrarSesion();
  }
}