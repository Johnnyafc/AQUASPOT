// lib/features/inventario/data/datasources/inventario_remote_datasource_impl.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/errors/exceptions.dart';
import '../models/item_inventario_model.dart';
import 'inventario_remote_datasource.dart';

class InventarioRemoteDataSourceImpl implements InventarioRemoteDataSource {
  final FirebaseFirestore firestore;

  InventarioRemoteDataSourceImpl({required this.firestore});

  CollectionReference<Map<String, dynamic>> get _coleccion =>
      firestore.collection('inventario_bodega');

  @override
  Future<int> guardarLoteInventario(List<ItemInventarioModel> items) async {
    try {
      int procesados = 0;
      // Firestore batch limit is 500
      for (int i = 0; i < items.length; i += 450) {
        final chunk = items.sublist(i, (i + 450 > items.length) ? items.length : i + 450);
        final batch = firestore.batch();

        for (final item in chunk) {
          final docId = item.codigo
              .trim()
              .replaceAll('/', '_')
              .replaceAll('.', '_')
              .replaceAll('#', '_')
              .replaceAll(' ', '_');

          final ref = _coleccion.doc(docId.isNotEmpty ? docId : _coleccion.doc().id);
          batch.set(ref, item.toFirestore(), SetOptions(merge: true));
        }

        await batch.commit();
        procesados += chunk.length;
      }
      return procesados;
    } catch (e) {
      throw ServerException('Falla al guardar inventario en Firestore: $e');
    }
  }

  @override
  Future<List<ItemInventarioModel>> obtenerTodos() async {
    try {
      final snapshot = await _coleccion.get();
      return snapshot.docs
          .map((doc) => ItemInventarioModel.fromFirestore(doc.data()))
          .toList();
    } catch (e) {
      throw ServerException('Error al consultar inventario: $e');
    }
  }

  @override
  Stream<List<ItemInventarioModel>> escucharInventario() {
    return _coleccion.snapshots().map((snapshot) =>
        snapshot.docs.map((d) => ItemInventarioModel.fromFirestore(d.data())).toList());
  }

  @override
  Future<Map<String, ItemInventarioModel>> consultarPorCodigos(List<String> codigos) async {
    try {
      final Map<String, ItemInventarioModel> resultado = {};
      final Set<String> codigosNormalizados = codigos
          .map((c) => c.trim().toUpperCase())
          .where((c) => c.isNotEmpty)
          .toSet();

      if (codigosNormalizados.isEmpty) return resultado;

      // Traer inventario y filtrar
      final snapshot = await _coleccion.get();
      for (final doc in snapshot.docs) {
        final item = ItemInventarioModel.fromFirestore(doc.data());
        final cod = item.codigo.trim().toUpperCase();
        if (codigosNormalizados.contains(cod)) {
          resultado[cod] = item;
        }
      }
      return resultado;
    } catch (e) {
      throw ServerException('Error al consultar existencias por códigos: $e');
    }
  }
}
