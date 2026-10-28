// lib/features/plan_preventivo/data/datasources/plan_preventivo_remote_datasource.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../tickets/domain/entities/mantenimiento_interno_entity.dart';
import '../../domain/entities/actividad_preventiva_entity.dart';
import '../models/actividad_preventiva_model.dart';

abstract class PlanPreventivoRemoteDataSource {
  Future<List<ActividadPreventivaEntity>> obtenerPorMaquina(TipoActivoMantenimiento tipo);
  Future<ActividadPreventivaEntity> guardar(ActividadPreventivaEntity actividad);
  Future<void> desactivar(String id, {required String usuarioNombre});
}

class PlanPreventivoRemoteDataSourceImpl implements PlanPreventivoRemoteDataSource {
  static const coleccion = 'plan_preventivo';
  final FirebaseFirestore firestore;

  PlanPreventivoRemoteDataSourceImpl({required this.firestore});

  @override
  Future<List<ActividadPreventivaEntity>> obtenerPorMaquina(TipoActivoMantenimiento tipo) async {
    final query = await firestore.collection(coleccion).where('tipoActivo', isEqualTo: tipo.name).get();
    final lista = [
      for (final doc in query.docs) ?ActividadPreventivaModel.fromJson(doc.data(), doc.id),
    ];
    lista.sort((a, b) => a.codigo.compareTo(b.codigo));
    return lista;
  }

  /// Nueva (id vacío): se crea en una transacción que falla si ese código ya
  /// existe (otro usuario la creó a la vez). Edición: actualiza sin tocar
  /// "activo".
  @override
  Future<ActividadPreventivaEntity> guardar(ActividadPreventivaEntity actividad) async {
    if (actividad.id.isNotEmpty) {
      await firestore
          .collection(coleccion)
          .doc(actividad.id)
          .set(ActividadPreventivaModel.toJson(actividad, incluirActivo: false), SetOptions(merge: true));
      return actividad;
    }
    final ref = firestore.collection(coleccion).doc(ActividadPreventivaModel.idDe(actividad));
    await firestore.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (snap.exists) {
        throw Exception('El código ${actividad.codigo} ya existe (otro usuario lo acaba de crear). '
            'Cierre y vuelva a agregar la actividad.');
      }
      tx.set(ref, ActividadPreventivaModel.toJson(actividad));
    });
    return actividad.copyWith(id: ref.id);
  }

  @override
  Future<void> desactivar(String id, {required String usuarioNombre}) async {
    await firestore.collection(coleccion).doc(id).update({
      'activo': false,
      'actualizadoPor': usuarioNombre,
      'fechaActualizacion': FieldValue.serverTimestamp(),
    });
  }
}
