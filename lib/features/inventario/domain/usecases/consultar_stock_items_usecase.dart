import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../repositories/inventario_repository.dart';

class ConsultarStockItemsUseCase {
  final InventarioRepository repository;

  ConsultarStockItemsUseCase(this.repository);

  Future<Either<Failure, Map<String, double>>> call(List<String> codigos) async {
    return await repository.consultarStockItems(codigos);
  }
}
