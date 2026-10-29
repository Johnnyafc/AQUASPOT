// lib/features/tickets/data/repositories/catalogo_activos_mantenimiento_repository_impl.dart

import 'package:dartz/dartz.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/repositories/catalogo_activos_mantenimiento_repository.dart';
import '../datasources/catalogo_activos_mantenimiento_remote_datasource.dart';

class CatalogoActivosMantenimientoRepositoryImpl implements ICatalogoActivosMantenimientoRepository {
  final CatalogoActivosMantenimientoRemoteDataSource dataSource;

  CatalogoActivosMantenimientoRepositoryImpl({required this.dataSource});

  @override
  Future<Either<Failure, Map<String, List<String>>>> obtener() async {
    try {
      return Right(await dataSource.obtener());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }
}
