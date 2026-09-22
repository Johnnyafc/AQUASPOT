// lib/features/tecnicos/data/datasources/tecnico_remote_datasource.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/tecnico_model.dart';
import '../../domain/entities/tecnico_entity.dart';

class TecnicoRemoteDataSource {
  final FirebaseFirestore _firestore;

  TecnicoRemoteDataSource({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection('catalogo_tecnicos');

  /// Escucha los técnicos en tiempo real
  Stream<List<TecnicoEntity>> escucharTecnicos({bool soloActivos = false}) {
    Query<Map<String, dynamic>> q = _col;
    if (soloActivos) {
      q = q.where('activo', isEqualTo: true);
    }
    return q.snapshots().map((snap) {
      final list = snap.docs
          .map((d) => TecnicoModel.fromJson(d.data(), docId: d.id))
          .toList();
      list.sort((a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()));
      return list;
    });
  }

  /// Guarda o actualiza un técnico en Firestore
  Future<void> registrarOActualizarTecnico(TecnicoEntity tecnico) async {
    final docRef = tecnico.id.isEmpty ? _col.doc() : _col.doc(tecnico.id);
    final model = TecnicoModel(
      id: docRef.id,
      nombre: tecnico.nombre.trim(),
      rol: tecnico.rol.trim(),
      activo: tecnico.activo,
      fechaRegistro: tecnico.fechaRegistro,
      esExterno: tecnico.esExterno,
      usuarioUid: tecnico.usuarioUid,
    );
    await docRef.set(model.toJson(), SetOptions(merge: true));
  }

  /// Conmuta el estado activo/inactivo
  Future<void> toggleActivo(String id, bool activo) async {
    await _col.doc(id).update({'activo': activo});
  }

  /// Elimina un técnico si es necesario
  Future<void> eliminarTecnico(String id) async {
    await _col.doc(id).delete();
  }
}
