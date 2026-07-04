// lib/features/auth/domain/repositories/auth_repository.dart

import 'package:dartz/dartz.dart';
import '../../../../../core/errors/failures.dart';
import '../entities/usuario_entity.dart';
import '../../../../core/enum/segmento_operativo.dart';
import '../../../../core/enum/rol_usuario.dart';

abstract class AuthRepository {
  // Retorna un Fallo (Izquierda) o la Tarjeta del Usuario (Derecha)
  Future<Either<Failure, UsuarioEntity>> iniciarSesion(String email, String password);
  
  // Para cuando el operador retire la tarjeta
  Future<Either<Failure, void>> cerrarSesion();

  Future<Either<Failure, void>> registrarUsuario({
    required String nombre,
    required String email,
    required String password,
    required SegmentoOperativo segmento,
    required RolUsuario rol,
  });
}