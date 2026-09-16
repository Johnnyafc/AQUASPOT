import 'dart:typed_data';
import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../repositories/inventario_repository.dart';

class CargarStockDesdeExcelUseCase {
  final InventarioRepository repository;

  CargarStockDesdeExcelUseCase(this.repository);

  Future<Either<Failure, int>> call(Uint8List bytes) async {
    return await repository.cargarStockDesdeExcel(bytes);
  }
}
