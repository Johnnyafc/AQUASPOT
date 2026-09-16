import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/usecases/actualizar_cliente_usecase.dart';
import '../../domain/usecases/obtener_todos_clientes_usecase.dart';
import '../../domain/usecases/registrar_cliente_usecase.dart';
import 'cliente_event.dart';
import 'cliente_state.dart';

class ClienteBloc extends Bloc<ClienteEvent, ClienteState> {
  final RegistrarClienteUseCase registrarClienteUseCase;
  final ObtenerTodosClientesUseCase obtenerTodosClientesUseCase;
  final ActualizarClienteUseCase actualizarClienteUseCase;

  ClienteBloc({
    required this.registrarClienteUseCase,
    required this.obtenerTodosClientesUseCase,
    required this.actualizarClienteUseCase,
  }) : super(ClienteInitial()) {
    on<RegistrarClienteSubmitEvent>(_onRegistrarClienteSubmit);
    on<CargarClientesEvent>(_onCargarClientes);
    on<ActualizarClienteSubmitEvent>(_onActualizarClienteSubmit);
  }

  Future<void> _onRegistrarClienteSubmit(
    RegistrarClienteSubmitEvent event,
    Emitter<ClienteState> emit,
  ) async {
    // 1. Encendemos baliza de carga
    emit(ClienteLoading());

    // 2. Ejecutamos el caso de uso
    final result = await registrarClienteUseCase(
      camaronera: event.camaronera,
      celular: event.celular,
      direccion: event.direccion,
      emailContacto: event.emailContacto,
      nombreContacto: event.nombreContacto,
      subSector: event.subSector,
    );

    // 3. Evaluamos la respuesta del relé
    result.fold(
      (failure) => emit(ClienteError(failure.message)),
      (_) => emit(ClienteSuccess()),
    );
  }

  Future<void> _onCargarClientes(
    CargarClientesEvent event,
    Emitter<ClienteState> emit,
  ) async {
    emit(ClienteLoading());
    final result = await obtenerTodosClientesUseCase();
    result.fold(
      (failure) => emit(ClienteError(failure.message)),
      (clientes) => emit(ClientesLoaded(clientes)),
    );
  }

  Future<void> _onActualizarClienteSubmit(
    ActualizarClienteSubmitEvent event,
    Emitter<ClienteState> emit,
  ) async {
    emit(ClienteLoading());
    final result = await actualizarClienteUseCase(event.cliente);
    result.fold(
      (failure) => emit(ClienteError(failure.message)),
      (_) => emit(ClienteActualizadoSuccess()),
    );
  }
}