// lib/features/catalogo/data/datasources/catalogo_remote_datasource.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/actividad_catalogo_model.dart';

abstract class CatalogoRemoteDataSource {
  Future<List<ActividadCatalogoModel>> obtenerActividadesPorEquipo(String equipo);
  Future<void> guardarActividad(ActividadCatalogoModel actividad);
  Future<void> eliminarActividad(String id);
  Future<void> cargarCatalogoInicial(List<ActividadCatalogoModel> actividades);
}

class CatalogoRemoteDataSourceImpl implements CatalogoRemoteDataSource {
  final FirebaseFirestore firestore;

  CatalogoRemoteDataSourceImpl({required this.firestore});

  @override
  Future<List<ActividadCatalogoModel>> obtenerActividadesPorEquipo(String equipo) async {
    final query = await firestore
        .collection('catalogo_actividades')
        .where('equipo', isEqualTo: equipo.toLowerCase())
        .where('activo', isEqualTo: true)
        .get();

    final lista = query.docs
        .map((doc) => ActividadCatalogoModel.fromJson(doc.data(), doc.id))
        .toList();

    // Ordenar por código (MO001, MO002...)
    lista.sort((a, b) => a.codigo.compareTo(b.codigo));
    return lista;
  }

  @override
  Future<void> guardarActividad(ActividadCatalogoModel actividad) async {
    final docId = actividad.id.isNotEmpty
        ? actividad.id
        : '${actividad.equipo.toLowerCase()}_${actividad.codigo.toLowerCase().replaceAll(' ', '_')}';

    await firestore
        .collection('catalogo_actividades')
        .doc(docId)
        .set(actividad.toJson(), SetOptions(merge: true));
  }

  @override
  Future<void> eliminarActividad(String id) async {
    await firestore.collection('catalogo_actividades').doc(id).update({'activo': false});
  }

  @override
  Future<void> cargarCatalogoInicial(List<ActividadCatalogoModel> actividades) async {
    final batch = firestore.batch();
    for (final act in actividades) {
      final docRef = firestore.collection('catalogo_actividades').doc(act.id);
      batch.set(docRef, act.toJson(), SetOptions(merge: true));
    }
    await batch.commit();
  }
}
