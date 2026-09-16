// lib/features/catalogo/data/repositories/catalogo_repository_impl.dart
import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/actividad_catalogo_entity.dart';
import '../../domain/repositories/catalogo_repository.dart';
import '../datasources/catalogo_remote_datasource.dart';
import '../models/actividad_catalogo_model.dart';

class CatalogoRepositoryImpl implements CatalogoRepository {
  final CatalogoRemoteDataSource remoteDataSource;

  CatalogoRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, List<ActividadCatalogoEntity>>> obtenerActividadesPorEquipo(String equipo) async {
    try {
      final resultado = await remoteDataSource.obtenerActividadesPorEquipo(equipo);
      return Right(resultado);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> guardarActividad(ActividadCatalogoEntity actividad) async {
    try {
      final model = ActividadCatalogoModel.fromEntity(actividad);
      await remoteDataSource.guardarActividad(model);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> eliminarActividad(String id) async {
    try {
      await remoteDataSource.eliminarActividad(id);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> cargarCatalogoInicial(List<ActividadCatalogoEntity> actividades) async {
    try {
      final models = actividades.map((e) => ActividadCatalogoModel.fromEntity(e)).toList();
      await remoteDataSource.cargarCatalogoInicial(models);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
