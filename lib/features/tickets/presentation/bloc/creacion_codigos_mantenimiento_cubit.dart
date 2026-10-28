// lib/features/tickets/presentation/bloc/creacion_codigos_mantenimiento_cubit.dart
//
// Costos: guarda los códigos creados para los repuestos SIN CÓDIGO de un
// mantenimiento interno (RegistrarCodigosMantenimientoUseCase).

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/services/creacion_codigos_mantenimiento_service.dart';
import '../../domain/usecases/registrar_codigos_mantenimiento_usecase.dart';

enum EnvioCodigosMantenimiento { editando, enviando, guardado, error }

class CreacionCodigosMantenimientoState extends Equatable {
  final EnvioCodigosMantenimiento envio;
  final String mensaje;

  const CreacionCodigosMantenimientoState({this.envio = EnvioCodigosMantenimiento.editando, this.mensaje = ''});

  @override
  List<Object?> get props => [envio, mensaje];
}

class CreacionCodigosMantenimientoCubit extends Cubit<CreacionCodigosMantenimientoState> {
  final RegistrarCodigosMantenimientoUseCase registrar;

  CreacionCodigosMantenimientoCubit({required this.registrar}) : super(const CreacionCodigosMantenimientoState());

  Future<void> guardar({
    required String ticketId,
    required List<CodigoCreadoMantenimiento> codigos,
    required String usuarioNombre,
    required String usuarioRol,
  }) async {
    emit(const CreacionCodigosMantenimientoState(envio: EnvioCodigosMantenimiento.enviando));
    final r = await registrar(
      ticketId: ticketId,
      codigos: codigos,
      usuarioNombre: usuarioNombre,
      usuarioRol: usuarioRol,
    );
    if (isClosed) return;
    r.fold(
      (f) => emit(CreacionCodigosMantenimientoState(envio: EnvioCodigosMantenimiento.error, mensaje: f.message)),
      (t) => emit(CreacionCodigosMantenimientoState(
        envio: EnvioCodigosMantenimiento.guardado,
        mensaje: 'Códigos de ${t.id} guardados. Los repuestos pasan a Compras.',
      )),
    );
  }
}
