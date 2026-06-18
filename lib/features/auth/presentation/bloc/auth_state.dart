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

// Baliza amarilla (Procesando validación)
class AuthLoading extends AuthState {}

// Baliza verde (Enclavamiento exitoso, tarjeta válida)
class Authenticated extends AuthState {
  final UsuarioEntity usuario;
  const Authenticated(this.usuario);

  @override
  List<Object?> get props => [usuario];
}

// Baliza roja (Operador sin acceso o desconectado)
class Unauthenticated extends AuthState {}

// Alarma de falla técnica
class AuthError extends AuthState {
  final String message;
  const AuthError(this.message);

  @override
  List<Object?> get props => [message];
}