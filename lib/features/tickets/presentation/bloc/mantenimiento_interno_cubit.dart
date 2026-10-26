// lib/features/tickets/presentation/bloc/mantenimiento_interno_cubit.dart
//
// Estado del formulario de MANTENIMIENTO INTERNO (Crear Ticket). Las reglas
// (campos por máquina, tipo de mantenimiento por rol, validaciones) están
// en FormularioMantenimientoService; aquí solo se guarda lo que el usuario
// llena y se orquesta el envío: crear el ticket → subir fotos → adjuntarlas.

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/enum/rol_usuario.dart';
import '../../domain/entities/mantenimiento_interno_entity.dart';
import '../../domain/services/formulario_mantenimiento_service.dart';
import '../../domain/usecases/adjuntar_evidencias_mantenimiento_usecase.dart';
import '../../domain/usecases/crear_mantenimiento_interno_usecase.dart';
import '../../domain/usecases/subir_evidencia_usecase.dart';

enum EstadoEnvioMantenimiento { editando, enviando, creado, error }

class MantenimientoInternoState extends Equatable {
  final DatosMantenimientoInterno datos;
  final List<XFile> fotos;
  final EstadoEnvioMantenimiento envio;
  final String mensaje;
  final List<String> errores;
  final String? ticketCreadoId;

  const MantenimientoInternoState({
    this.datos = const DatosMantenimientoInterno(),
    this.fotos = const [],
    this.envio = EstadoEnvioMantenimiento.editando,
    this.mensaje = '',
    this.errores = const [],
    this.ticketCreadoId,
  });

  MantenimientoInternoState copyWith({
    DatosMantenimientoInterno? datos,
    List<XFile>? fotos,
    EstadoEnvioMantenimiento? envio,
    String? mensaje,
    List<String>? errores,
    String? ticketCreadoId,
  }) {
    return MantenimientoInternoState(
      datos: datos ?? this.datos,
      fotos: fotos ?? this.fotos,
      envio: envio ?? this.envio,
      mensaje: mensaje ?? this.mensaje,
      errores: errores ?? this.errores,
      ticketCreadoId: ticketCreadoId ?? this.ticketCreadoId,
    );
  }

  @override
  List<Object?> get props => [datos.tipoMantenimiento, datos.tipoActivo, datos.serieOPlaca, datos.horometro,
        datos.kilometraje, datos.fechaHora, datos.detalle, fotos, envio, mensaje, errores, ticketCreadoId];
}

class MantenimientoInternoCubit extends Cubit<MantenimientoInternoState> {
  final CrearMantenimientoInternoUseCase crearMantenimiento;
  final SubirEvidenciaUseCase subirEvidencia;
  final AdjuntarEvidenciasMantenimientoUseCase adjuntarEvidencias;

  MantenimientoInternoCubit({
    required this.crearMantenimiento,
    required this.subirEvidencia,
    required this.adjuntarEvidencias,
  }) : super(MantenimientoInternoState(datos: DatosMantenimientoInterno(fechaHora: DateTime.now())));

  void _datos(DatosMantenimientoInterno d) => emit(state.copyWith(datos: d, errores: const []));

  void elegirTipoMantenimiento(TipoMantenimiento t) => _datos(state.datos.copyWith(tipoMantenimiento: t));
  void elegirTipoActivo(TipoActivoMantenimiento t) =>
      _datos(FormularioMantenimientoService.cambiarTipoActivo(state.datos, t));
  void elegirSerieOPlaca(String valor) => _datos(state.datos.copyWith(serieOPlaca: valor));
  void cambiarHorometro(double? v) =>
      _datos(v == null ? state.datos.copyWith(limpiarHorometro: true) : state.datos.copyWith(horometro: v));
  void cambiarKilometraje(double? v) =>
      _datos(v == null ? state.datos.copyWith(limpiarKilometraje: true) : state.datos.copyWith(kilometraje: v));
  void cambiarFechaHora(DateTime f) => _datos(state.datos.copyWith(fechaHora: f));
  void cambiarDetalle(String texto) => _datos(state.datos.copyWith(detalle: texto));

  void agregarFotos(List<XFile> nuevas) {
    final fotos = [...state.fotos, ...nuevas];
    emit(state.copyWith(fotos: fotos, datos: state.datos.copyWith(cantidadFotos: fotos.length), errores: const []));
  }

  void quitarFoto(int index) {
    final fotos = [...state.fotos]..removeAt(index);
    emit(state.copyWith(fotos: fotos, datos: state.datos.copyWith(cantidadFotos: fotos.length)));
  }

  /// Crea el ticket, sube las fotos y las adjunta. Si una foto falla, el
  /// ticket ya quedó creado: se avisa cuál y con qué número.
  Future<void> enviar({required String usuarioNombre, required RolUsuario rol}) async {
    final errores = FormularioMantenimientoService.validar(state.datos, rol: rol, ahora: DateTime.now());
    if (errores.isNotEmpty) {
      emit(state.copyWith(errores: errores, envio: EstadoEnvioMantenimiento.editando));
      return;
    }
    emit(state.copyWith(envio: EstadoEnvioMantenimiento.enviando, mensaje: 'Creando requerimiento...', errores: const []));

    final creado = await crearMantenimiento(state.datos, usuarioNombre: usuarioNombre, rol: rol);
    final ticket = creado.fold((_) => null, (t) => t);
    if (ticket == null) {
      final msg = creado.fold((f) => f.message, (_) => '');
      emit(state.copyWith(envio: EstadoEnvioMantenimiento.error, mensaje: 'No se pudo crear el requerimiento: $msg'));
      return;
    }

    final urls = <String>[];
    for (final foto in state.fotos) {
      emit(state.copyWith(mensaje: 'Subiendo fotos a ${ticket.id} (${urls.length + 1}/${state.fotos.length})...'));
      final r = await subirEvidencia(foto, ticket.id);
      final url = r.fold((_) => null, (u) => u);
      if (url == null) {
        final msg = r.fold((f) => f.message, (_) => '');
        emit(state.copyWith(
          envio: EstadoEnvioMantenimiento.error,
          ticketCreadoId: ticket.id,
          mensaje: 'El requerimiento ${ticket.id} se creó, pero no se pudo subir la foto "${foto.name}": $msg',
        ));
        return;
      }
      urls.add(url);
    }

    final adjunto = await adjuntarEvidencias(ticket, urls);
    adjunto.fold(
      (f) => emit(state.copyWith(
        envio: EstadoEnvioMantenimiento.error,
        ticketCreadoId: ticket.id,
        mensaje: 'El requerimiento ${ticket.id} se creó, pero no se pudieron guardar las fotos: ${f.message}',
      )),
      (_) => emit(state.copyWith(
        envio: EstadoEnvioMantenimiento.creado,
        ticketCreadoId: ticket.id,
        mensaje: 'Requerimiento ${ticket.id} creado',
      )),
    );
  }
}
