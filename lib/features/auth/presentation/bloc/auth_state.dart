// lib/features/auth/presentation/bloc/auth_state.dart

import 'package:equatable/equatable.dart';
import '../../domain/entities/usuario_entity.dart';

abstract class AuthState extends Equatable {
  const AuthState();
  
  @override
  List<Object?> get props => [];
}

// Baliza apagada (Estado inicial)
class AuthInitial extends AuthState {}

// Baliza amarilla (Procesando validación / Creando usuario)
class AuthLoading extends AuthState {}

// Baliza verde continua (Enclavamiento exitoso, tarjeta válida)
class Authenticated extends AuthState {
  final UsuarioEntity usuario;
  const Authenticated(this.usuario);

  @override
  List<Object?> get props => [usuario];
}

// Baliza roja continua (Operador sin acceso o desconectado)
class Unauthenticated extends AuthState {}

// 🚀 NUEVO ESTADO: Baliza verde intermitente (Nuevo operario registrado con éxito)
class AuthRegistrationSuccess extends AuthState {
  final String message;
  const AuthRegistrationSuccess(this.message);

  @override
  List<Object?> get props => [message];
}

// Alarma de falla técnica (Credenciales inválidas, error de red)
class AuthError extends AuthState {
  final String message;
  const AuthError(this.message);

  @override
  List<Object?> get props => [message];
}