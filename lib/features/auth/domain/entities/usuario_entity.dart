// lib/features/auth/domain/entities/usuario_entity.dart

import 'package:equatable/equatable.dart';

// El nivel de privilegios del operador
enum RolUsuario { 
  requerimiento, 
  tecnico, 
  supervisor, 
  desconocido // Estado de fallo de seguridad
}

class UsuarioEntity extends Equatable {
  final String uid;
  final String email;
  final String nombre;
  final RolUsuario rol;

  const UsuarioEntity({
    required this.uid,
    required this.email,
    required this.nombre,
    required this.rol,
  });

  @override
List<Object?> get props => [uid, email, nombre, rol];
}