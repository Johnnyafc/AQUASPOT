// lib/features/catalogo/presentation/bloc/catalogo_bloc.dart
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/usecases/catalogo_usecases.dart';
import 'catalogo_event.dart';
import 'catalogo_state.dart';

class CatalogoBloc extends Bloc<CatalogoEvent, CatalogoState> {
  final ObtenerActividadesPorEquipoUseCase obtenerActividadesPorEquipo;
  final GuardarActividadCatalogoUseCase guardarActividadCatalogo;
  final EliminarActividadCatalogoUseCase eliminarActividadCatalogo;
  final CargarCatalogoInicialUseCase cargarCatalogoInicial;

  CatalogoBloc({
    required this.obtenerActividadesPorEquipo,
    required this.guardarActividadCatalogo,
    required this.eliminarActividadCatalogo,
    required this.cargarCatalogoInicial,
  }) : super(CatalogoInitial()) {
    on<CargarCatalogoPorEquipoEvent>(_onCargarCatalogoPorEquipo);
    on<GuardarActividadEvent>(_onGuardarActividad);
    on<EliminarActividadEvent>(_onEliminarActividad);
    on<CargarCatalogoInicialSeedEvent>(_onCargarCatalogoInicialSeed);
  }

  Future<void> _onCargarCatalogoPorEquipo(
    CargarCatalogoPorEquipoEvent event,
    Emitter<CatalogoState> emit,
  ) async {
    emit(CatalogoLoading());
    final result = await obtenerActividadesPorEquipo(event.equipo);
    result.fold(
      (failure) => emit(CatalogoError(failure.message)),
      (actividades) => emit(CatalogoLoaded(actividades: actividades, equipo: event.equipo)),
    );
  }

  Future<void> _onGuardarActividad(
    GuardarActividadEvent event,
    Emitter<CatalogoState> emit,
  ) async {
    emit(CatalogoLoading());
    final result = await guardarActividadCatalogo(event.actividad);
    result.fold(
      (failure) => emit(CatalogoError(failure.message)),
      (_) {
        emit(CatalogoOperacionSuccess(
          mensaje: 'Actividad guardada correctamente',
          equipo: event.actividad.equipo,
        ));
        add(CargarCatalogoPorEquipoEvent(event.actividad.equipo));
      },
    );
  }

  Future<void> _onEliminarActividad(
    EliminarActividadEvent event,
    Emitter<CatalogoState> emit,
  ) async {
    emit(CatalogoLoading());
    final result = await eliminarActividadCatalogo(event.id);
    result.fold(
      (failure) => emit(CatalogoError(failure.message)),
      (_) {
        emit(CatalogoOperacionSuccess(
          mensaje: 'Actividad eliminada del catálogo',
          equipo: event.equipo,
        ));
        add(CargarCatalogoPorEquipoEvent(event.equipo));
      },
    );
  }

  Future<void> _onCargarCatalogoInicialSeed(
    CargarCatalogoInicialSeedEvent event,
    Emitter<CatalogoState> emit,
  ) async {
    emit(CatalogoLoading());
    final result = await cargarCatalogoInicial(event.actividades);
    result.fold(
      (failure) => emit(CatalogoError(failure.message)),
      (_) {
        emit(CatalogoOperacionSuccess(
          mensaje: 'Plan maestro cargado exitosamente',
          equipo: event.equipo,
        ));
        add(CargarCatalogoPorEquipoEvent(event.equipo));
      },
    );
  }
}
