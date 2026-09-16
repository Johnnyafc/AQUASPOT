// lib/features/catalogo/presentation/bloc/catalogo_state.dart
import 'package:equatable/equatable.dart';
import '../../domain/entities/actividad_catalogo_entity.dart';

abstract class CatalogoState extends Equatable {
  const CatalogoState();

  @override
  List<Object?> get props => [];
}

class CatalogoInitial extends CatalogoState {}

class CatalogoLoading extends CatalogoState {}

class CatalogoLoaded extends CatalogoState {
  final List<ActividadCatalogoEntity> actividades;
  final String equipo;

  const CatalogoLoaded({required this.actividades, required this.equipo});

  @override
  List<Object?> get props => [actividades, equipo];
}

class CatalogoOperacionSuccess extends CatalogoState {
  final String mensaje;
  final String equipo;

  const CatalogoOperacionSuccess({required this.mensaje, required this.equipo});

  @override
  List<Object?> get props => [mensaje, equipo];
}

class CatalogoError extends CatalogoState {
  final String mensaje;
  const CatalogoError(this.mensaje);

  @override
  List<Object?> get props => [mensaje];
}
