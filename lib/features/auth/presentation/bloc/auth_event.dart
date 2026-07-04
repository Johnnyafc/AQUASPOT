// lib/features/auth/presentation/bloc/auth_event.dart

import 'package:equatable/equatable.dart';
import '../../../../core/enum/rol_usuario.dart';
import '../../../../core/enum/segmento_operativo.dart';
abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object> get props => [];
}

class IniciarSesionEvent extends AuthEvent {
  final String email;
  final String password;

  const IniciarSesionEvent({required this.email, required this.password});

  @override
  List<Object> get props => [email, password];
}

class CerrarSesionEvent extends AuthEvent {}

class RegistrarUsuarioEvent extends AuthEvent {
  final String nombre;
  final String email;
  final String password;
  final SegmentoOperativo segmento;
  final RolUsuario rol;

  const RegistrarUsuarioEvent({
    required this.nombre,
    required this.email,
    required this.password,
    required this.segmento,
    required this.rol,
  });

  @override
  List<Object> get props => [nombre, email, password, segmento, rol];
}