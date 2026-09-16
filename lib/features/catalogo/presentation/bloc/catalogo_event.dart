// lib/features/catalogo/presentation/bloc/catalogo_event.dart
import 'package:equatable/equatable.dart';
import '../../domain/entities/actividad_catalogo_entity.dart';

abstract class CatalogoEvent extends Equatable {
  const CatalogoEvent();

  @override
  List<Object?> get props => [];
}

class CargarCatalogoPorEquipoEvent extends CatalogoEvent {
  final String equipo;
  const CargarCatalogoPorEquipoEvent(this.equipo);

  @override
  List<Object?> get props => [equipo];
}

class GuardarActividadEvent extends CatalogoEvent {
  final ActividadCatalogoEntity actividad;
  const GuardarActividadEvent(this.actividad);

  @override
  List<Object?> get props => [actividad];
}

class EliminarActividadEvent extends CatalogoEvent {
  final String id;
  final String equipo;
  const EliminarActividadEvent({required this.id, required this.equipo});

  @override
  List<Object?> get props => [id, equipo];
}

class CargarCatalogoInicialSeedEvent extends CatalogoEvent {
  final List<ActividadCatalogoEntity> actividades;
  final String equipo;
  const CargarCatalogoInicialSeedEvent({required this.actividades, required this.equipo});

  @override
  List<Object?> get props => [actividades, equipo];
}
