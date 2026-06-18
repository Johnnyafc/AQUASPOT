// lib/features/auth/data/repositories/auth_repository_impl.dart

import 'package:dartz/dartz.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../../core/errors/failures.dart';
import '../../../../../core/network/network_info.dart';
import '../../domain/entities/usuario_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource remoteDataSource;
  final NetworkInfo networkInfo;
  final FirebaseAuth firebaseAuth;

  AuthRepositoryImpl({
    required this.remoteDataSource,
    required this.networkInfo,
    required this.firebaseAuth,
  });

  @override
  Future<Either<Failure, UsuarioEntity>> iniciarSesion(String email, String password) async {
    // 1. Verificamos si hay conexión física a la red
    if (await networkInfo.isConnected) {
      try {
        // 2. Disparamos la lectura del RFID
        final usuario = await remoteDataSource.iniciarSesion(email, password);
        return Right(usuario); // Señal nominal (Verde)
      } on ServerFailure catch (e) {
        return Left(e); // Propagamos la alarma específica del sensor
      } catch (e) {
        return const Left(ServerFailure('Fallo no clasificado en la lectura de credenciales.'));
      }
    } else {
      // Circuito abierto por falta de internet
      return const Left(NetworkFailure('Sin conexión a la red de telemetría.'));
    }
  }

  @override
  Future<Either<Failure, void>> cerrarSesion() async {
    try {
      await firebaseAuth.signOut();
      return const Right(null);
    } catch (e) {
      return const Left(ServerFailure('Error al intentar desconectar el panel local.'));
    }
  }
}