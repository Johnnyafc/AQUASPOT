import 'dart:typed_data';
import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/item_inventario_entity.dart';

abstract class InventarioRepository {
  Future<Either<Failure, int>> cargarStockDesdeExcel(Uint8List bytes);
  Future<Either<Failure, List<ItemInventarioEntity>>> obtenerStockInventario();
  Future<Either<Failure, Map<String, double>>> consultarStockItems(
      List<String> codigos);
}
