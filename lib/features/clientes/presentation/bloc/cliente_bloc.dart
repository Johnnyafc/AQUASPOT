import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/usecases/registrar_cliente_usecase.dart';
import 'cliente_event.dart';
import 'cliente_state.dart';

class ClienteBloc extends Bloc<ClienteEvent, ClienteState> {
  final RegistrarClienteUseCase registrarClienteUseCase;

  ClienteBloc({required this.registrarClienteUseCase}) : super(ClienteInitial()) {
    on<RegistrarClienteSubmitEvent>(_onRegistrarClienteSubmit);
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
}