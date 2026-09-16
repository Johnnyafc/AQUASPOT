// lib/features/catalogo/domain/usecases/catalogo_usecases.dart
import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/actividad_catalogo_entity.dart';
import '../repositories/catalogo_repository.dart';

class ObtenerActividadesPorEquipoUseCase {
  final CatalogoRepository repository;
  ObtenerActividadesPorEquipoUseCase(this.repository);

  Future<Either<Failure, List<ActividadCatalogoEntity>>> call(String equipo) {
    return repository.obtenerActividadesPorEquipo(equipo);
  }
}

class GuardarActividadCatalogoUseCase {
  final CatalogoRepository repository;
  GuardarActividadCatalogoUseCase(this.repository);

  Future<Either<Failure, void>> call(ActividadCatalogoEntity actividad) {
    return repository.guardarActividad(actividad);
  }
}

class EliminarActividadCatalogoUseCase {
  final CatalogoRepository repository;
  EliminarActividadCatalogoUseCase(this.repository);

  Future<Either<Failure, void>> call(String id) {
    return repository.eliminarActividad(id);
  }
}

class CargarCatalogoInicialUseCase {
  final CatalogoRepository repository;
  CargarCatalogoInicialUseCase(this.repository);

  Future<Either<Failure, void>> call(List<ActividadCatalogoEntity> actividades) {
    return repository.cargarCatalogoInicial(actividades);
  }
}
