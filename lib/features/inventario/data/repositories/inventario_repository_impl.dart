import 'dart:typed_data';
import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/errors/exceptions.dart';
import '../../domain/entities/item_inventario_entity.dart';
import '../../domain/repositories/inventario_repository.dart';
import '../datasources/inventario_remote_datasource.dart';
import '../services/parser_excel_stock_service.dart';

class InventarioRepositoryImpl implements InventarioRepository {
  final InventarioRemoteDataSource remoteDataSource;

  InventarioRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, int>> cargarStockDesdeExcel(Uint8List bytes) async {
    try {
      final items = ParserExcelStockService.parsearExcelOBytes(bytes);
      if (items.isEmpty) {
        return const Left(ServerFailure('No se encontraron ítems válidos en el archivo'));
      }
      final guardados = await remoteDataSource.guardarLoteInventario(items);
      return Right(guardados);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<ItemInventarioEntity>>> obtenerStockInventario() async {
    try {
      final items = await remoteDataSource.obtenerTodos();
      return Right(items);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Map<String, double>>> consultarStockItems(
      List<String> codigos) async {
    try {
      final modelMap = await remoteDataSource.consultarPorCodigos(codigos);
      final stockMap = modelMap.map((key, val) => MapEntry(key, val.stockDisponible));
      return Right(stockMap);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
