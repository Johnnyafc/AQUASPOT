// lib/features/auth/presentation/bloc/auth_bloc.dart

import 'package:aquaspot_postventa/features/auth/domain/usecases/verificar_sesion_usecase.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/usecases/cerrar_sesion_usecase.dart';
import '../../domain/usecases/iniciar_sesion_usecase.dart';
import 'auth_event.dart';
import 'auth_state.dart';
import '../../../../core/services/notification_service.dart';
import '../../domain/usecases/registrar_usuario_usecase.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final IniciarSesionUseCase iniciarSesion;
  final CerrarSesionUseCase cerrarSesion;
  final RegistrarUsuarioUseCase registrarUsuarioUseCase;
  final VerificarSesionUseCase verificarSesionUseCase; 

  AuthBloc({
    required this.iniciarSesion,
    required this.cerrarSesion,
    required this.registrarUsuarioUseCase,
    required this.verificarSesionUseCase,
  }) : super(AuthInitial()) {
    on<VerificarSesionEvent>(_onVerificarSesion);
    on<IniciarSesionEvent>(_onIniciarSesion);
    on<CerrarSesionEvent>(_onCerrarSesion);
    on<RegistrarUsuarioEvent>(_onRegistrarUsuario);
  }

  Future<void> _onVerificarSesion(VerificarSesionEvent event, Emitter<AuthState> emit) async {
    emit(AuthLoading());

    final failureOrUser = await verificarSesionUseCase();

    await failureOrUser.fold(
      (failure) async {
        // La HMI no detecta energía residual. Lo mandamos a loguearse.
        emit(Unauthenticated());
      },
      (usuario) async {
        // 1. 🚀 ENERGIZAR LA HMI INMEDIATAMENTE
        // Emitimos primero para que la pantalla pase al panel de control sin bloqueos de red
        if (!emit.isDone) {
          emit(Authenticated(usuario)); 
        }
        
        // 2. 📡 SUBRUTINA ASÍNCRONA DE TELEMETRÍA (Fire-and-forget)
        // Se ejecuta en paralelo sin congelar la máquina de estados
        _energizarComunicacionesFCM(usuario.uid);
      },
    );
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
        // 1. 🚀 ENERGIZAR LA HMI INMEDIATAMENTE
        if (!emit.isDone) {
          emit(Authenticated(usuario));
        }
        
        // 2. 📡 SUBRUTINA ASÍNCRONA DE TELEMETRÍA
        _energizarComunicacionesFCM(usuario.uid);
      },
    );
  }

  Future<void> _onCerrarSesion(CerrarSesionEvent event, Emitter<AuthState> emit) async {
    // 1. PROTOCOLO DE DESENCLAVAMIENTO: Recuperamos el UID antes de destruir el estado
    if (state is Authenticated) {
      final operarioEnTurno = (state as Authenticated).usuario;
      // Purga de token en Firestore y en la memoria del dispositivo
      await NotificationService.eliminarToken(operarioEnTurno.uid); 
    }

    // 2. Iniciamos secuencia de apagado
    emit(AuthLoading());
    final failureOrSuccess = await cerrarSesion();
    
    failureOrSuccess.fold(
      (failure) => emit(AuthError(_mapFailureToMessage(failure))),
      (_) => emit(Unauthenticated()), // Cortamos la corriente al panel principal
    );
  }

  Future<void> _onRegistrarUsuario(RegistrarUsuarioEvent event, Emitter<AuthState> emit) async {
    // 1. Encendemos la baliza amarilla (Enclavamiento de seguridad en la HMI)
    emit(AuthLoading());

    // 2. Transmisión de datos al Dominio (El UseCase hace el trabajo pesado)
    final result = await registrarUsuarioUseCase(
      nombre: event.nombre,
      email: event.email,
      password: event.password,
      segmento: event.segmento,
      rol: event.rol,
    );

    // 3. Resolución de la maniobra
    result.fold(
      // 🛑 FALLA: Se disparan los relés de protección
      (failure) => emit(AuthError(_mapFailureToMessage(failure))),
      
      // ✅ ÉXITO: Alta confirmada en Firebase
      (_) => emit(const AuthRegistrationSuccess('Operario dado de alta y sincronizado exitosamente.')),
    );
  }

  // ============================================================================
  // ⚙️ MOTOR DE ARRANQUE DE COMUNICACIONES (Aislado del flujo de la UI)
  // ============================================================================
  Future<void> _energizarComunicacionesFCM(String uid) async {
    try {
      // 1. Encendemos el módulo (Pide permisos al SO y levanta el listener del SnackBar)
      await NotificationService.inicializar();
      
      // 2. Enclavamos el token criptográfico en Firestore
      await NotificationService.registrarToken(uid);
    } catch (e) {
      // La falla de telecomunicaciones no debe tumbar la sesión del usuario principal
      print('💥 [AuthBloc] Cortocircuito en subrutina FCM: $e');
    }
  }
}