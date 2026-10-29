// lib/features/tickets/data/datasources/catalogo_activos_mantenimiento_remote_datasource.dart
//
// Lee catalogos/activos_mantenimiento: un campo por tipo de máquina
// (cosechadora, contador, caracol, vehiculo), cada uno una lista de textos
// con sus series o placas.

import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/errors/exceptions.dart';

class CatalogoActivosMantenimientoRemoteDataSource {
  final FirebaseFirestore firestore;

  CatalogoActivosMantenimientoRemoteDataSource({required this.firestore});

  Future<Map<String, List<String>>> obtener() async {
    try {
      final doc = await firestore.collection('catalogos').doc('activos_mantenimiento').get();
      final data = doc.data() ?? const <String, dynamic>{};
      return {
        for (final e in data.entries)
          if (e.value is List) e.key: [for (final v in e.value as List) if (v != null) v.toString()],
      };
    } catch (e) {
      throw ServerException('No se pudo leer el catálogo de series y placas: $e');
    }
  }
}
