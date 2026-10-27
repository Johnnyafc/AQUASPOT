// lib/features/tickets/presentation/bloc/evaluacion_mantenimiento_cubit.dart
//
// Estado de la EVALUACIÓN TÉCNICA de un mantenimiento interno. Las reglas
// (repuestos en una sola lista, consolidado, validación, paso a Compras)
// están en EvaluacionMantenimientoService; aquí solo se guarda lo que el
// técnico arma y se orquesta el envío: subir fotos → guardar evaluación.

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/enum/rol_usuario.dart';
import '../../../catalogo/domain/entities/actividad_catalogo_entity.dart';
import '../../../catalogo/domain/usecases/catalogo_usecases.dart';
import '../../../inventario/domain/entities/item_inventario_entity.dart';
import '../../../inventario/domain/usecases/obtener_stock_inventario_usecase.dart';
import '../../domain/entities/actividad_mantenimiento.dart';
import '../../domain/entities/archivo_adjunto.dart';
import '../../domain/entities/ticket_entity.dart';
import '../../domain/services/evaluacion_mantenimiento_service.dart';
import '../../domain/usecases/guardar_evaluacion_mantenimiento_usecase.dart';
import '../../domain/usecases/subir_archivo_adjunto_usecase.dart';

typedef _S = EvaluacionMantenimientoService;

enum CargaEvaluacionMantenimiento { cargando, lista, error }

enum EnvioEvaluacionMantenimiento { editando, enviando, guardada, error }

class EvaluacionMantenimientoState extends Equatable {
  final TicketEntity? ticket;
  final CargaEvaluacionMantenimiento carga;
  final List<ActividadCatalogoEntity> catalogo;
  final List<ItemInventarioEntity> inventario;
  final List<ActividadMantenimiento> actividades;
  final bool necesitaCompras;
  final String motivoNoCompras;
  final EnvioEvaluacionMantenimiento envio;
  final String mensaje;
  final List<String> errores;

  const EvaluacionMantenimientoState({
    this.ticket,
    this.carga = CargaEvaluacionMantenimiento.cargando,
    this.catalogo = const [],
    this.inventario = const [],
    this.actividades = const [],
    this.necesitaCompras = true,
    this.motivoNoCompras = '',
    this.envio = EnvioEvaluacionMantenimiento.editando,
    this.mensaje = '',
    this.errores = const [],
  });

  EvaluacionMantenimientoState copyWith({
    TicketEntity? ticket,
    CargaEvaluacionMantenimiento? carga,
    List<ActividadCatalogoEntity>? catalogo,
    List<ItemInventarioEntity>? inventario,
    List<ActividadMantenimiento>? actividades,
    bool? necesitaCompras,
    String? motivoNoCompras,
    EnvioEvaluacionMantenimiento? envio,
    String? mensaje,
    List<String>? errores,
  }) {
    return EvaluacionMantenimientoState(
      ticket: ticket ?? this.ticket,
      carga: carga ?? this.carga,
      catalogo: catalogo ?? this.catalogo,
      inventario: inventario ?? this.inventario,
      actividades: actividades ?? this.actividades,
      necesitaCompras: necesitaCompras ?? this.necesitaCompras,
      motivoNoCompras: motivoNoCompras ?? this.motivoNoCompras,
      envio: envio ?? this.envio,
      mensaje: mensaje ?? this.mensaje,
      errores: errores ?? this.errores,
    );
  }

  @override
  List<Object?> get props => [ticket?.id, carga, catalogo, inventario.length, actividades, necesitaCompras,
        motivoNoCompras, envio, mensaje, errores];
}

class EvaluacionMantenimientoCubit extends Cubit<EvaluacionMantenimientoState> {
  final ObtenerActividadesPorEquipoUseCase obtenerActividades;
  final ObtenerStockInventarioUseCase obtenerInventario;
  final SubirArchivoAdjuntoUseCase subirArchivo;
  final GuardarEvaluacionMantenimientoUseCase guardarEvaluacion;

  EvaluacionMantenimientoCubit({
    required this.obtenerActividades,
    required this.obtenerInventario,
    required this.subirArchivo,
    required this.guardarEvaluacion,
  }) : super(const EvaluacionMantenimientoState());

  /// Carga el Plan Maestro del equipo y el inventario registrado.
  Future<void> cargar(TicketEntity ticket) async {
    emit(state.copyWith(ticket: ticket, carga: CargaEvaluacionMantenimiento.cargando));
    final equipo = _S.equipoCatalogo(ticket);
    final catalogo = equipo == null ? null : await obtenerActividades(equipo);
    final inventario = await obtenerInventario();
    final fallo = [
      if (catalogo != null) catalogo.fold((f) => 'Plan Maestro: ${f.message}', (_) => null),
      inventario.fold((f) => 'Inventario: ${f.message}', (_) => null),
    ].whereType<String>();
    emit(state.copyWith(
      carga: fallo.isEmpty ? CargaEvaluacionMantenimiento.lista : CargaEvaluacionMantenimiento.error,
      mensaje: fallo.join('\n'),
      catalogo: catalogo?.getOrElse(() => const []) ?? const [],
      inventario: inventario.getOrElse(() => const []),
    ));
  }

  void _actividades(List<ActividadMantenimiento> lista) => emit(state.copyWith(actividades: lista, errores: const []));

  void _cambiar(int i, ActividadMantenimiento Function(ActividadMantenimiento a) f) =>
      _actividades([...state.actividades]..[i] = f(state.actividades[i]));

  // ------------------------------------------------------------ Actividades
  void agregarActividad(ActividadCatalogoEntity a) => _actividades([...state.actividades, _S.desdeCatalogo(a)]);
  void quitarActividad(int i) => _actividades([...state.actividades]..removeAt(i));
  void cambiarHoras(int i, double? horas) => _cambiar(i, (a) => a.copyWith(horasHombre: horas ?? 0));
  void cambiarObservacion(int i, String texto) => _cambiar(i, (a) => a.copyWith(observacion: texto));
  void agregarFotos(int i, List<ArchivoAdjunto> fotos) => _cambiar(i, (a) => a.copyWith(fotos: [...a.fotos, ...fotos]));
  void quitarFoto(int i, int j) => _cambiar(i, (a) => a.copyWith(fotos: [...a.fotos]..removeAt(j)));

  // ------------------------------------------------------------ Repuestos
  void agregarRepuesto(int i, ItemInventarioEntity item) => _cambiar(i, (a) => _S.agregarRepuesto(a, item));
  void cambiarCantidad(int i, int j, double cantidad) => _cambiar(i, (a) => _S.cambiarCantidad(a, j, cantidad));
  void quitarRepuesto(int i, int j) => _cambiar(i, (a) => _S.quitarRepuesto(a, j));

  // ------------------------------------------------------------ Compras
  void cambiarNecesitaCompras(bool v) => emit(state.copyWith(necesitaCompras: v));
  void cambiarMotivoNoCompras(String texto) => emit(state.copyWith(motivoNoCompras: texto));

  /// Valida, sube las fotos de cada actividad y guarda la evaluación.
  Future<void> enviar({required String usuarioNombre, required RolUsuario rol}) async {
    final ticket = state.ticket;
    if (ticket == null) return;
    final errores = _S.validar(state.actividades);
    if (errores.isNotEmpty) {
      emit(state.copyWith(errores: errores));
      return;
    }
    emit(state.copyWith(envio: EnvioEvaluacionMantenimiento.enviando, mensaje: 'Guardando evaluación...', errores: const []));

    // Cada foto subida pasa de "fotos" a "fotosUrls" en el estado: si algo
    // falla, un reintento solo sube lo que falta.
    final total = state.actividades.fold<int>(0, (s, a) => s + a.fotos.length);
    var subidas = 0;
    for (var i = 0; i < state.actividades.length; i++) {
      while (state.actividades[i].fotos.isNotEmpty) {
        final act = state.actividades[i];
        final foto = act.fotos.first;
        emit(state.copyWith(mensaje: 'Subiendo fotos (${subidas + 1}/$total)...'));
        final r = await subirArchivo(foto, ticket.id, carpeta: 'evaluaciones/actividades');
        final url = r.fold((_) => null, (u) => u);
        if (url == null) {
          emit(state.copyWith(
            envio: EnvioEvaluacionMantenimiento.error,
            mensaje: 'No se pudo subir la foto "${foto.nombre}": ${r.fold((f) => f.message, (_) => '')}',
          ));
          return;
        }
        final lista = [...state.actividades]
          ..[i] = act.copyWith(fotos: act.fotos.sublist(1), fotosUrls: [...act.fotosUrls, url]);
        emit(state.copyWith(actividades: lista));
        subidas++;
      }
    }
    final actividades = state.actividades;

    emit(state.copyWith(mensaje: 'Guardando evaluación...'));
    final r = await guardarEvaluacion(
      ticket,
      actividades,
      necesitaCompras: state.necesitaCompras,
      motivoNoCompras: state.motivoNoCompras,
      usuarioNombre: usuarioNombre,
      rol: rol,
    );
    r.fold(
      (f) => emit(state.copyWith(
        envio: EnvioEvaluacionMantenimiento.error,
        mensaje: 'No se pudo guardar la evaluación: ${f.message}',
      )),
      (_) => emit(state.copyWith(
        envio: EnvioEvaluacionMantenimiento.guardada,
        mensaje: 'Evaluación de ${ticket.id} guardada. Pasa a Compras.',
      )),
    );
  }
}
