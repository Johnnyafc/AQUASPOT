// lib/features/catalogo/domain/repositories/catalogo_repository.dart
import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/actividad_catalogo_entity.dart';

abstract class CatalogoRepository {
  Future<Either<Failure, List<ActividadCatalogoEntity>>> obtenerActividadesPorEquipo(String equipo);
  Future<Either<Failure, void>> guardarActividad(ActividadCatalogoEntity actividad);
  Future<Either<Failure, void>> eliminarActividad(String id);
  Future<Either<Failure, void>> cargarCatalogoInicial(List<ActividadCatalogoEntity> actividades);
}
