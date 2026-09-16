// lib/features/inventario/data/datasources/inventario_remote_datasource.dart
import '../models/item_inventario_model.dart';

abstract class InventarioRemoteDataSource {
  Future<int> guardarLoteInventario(List<ItemInventarioModel> items);
  Future<List<ItemInventarioModel>> obtenerTodos();
  Stream<List<ItemInventarioModel>> escucharInventario();
  Future<Map<String, ItemInventarioModel>> consultarPorCodigos(List<String> codigos);
}
