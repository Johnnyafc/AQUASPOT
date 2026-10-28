// lib/features/plan_preventivo/presentation/bloc/plan_preventivo_cubit.dart
//
// Estado de la página PLAN PREVENTIVO: máquina elegida, sus actividades
// (todas, también las desactivadas, para los códigos), el inventario para
// elegir repuestos y el guardado. Las reglas están en PlanPreventivoService.

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/enum/rol_usuario.dart';
import '../../../inventario/domain/entities/item_inventario_entity.dart';
import '../../../inventario/domain/usecases/obtener_stock_inventario_usecase.dart';
import '../../../tickets/domain/entities/mantenimiento_interno_entity.dart';
import '../../domain/entities/actividad_preventiva_entity.dart';
import '../../domain/services/plan_preventivo_service.dart';
import '../../domain/usecases/plan_preventivo_usecases.dart';

enum CargaPlanPreventivo { cargando, lista, error }

class PlanPreventivoState extends Equatable {
  final TipoActivoMantenimiento tipo;
  final CargaPlanPreventivo carga;
  final List<ActividadPreventivaEntity> todas; // de la máquina elegida
  final List<ItemInventarioEntity> inventario;
  final String busqueda;
  final bool guardando;
  final String mensaje; // último resultado (éxito o error)
  final bool mensajeEsError;

  const PlanPreventivoState({
    this.tipo = TipoActivoMantenimiento.cosechadora,
    this.carga = CargaPlanPreventivo.cargando,
    this.todas = const [],
    this.inventario = const [],
    this.busqueda = '',
    this.guardando = false,
    this.mensaje = '',
    this.mensajeEsError = false,
  });

  /// Activas de la máquina que coinciden con la búsqueda.
  List<ActividadPreventivaEntity> get visibles =>
      PlanPreventivoService.buscar(PlanPreventivoService.activasDe(todas, tipo), busqueda);

  PlanPreventivoState copyWith({
    TipoActivoMantenimiento? tipo,
    CargaPlanPreventivo? carga,
    List<ActividadPreventivaEntity>? todas,
    List<ItemInventarioEntity>? inventario,
    String? busqueda,
    bool? guardando,
    String? mensaje,
    bool? mensajeEsError,
  }) {
    return PlanPreventivoState(
      tipo: tipo ?? this.tipo,
      carga: carga ?? this.carga,
      todas: todas ?? this.todas,
      inventario: inventario ?? this.inventario,
      busqueda: busqueda ?? this.busqueda,
      guardando: guardando ?? this.guardando,
      mensaje: mensaje ?? this.mensaje,
      mensajeEsError: mensajeEsError ?? this.mensajeEsError,
    );
  }

  @override
  List<Object?> get props => [tipo, carga, todas, inventario.length, busqueda, guardando, mensaje, mensajeEsError];
}

class PlanPreventivoCubit extends Cubit<PlanPreventivoState> {
  final ObtenerPlanPreventivoUseCase obtenerPlan;
  final GuardarActividadPreventivaUseCase guardarActividad;
  final DesactivarActividadPreventivaUseCase desactivarActividad;
  final ObtenerStockInventarioUseCase obtenerInventario;

  PlanPreventivoCubit({
    required this.obtenerPlan,
    required this.guardarActividad,
    required this.desactivarActividad,
    required this.obtenerInventario,
  }) : super(const PlanPreventivoState());

  /// Primera carga: inventario y el plan de la máquina inicial.
  Future<void> iniciar() async {
    final inv = await obtenerInventario();
    if (isClosed) return;
    emit(state.copyWith(inventario: inv.getOrElse(() => const [])));
    await elegirMaquina(state.tipo, forzar: true);
  }

  Future<void> elegirMaquina(TipoActivoMantenimiento tipo, {bool forzar = false}) async {
    if (tipo == state.tipo && !forzar) return;
    emit(state.copyWith(tipo: tipo, carga: CargaPlanPreventivo.cargando, todas: const [], mensaje: ''));
    final r = await obtenerPlan(tipo);
    if (isClosed || state.tipo != tipo) return; // salió o ya cambió de máquina
    r.fold(
      (f) => emit(state.copyWith(carga: CargaPlanPreventivo.error, mensaje: f.message, mensajeEsError: true)),
      (lista) => emit(state.copyWith(carga: CargaPlanPreventivo.lista, todas: lista)),
    );
  }

  void buscar(String texto) => emit(state.copyWith(busqueda: texto));

  /// Actividad nueva (vacía) con el siguiente código de la máquina.
  ActividadPreventivaEntity nueva() => PlanPreventivoService.nueva(state.todas, state.tipo);

  /// Guarda y refresca la lista. true si se guardó.
  Future<bool> guardar(ActividadPreventivaEntity a, {required String usuarioNombre, required RolUsuario rol}) async {
    emit(state.copyWith(guardando: true, mensaje: ''));
    final r = await guardarActividad(a, usuarioNombre: usuarioNombre, rol: rol);
    if (isClosed) return r.isRight();
    return r.fold(
      (f) {
        emit(state.copyWith(guardando: false, mensaje: f.message, mensajeEsError: true));
        // Nueva que chocó con otra: se recarga la lista para que el
        // siguiente código salga bien.
        if (a.id.isEmpty) _recargar();
        return false;
      },
      (guardada) {
        final todas = [
          for (final x in state.todas)
            if (x.id != guardada.id) x,
          guardada,
        ]..sort((x, y) => x.codigo.compareTo(y.codigo));
        emit(state.copyWith(
          guardando: false,
          todas: todas,
          mensaje: '${guardada.codigo} guardada.',
          mensajeEsError: false,
        ));
        return true;
      },
    );
  }

  /// true si se desactivó.
  Future<bool> desactivar(ActividadPreventivaEntity a, {required String usuarioNombre, required RolUsuario rol}) async {
    emit(state.copyWith(guardando: true, mensaje: ''));
    final r = await desactivarActividad(a, usuarioNombre: usuarioNombre, rol: rol);
    if (isClosed) return r.isRight();
    r.fold(
      (f) => emit(state.copyWith(guardando: false, mensaje: f.message, mensajeEsError: true)),
      (_) => emit(state.copyWith(
        guardando: false,
        todas: [
          for (final x in state.todas) x.id == a.id ? x.copyWith(activo: false) : x,
        ],
        mensaje: '${a.codigo} desactivada.',
        mensajeEsError: false,
      )),
    );
    return r.isRight();
  }

  Future<void> _recargar() async {
    final tipo = state.tipo;
    final r = await obtenerPlan(tipo);
    if (isClosed || state.tipo != tipo) return;
    r.fold((_) {}, (lista) => emit(state.copyWith(todas: lista)));
  }
}
