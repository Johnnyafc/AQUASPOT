// lib/features/plan_preventivo/data/repositories/plan_preventivo_repository_impl.dart

import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../../tickets/domain/entities/mantenimiento_interno_entity.dart';
import '../../domain/entities/actividad_preventiva_entity.dart';
import '../../domain/repositories/plan_preventivo_repository.dart';
import '../datasources/plan_preventivo_remote_datasource.dart';

class PlanPreventivoRepositoryImpl implements PlanPreventivoRepository {
  final PlanPreventivoRemoteDataSource remoteDataSource;

  PlanPreventivoRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, List<ActividadPreventivaEntity>>> obtenerPorMaquina(TipoActivoMantenimiento tipo) async {
    try {
      return Right(await remoteDataSource.obtenerPorMaquina(tipo));
    } catch (e) {
      return Left(ServerFailure('No se pudo cargar el Plan Preventivo: $e'));
    }
  }

  @override
  Future<Either<Failure, ActividadPreventivaEntity>> guardar(ActividadPreventivaEntity actividad) async {
    try {
      return Right(await remoteDataSource.guardar(actividad));
    } catch (e) {
      return Left(ServerFailure('No se pudo guardar la actividad preventiva: ${e.toString().replaceFirst('Exception: ', '')}'));
    }
  }

  @override
  Future<Either<Failure, void>> desactivar(String id, {required String usuarioNombre}) async {
    try {
      await remoteDataSource.desactivar(id, usuarioNombre: usuarioNombre);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure('No se pudo desactivar la actividad preventiva: $e'));
    }
  }
}
