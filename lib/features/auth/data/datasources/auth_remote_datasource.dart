// lib/features/auth/data/datasources/auth_remote_datasource.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/usuario_entity.dart';
import '../../../../../core/errors/failures.dart';

abstract class AuthRemoteDataSource {
  Future<UsuarioEntity> iniciarSesion(String email, String password);
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final FirebaseAuth firebaseAuth;
  final FirebaseFirestore firestore;

  AuthRemoteDataSourceImpl({
    required this.firebaseAuth,
    required this.firestore,
  });

  // Traductor de Strings de la base de datos al Enum estricto de nuestro sistema
  RolUsuario _mapearRol(String rolString) {
    switch (rolString.toUpperCase()) {
      case 'REQUERIMIENTO':
        return RolUsuario.requerimiento;
      case 'TECNICO':
        return RolUsuario.tecnico;
      case 'SUPERVISOR':
        return RolUsuario.supervisor;
      case 'RECEPCION':
        return RolUsuario.recepcion;
      
      default:
        return RolUsuario.desconocido;
    }
  }

  @override
  Future<UsuarioEntity> iniciarSesion(String email, String password) async {
    try {
      // 1. Validamos la huella dactilar (Email y Clave)
      final userCredential = await firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = userCredential.user;
      if (user == null) {
        throw ServerFailure('Fallo catastrófico en la autenticación del motor.');
      }

      // 2. Buscamos el perfil de seguridad en Firestore usando el UID
      final docSnapshot = await firestore.collection('usuarios').doc(user.uid).get();

      if (!docSnapshot.exists) {
        await firebaseAuth.signOut(); 
        throw ServerFailure('Operador sin perfil de seguridad asignado en el sistema.');
      }

      final data = docSnapshot.data()!;
      final rol = _mapearRol(data['rol'] ?? '');

      if (rol == RolUsuario.desconocido) {
        await firebaseAuth.signOut();
        throw ServerFailure('Nivel de acceso corrupto o no reconocido.');
      }

      // 3. Extraemos el nombre registrado en la base de datos
      // Nota: Si el campo en Firestore se llama distinto (ej: 'Nombre'), ajusta la llave aquí.
      final String nombreCapturado = data['nombre'] ?? 'Operario Desconocido';

      // 4. Emitimos la tarjeta de identificación válida con los 4 parámetros requeridos
      return UsuarioEntity(
        uid: user.uid,
        email: user.email!,
        nombre: nombreCapturado, // ✅ Parámetro ahora integrado
        rol: rol,
      );
      
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found' || e.code == 'wrong-password' || e.code == 'invalid-credential') {
        throw ServerFailure('Credenciales denegadas. Operador no autorizado.');
      }
      throw ServerFailure(e.message ?? 'Error de protocolo en FirebaseAuth.');
    } catch (e) {
      throw ServerFailure('Fallo interno del lector RFID: $e');
    }
  }
}