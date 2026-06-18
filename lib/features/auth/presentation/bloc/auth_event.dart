// lib/features/auth/presentation/bloc/auth_event.dart

import 'package:equatable/equatable.dart';

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