import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/item_inventario_entity.dart';
import '../repositories/inventario_repository.dart';

class ObtenerStockInventarioUseCase {
  final InventarioRepository repository;

  ObtenerStockInventarioUseCase(this.repository);

  Future<Either<Failure, List<ItemInventarioEntity>>> call() async {
    return await repository.obtenerStockInventario();
  }
}
