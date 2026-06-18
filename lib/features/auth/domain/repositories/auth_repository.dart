// lib/features/auth/domain/repositories/auth_repository.dart

import 'package:dartz/dartz.dart';
import '../../../../../core/errors/failures.dart';
import '../entities/usuario_entity.dart';

abstract class AuthRepository {
  // Retorna un Fallo (Izquierda) o la Tarjeta del Usuario (Derecha)
  Future<Either<Failure, UsuarioEntity>> iniciarSesion(String email, String password);
  
  // Para cuando el operador retire la tarjeta
  Future<Either<Failure, void>> cerrarSesion();
}