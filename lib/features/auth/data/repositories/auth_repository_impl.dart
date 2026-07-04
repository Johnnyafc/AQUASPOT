// lib/features/auth/data/repositories/auth_repository_impl.dart

import 'package:dartz/dartz.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../../core/errors/failures.dart';
import '../../../../../core/network/network_info.dart';
import '../../domain/entities/usuario_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';
import '../../../../core/enum/rol_usuario.dart';
import '../../../../core/enum/segmento_operativo.dart';

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

@override
  Future<Either<Failure, void>> registrarUsuario({
    required String nombre,
    required String email,
    required String password,
    required SegmentoOperativo segmento,
    required RolUsuario rol,
  }) async {
    try {
      // 1. CREACIÓN EN AUTH (Usando una instancia secundaria para no cerrar sesión del admin)
      // Nota: Debes haber inicializado esta app secundaria al arrancar la app.
      // Si no quieres complicarte ahora, usa createUserWithEmailAndPassword, 
      // pero ten en cuenta que te logueará como el nuevo usuario inmediatamente.
      
      final UserCredential userCredential = await firebaseAuth.createUserWithEmailAndPassword(
        email: email, 
        password: password
      );

      final String uid = userCredential.user!.uid;

      // 2. PERSISTENCIA DEL PERFIL EN FIRESTORE
      // Usamos el UID generado por Auth para identificar al documento en Firestore
      await remoteDataSource.guardarPerfilUsuario(
        uid: uid,
        nombre: nombre,
        email: email,
        segmento: segmento,
        rol: rol,
      );

      return const Right(null);
      
    } on FirebaseAuthException catch (e) {
      return Left(ServerFailure(e.message ?? 'Error crítico en el nodo de Autenticación'));
    } catch (e) {
      return Left(ServerFailure('Fallo estructural en el proceso de alta: $e'));
    }
  }


}