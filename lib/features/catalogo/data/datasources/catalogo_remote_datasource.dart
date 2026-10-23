// lib/features/catalogo/data/datasources/catalogo_remote_datasource.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/actividad_catalogo_model.dart';
import '../../domain/services/revision_codigos_plan_maestro_service.dart';

abstract class CatalogoRemoteDataSource {
  Future<List<ActividadCatalogoModel>> obtenerActividadesPorEquipo(String equipo);
  Future<void> guardarActividad(ActividadCatalogoModel actividad);
  Future<void> eliminarActividad(String id);
  Future<void> cargarCatalogoInicial(List<ActividadCatalogoModel> actividades);

  /// Revisión de Códigos del Plan Maestro: en las actividades indicadas
  /// (todas del [equipo]) cambia el ítem con [codigoAnterior] (o, si no
  /// tiene código, con [descripcionAnterior]) por el código/descripción/
  /// unidad nuevos, en una transacción, y deja el cambio en
  /// `historial_plan_maestro`. Devuelve cuántas actividades cambiaron.
  Future<int> reemplazarItemPlanMaestro({
    required String equipo,
    required List<String> actividadIds,
    required String codigoAnterior,
    required String descripcionAnterior,
    required String codigoNuevo,
    String? descripcionNueva, // null = cada ítem conserva la suya
    String? unidadNueva, // null = cada ítem conserva la suya
    required String tipo, // 'editar' | 'asignar'
    required String usuarioEmail,
    required String usuarioNombre,
  });

  /// Último cambio (no deshecho) del historial del plan maestro del equipo.
  Future<Map<String, dynamic>?> obtenerUltimoCambioPlanMaestro(String equipo);

  /// Devuelve las actividades al estado anterior al cambio, solo si nadie
  /// las modificó después.
  Future<void> deshacerCambioPlanMaestro({required String historialId, required String usuarioEmail});
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

  static List<Map<String, dynamic>> _listaItems(dynamic raw) => (raw as List<dynamic>? ?? [])
      .map((e) => Map<String, dynamic>.from(e as Map))
      .toList();

  @override
  Future<int> reemplazarItemPlanMaestro({
    required String equipo,
    required List<String> actividadIds,
    required String codigoAnterior,
    required String descripcionAnterior,
    required String codigoNuevo,
    String? descripcionNueva, // null = cada ítem conserva la suya
    String? unidadNueva, // null = cada ítem conserva la suya
    required String tipo,
    required String usuarioEmail,
    required String usuarioNombre,
  }) async {
    final equipoNorm = equipo.toLowerCase();
    final historialRef = firestore.collection('historial_plan_maestro').doc();

    return firestore.runTransaction<int>((tx) async {
      // Firestore exige leer todo antes de escribir.
      final snaps = <DocumentSnapshot<Map<String, dynamic>>>[];
      for (final id in actividadIds.toSet()) {
        snaps.add(await tx.get(firestore.collection('catalogo_actividades').doc(id)));
      }

      final antes = <String, dynamic>{};
      final despues = <String, dynamic>{};
      final codigosActividad = <String>[];
      final escrituras = <DocumentReference<Map<String, dynamic>>, Map<String, dynamic>>{};

      for (final snap in snaps) {
        final data = snap.data();
        if (data == null) continue;
        if ((data['equipo'] as String? ?? '').toLowerCase() != equipoNorm) {
          throw Exception('La actividad ${data['codigo'] ?? snap.id} no pertenece al equipo $equipo.');
        }
        final internos = _listaItems(data['itemsInternos']);
        final comerciales = _listaItems(data['itemsComerciales']);
        List<Map<String, dynamic>>? reemplazar(List<Map<String, dynamic>> items) =>
            RevisionCodigosPlanMaestroService.reemplazarEnLista(
              items: items,
              codigoAnterior: codigoAnterior,
              descripcionAnterior: descripcionAnterior,
              codigoNuevo: codigoNuevo,
              descripcionNueva: descripcionNueva,
              unidadNueva: unidadNueva,
            );
        final nuevosInternos = reemplazar(internos);
        final nuevosComerciales = reemplazar(comerciales);
        if (nuevosInternos == null && nuevosComerciales == null) continue;

        escrituras[snap.reference] = {
          'itemsInternos': ?nuevosInternos,
          'itemsComerciales': ?nuevosComerciales,
        };
        antes[snap.id] = {'itemsInternos': internos, 'itemsComerciales': comerciales};
        despues[snap.id] = {
          'itemsInternos': nuevosInternos ?? internos,
          'itemsComerciales': nuevosComerciales ?? comerciales,
        };
        codigosActividad.add(data['codigo'] as String? ?? snap.id);
      }

      if (escrituras.isEmpty) return 0;
      escrituras.forEach((ref, cambios) => tx.update(ref, cambios));
      tx.set(historialRef, {
        'equipo': equipoNorm,
        'tipo': tipo,
        'codigoAnterior': codigoAnterior.trim(),
        'descripcionAnterior': descripcionAnterior.trim(),
        'codigoNuevo': codigoNuevo.trim(),
        'descripcionNueva': descripcionNueva?.trim(),
        'unidadNueva': unidadNueva?.trim(),
        'actividadIds': antes.keys.toList(),
        'actividadCodigos': codigosActividad,
        'usuarioEmail': usuarioEmail,
        'usuarioNombre': usuarioNombre,
        'fecha': FieldValue.serverTimestamp(),
        'deshecho': false,
        'antes': antes,
        'despues': despues,
      });
      return escrituras.length;
    });
  }

  @override
  Future<Map<String, dynamic>?> obtenerUltimoCambioPlanMaestro(String equipo) async {
    // Sin orderBy para no requerir índice compuesto: el historial por equipo
    // es corto y se ordena aquí.
    final query = await firestore
        .collection('historial_plan_maestro')
        .where('equipo', isEqualTo: equipo.toLowerCase())
        .get();
    final docs = query.docs.where((d) => d.data()['deshecho'] != true).toList();
    if (docs.isEmpty) return null;
    int ms(dynamic f) => f is Timestamp ? f.millisecondsSinceEpoch : 0;
    docs.sort((a, b) => ms(b.data()['fecha']).compareTo(ms(a.data()['fecha'])));
    return {...docs.first.data(), 'id': docs.first.id};
  }

  @override
  Future<void> deshacerCambioPlanMaestro({required String historialId, required String usuarioEmail}) async {
    final historialRef = firestore.collection('historial_plan_maestro').doc(historialId);

    await firestore.runTransaction<void>((tx) async {
      final historial = await tx.get(historialRef);
      final data = historial.data();
      if (data == null) throw Exception('No se encontró el cambio en el historial.');
      if (data['deshecho'] == true) throw Exception('Este cambio ya fue deshecho.');

      final antes = Map<String, dynamic>.from(data['antes'] as Map? ?? {});
      final despues = Map<String, dynamic>.from(data['despues'] as Map? ?? {});

      final snaps = <DocumentSnapshot<Map<String, dynamic>>>[];
      for (final id in antes.keys) {
        snaps.add(await tx.get(firestore.collection('catalogo_actividades').doc(id)));
      }

      for (final snap in snaps) {
        final actual = snap.data();
        final esperado = Map<String, dynamic>.from(despues[snap.id] as Map? ?? {});
        final igual = actual != null &&
            RevisionCodigosPlanMaestroService.huellaItems(actual['itemsInternos'] as List? ?? []) ==
                RevisionCodigosPlanMaestroService.huellaItems(esperado['itemsInternos'] as List? ?? []) &&
            RevisionCodigosPlanMaestroService.huellaItems(actual['itemsComerciales'] as List? ?? []) ==
                RevisionCodigosPlanMaestroService.huellaItems(esperado['itemsComerciales'] as List? ?? []);
        if (!igual) {
          throw Exception('La actividad ${actual?['codigo'] ?? snap.id} cambió después de este ajuste; '
              'no se puede deshacer automáticamente.');
        }
      }

      for (final snap in snaps) {
        final previo = Map<String, dynamic>.from(antes[snap.id] as Map);
        tx.update(snap.reference, {
          'itemsInternos': previo['itemsInternos'] ?? [],
          'itemsComerciales': previo['itemsComerciales'] ?? [],
        });
      }
      tx.update(historialRef, {
        'deshecho': true,
        'deshechoPor': usuarioEmail,
        'fechaDeshecho': FieldValue.serverTimestamp(),
      });
    });
  }
}
