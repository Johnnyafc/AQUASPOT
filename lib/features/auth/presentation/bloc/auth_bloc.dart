// lib/features/auth/presentation/bloc/auth_bloc.dart

import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/usecases/cerrar_sesion_usecase.dart';
import '../../domain/usecases/iniciar_sesion_usecase.dart';
import 'auth_event.dart';
import 'auth_state.dart';
import '../../../../core/services/notification_service.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final IniciarSesionUseCase iniciarSesion;
  final CerrarSesionUseCase cerrarSesion;

  AuthBloc({
    required this.iniciarSesion,
    required this.cerrarSesion,
  }) : super(AuthInitial()) {
    on<IniciarSesionEvent>(_onIniciarSesion);
    on<CerrarSesionEvent>(_onCerrarSesion);
  }

  String _mapFailureToMessage(Failure failure) {
    if (failure is ServerFailure) return failure.message;
    if (failure is NetworkFailure) return failure.message;
    return 'Fallo catastrófico en el sistema de seguridad.';
  }

Future<void> _onIniciarSesion(IniciarSesionEvent event, Emitter<AuthState> emit) async {
  emit(AuthLoading());

  final failureOrUser = await iniciarSesion(event.email, event.password);

  // Manejo de la bifurcación (Either) con await estricto
  await failureOrUser.fold(
    (failure) async {
      emit(AuthError(_mapFailureToMessage(failure)));
    },
    (usuario) async {
      // 1. Esperamos obligatoriamente que el registro termine (sea exitoso o falle)
      await NotificationService.registrarToken(usuario.uid);
      
      // 2. Solo emitimos si el handler del evento no ha sido cerrado por el framework
      if (!emit.isDone) {
        emit(Authenticated(usuario));
      }
    },
  );
}

  Future<void> _onCerrarSesion(CerrarSesionEvent event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    final failureOrSuccess = await cerrarSesion();
    
    failureOrSuccess.fold(
      (failure) => emit(AuthError(_mapFailureToMessage(failure))),
      (_) => emit(Unauthenticated()), // Cortamos la corriente al panel principal
    );
  }
}