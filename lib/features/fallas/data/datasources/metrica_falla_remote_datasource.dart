// lib/features/fallas/data/datasources/metrica_falla_remote_datasource.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/metrica_falla_model.dart';
import '../../domain/entities/metrica_falla_entity.dart';

class MetricaFallaRemoteDataSource {
  final FirebaseFirestore _firestore;

  MetricaFallaRemoteDataSource({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection('catalogo_metricas_falla');

  static String _docKey(String tipo) => tipo.trim().toLowerCase();

  /// Escucha en tiempo real la matriz de fallas para un tipo de equipo (ej: Contador, Caracol, Cosechadora)
  Stream<MatrizFallasEquipoEntity> escucharMatrizEquipo(String tipoEquipo) {
    final docId = _docKey(tipoEquipo);
    return _col.doc(docId).snapshots().map((snap) {
      if (!snap.exists || snap.data() == null) {
        return obtenerMatrizPorDefecto(tipoEquipo);
      }
      return MatrizFallasEquipoModel.fromJson(snap.data()!);
    });
  }

  /// Inicializa o actualiza la matriz en Firestore
  Future<void> guardarMatriz(MatrizFallasEquipoEntity matriz) async {
    final docId = _docKey(matriz.tipoEquipo);
    final model = MatrizFallasEquipoModel(
      tipoEquipo: matriz.tipoEquipo,
      categorias: matriz.categorias,
    );
    await _col.doc(docId).set(model.toJson(), SetOptions(merge: true));
  }

  Future<MatrizFallasEquipoEntity> _obtenerMatrizActual(String tipoEquipo) async {
    final docId = _docKey(tipoEquipo);
    final snap = await _col.doc(docId).get();
    if (!snap.exists || snap.data() == null) {
      return obtenerMatrizPorDefecto(tipoEquipo);
    }
    return MatrizFallasEquipoModel.fromJson(snap.data()!);
  }

  /// 1. Agrega una nueva categoría mayor vacía (ej: "Eléctrico")
  Future<void> agregarCategoria({
    required String tipoEquipo,
    required String nombreCategoria,
  }) async {
    final matriz = await _obtenerMatrizActual(tipoEquipo);
    final cats = List<CategoriaFallaEntity>.from(matriz.categorias);
    final catTrim = nombreCategoria.trim();
    final existe = cats.any((c) => c.nombre.trim().toLowerCase() == catTrim.toLowerCase());

    if (!existe && catTrim.isNotEmpty) {
      cats.add(CategoriaFallaEntity(nombre: catTrim, subcategorias: const []));
      await guardarMatriz(matriz.copyWith(categorias: cats));
    }
  }

  /// 2. Elimina una categoría mayor y todas sus subcategorías
  Future<void> eliminarCategoria({
    required String tipoEquipo,
    required String nombreCategoria,
  }) async {
    final matriz = await _obtenerMatrizActual(tipoEquipo);
    final cats = matriz.categorias
        .where((c) => c.nombre.trim().toLowerCase() != nombreCategoria.trim().toLowerCase())
        .toList();
    await guardarMatriz(matriz.copyWith(categorias: cats));
  }

  /// 3. Agrega una nueva subcategoría/componente dentro de una categoría (ej: "Comap" en "Eléctrico")
  Future<void> agregarSubcategoria({
    required String tipoEquipo,
    required String nombreCategoria,
    required String nombreSubcategoria,
  }) async {
    final matriz = await _obtenerMatrizActual(tipoEquipo);
    final cats = List<CategoriaFallaEntity>.from(matriz.categorias);
    final catIdx = cats.indexWhere(
      (c) => c.nombre.trim().toLowerCase() == nombreCategoria.trim().toLowerCase(),
    );
    final subTrim = nombreSubcategoria.trim();
    if (subTrim.isEmpty) return;

    if (catIdx >= 0) {
      final actualCat = cats[catIdx];
      final subs = List<SubcategoriaFallaEntity>.from(actualCat.subcategorias);
      final existeSub = subs.any((s) => s.nombre.trim().toLowerCase() == subTrim.toLowerCase());

      if (!existeSub) {
        subs.add(SubcategoriaFallaEntity(nombre: subTrim, fallas: const []));
        cats[catIdx] = actualCat.copyWith(subcategorias: subs);
        await guardarMatriz(matriz.copyWith(categorias: cats));
      }
    } else {
      // Si la categoría no existe, la crea con esta subcategoría
      cats.add(
        CategoriaFallaEntity(
          nombre: nombreCategoria.trim(),
          subcategorias: [SubcategoriaFallaEntity(nombre: subTrim, fallas: const [])],
        ),
      );
      await guardarMatriz(matriz.copyWith(categorias: cats));
    }
  }

  /// 4. Elimina una subcategoría/componente de una categoría
  Future<void> eliminarSubcategoria({
    required String tipoEquipo,
    required String nombreCategoria,
    required String nombreSubcategoria,
  }) async {
    final matriz = await _obtenerMatrizActual(tipoEquipo);
    final cats = List<CategoriaFallaEntity>.from(matriz.categorias);
    final catIdx = cats.indexWhere(
      (c) => c.nombre.trim().toLowerCase() == nombreCategoria.trim().toLowerCase(),
    );

    if (catIdx >= 0) {
      final actualCat = cats[catIdx];
      final subs = actualCat.subcategorias
          .where((s) => s.nombre.trim().toLowerCase() != nombreSubcategoria.trim().toLowerCase())
          .toList();
      cats[catIdx] = actualCat.copyWith(subcategorias: subs);
      await guardarMatriz(matriz.copyWith(categorias: cats));
    }
  }

  /// 5. Agrega una falla específica dentro de una subcategoría (ej: "Falla en tarjeta electrónica" en "Comap")
  Future<void> agregarFalla({
    required String tipoEquipo,
    required String nombreCategoria,
    required String nombreSubcategoria,
    required String nuevaFalla,
  }) async {
    final matriz = await _obtenerMatrizActual(tipoEquipo);
    final cats = List<CategoriaFallaEntity>.from(matriz.categorias);
    final catIdx = cats.indexWhere(
      (c) => c.nombre.trim().toLowerCase() == nombreCategoria.trim().toLowerCase(),
    );
    final fallaTrim = nuevaFalla.trim();
    if (fallaTrim.isEmpty) return;

    if (catIdx >= 0) {
      final actualCat = cats[catIdx];
      final subs = List<SubcategoriaFallaEntity>.from(actualCat.subcategorias);
      final subIdx = subs.indexWhere(
        (s) => s.nombre.trim().toLowerCase() == nombreSubcategoria.trim().toLowerCase(),
      );

      if (subIdx >= 0) {
        final actualSub = subs[subIdx];
        if (!actualSub.fallas.contains(fallaTrim)) {
          subs[subIdx] = actualSub.copyWith(fallas: [...actualSub.fallas, fallaTrim]);
          cats[catIdx] = actualCat.copyWith(subcategorias: subs);
          await guardarMatriz(matriz.copyWith(categorias: cats));
        }
      } else {
        subs.add(SubcategoriaFallaEntity(nombre: nombreSubcategoria.trim(), fallas: [fallaTrim]));
        cats[catIdx] = actualCat.copyWith(subcategorias: subs);
        await guardarMatriz(matriz.copyWith(categorias: cats));
      }
    } else {
      cats.add(
        CategoriaFallaEntity(
          nombre: nombreCategoria.trim(),
          subcategorias: [
            SubcategoriaFallaEntity(nombre: nombreSubcategoria.trim(), fallas: [fallaTrim])
          ],
        ),
      );
      await guardarMatriz(matriz.copyWith(categorias: cats));
    }
  }

  /// 6. Elimina una falla específica de una subcategoría
  Future<void> eliminarFalla({
    required String tipoEquipo,
    required String nombreCategoria,
    required String nombreSubcategoria,
    required String fallaAEliminar,
  }) async {
    final matriz = await _obtenerMatrizActual(tipoEquipo);
    final cats = List<CategoriaFallaEntity>.from(matriz.categorias);
    final catIdx = cats.indexWhere(
      (c) => c.nombre.trim().toLowerCase() == nombreCategoria.trim().toLowerCase(),
    );

    if (catIdx >= 0) {
      final actualCat = cats[catIdx];
      final subs = List<SubcategoriaFallaEntity>.from(actualCat.subcategorias);
      final subIdx = subs.indexWhere(
        (s) => s.nombre.trim().toLowerCase() == nombreSubcategoria.trim().toLowerCase(),
      );

      if (subIdx >= 0) {
        final actualSub = subs[subIdx];
        subs[subIdx] = actualSub.copyWith(
          fallas: actualSub.fallas.where((f) => f != fallaAEliminar.trim()).toList(),
        );
        cats[catIdx] = actualCat.copyWith(subcategorias: subs);
        await guardarMatriz(matriz.copyWith(categorias: cats));
      }
    }
  }

  /// 7. Edita el nombre de una categoría mayor
  Future<void> editarCategoria({
    required String tipoEquipo,
    required String nombreActual,
    required String nuevoNombre,
  }) async {
    final matriz = await _obtenerMatrizActual(tipoEquipo);
    final cats = List<CategoriaFallaEntity>.from(matriz.categorias);
    final idx = cats.indexWhere(
      (c) => c.nombre.trim().toLowerCase() == nombreActual.trim().toLowerCase(),
    );
    final nuevoTrim = nuevoNombre.trim();
    if (idx >= 0 && nuevoTrim.isNotEmpty) {
      cats[idx] = cats[idx].copyWith(nombre: nuevoTrim);
      await guardarMatriz(matriz.copyWith(categorias: cats));
    }
  }

  /// 8. Edita el nombre de una subcategoría / componente
  Future<void> editarSubcategoria({
    required String tipoEquipo,
    required String nombreCategoria,
    required String nombreActual,
    required String nuevoNombre,
  }) async {
    final matriz = await _obtenerMatrizActual(tipoEquipo);
    final cats = List<CategoriaFallaEntity>.from(matriz.categorias);
    final catIdx = cats.indexWhere(
      (c) => c.nombre.trim().toLowerCase() == nombreCategoria.trim().toLowerCase(),
    );
    final nuevoTrim = nuevoNombre.trim();
    if (catIdx >= 0 && nuevoTrim.isNotEmpty) {
      final actualCat = cats[catIdx];
      final subs = List<SubcategoriaFallaEntity>.from(actualCat.subcategorias);
      final subIdx = subs.indexWhere(
        (s) => s.nombre.trim().toLowerCase() == nombreActual.trim().toLowerCase(),
      );
      if (subIdx >= 0) {
        subs[subIdx] = subs[subIdx].copyWith(nombre: nuevoTrim);
        cats[catIdx] = actualCat.copyWith(subcategorias: subs);
        await guardarMatriz(matriz.copyWith(categorias: cats));
      }
    }
  }

  /// 9. Edita la descripción de una falla específica
  Future<void> editarFalla({
    required String tipoEquipo,
    required String nombreCategoria,
    required String nombreSubcategoria,
    required String fallaActual,
    required String nuevaFalla,
  }) async {
    final matriz = await _obtenerMatrizActual(tipoEquipo);
    final cats = List<CategoriaFallaEntity>.from(matriz.categorias);
    final catIdx = cats.indexWhere(
      (c) => c.nombre.trim().toLowerCase() == nombreCategoria.trim().toLowerCase(),
    );
    final nuevaTrim = nuevaFalla.trim();
    if (catIdx >= 0 && nuevaTrim.isNotEmpty) {
      final actualCat = cats[catIdx];
      final subs = List<SubcategoriaFallaEntity>.from(actualCat.subcategorias);
      final subIdx = subs.indexWhere(
        (s) => s.nombre.trim().toLowerCase() == nombreSubcategoria.trim().toLowerCase(),
      );
      if (subIdx >= 0) {
        final actualSub = subs[subIdx];
        final fIdx = actualSub.fallas.indexOf(fallaActual);
        if (fIdx >= 0) {
          final nuevasFallas = List<String>.from(actualSub.fallas);
          nuevasFallas[fIdx] = nuevaTrim;
          subs[subIdx] = actualSub.copyWith(fallas: nuevasFallas);
          cats[catIdx] = actualCat.copyWith(subcategorias: subs);
          await guardarMatriz(matriz.copyWith(categorias: cats));
        }
      }
    }
  }

  /// Alias de retrocompatibilidad
  Future<void> agregarRazon({
    required String tipoEquipo,
    required String nombreCategoria,
    required String nuevaRazon,
  }) async {
    await agregarFalla(
      tipoEquipo: tipoEquipo,
      nombreCategoria: nombreCategoria,
      nombreSubcategoria: 'General',
      nuevaFalla: nuevaRazon,
    );
  }

  /// Alias de retrocompatibilidad
  Future<void> eliminarRazon({
    required String tipoEquipo,
    required String nombreCategoria,
    required String razonAEliminar,
  }) async {
    await eliminarFalla(
      tipoEquipo: tipoEquipo,
      nombreCategoria: nombreCategoria,
      nombreSubcategoria: 'General',
      fallaAEliminar: razonAEliminar,
    );
  }

  /// Plantilla y datos por defecto (Semilla inicial requerida)
  static MatrizFallasEquipoEntity obtenerMatrizPorDefecto(String tipoEquipo) {
    final key = tipoEquipo.trim().toLowerCase();

    if (key.contains('contador')) {
      return const MatrizFallasEquipoEntity(
        tipoEquipo: 'Contador',
        categorias: [
          CategoriaFallaEntity(
            nombre: 'Electrónico',
            subcategorias: [
              SubcategoriaFallaEntity(
                nombre: 'Comap',
                fallas: [
                  'Falla en tarjeta electrónica',
                  'Fallo en borneras',
                  'Fallo de comunicación CAN',
                ],
              ),
              SubcategoriaFallaEntity(
                nombre: 'Cableado y Puertos',
                fallas: [
                  'Desgaste de puerto de los cables',
                  'Mala manipulación de los cables',
                ],
              ),
              SubcategoriaFallaEntity(
                nombre: 'Placas',
                fallas: [
                  'Daños en la placa electrónica de la pantalla y sus componentes',
                  'Rotura de la soldadura',
                  'Daño en la placa del cabezal',
                ],
              ),
            ],
          ),
          CategoriaFallaEntity(
            nombre: 'Mecánico',
            subcategorias: [
              SubcategoriaFallaEntity(
                nombre: 'Estructura y Ensamblaje',
                fallas: [
                  'Defectos de soldadura',
                  'Defectos de ensamblaje',
                ],
              ),
            ],
          ),
          CategoriaFallaEntity(
            nombre: 'Software',
            subcategorias: [
              SubcategoriaFallaEntity(
                nombre: 'Sistema de Visión',
                fallas: [
                  'Mala calibración de la curva de la cámara',
                  'Falta de iluminación en sistema',
                  'Cámara desalineada',
                ],
              ),
              SubcategoriaFallaEntity(
                nombre: 'Licenciamiento',
                fallas: [
                  'Error de licencia',
                ],
              ),
            ],
          ),
        ],
      );
    }

    if (key.contains('caracol')) {
      return const MatrizFallasEquipoEntity(
        tipoEquipo: 'Caracol',
        categorias: [],
      );
    }

    if (key.contains('cosechadora')) {
      return const MatrizFallasEquipoEntity(
        tipoEquipo: 'Cosechadora',
        categorias: [],
      );
    }

    // Cualquier otro equipo inicia en blanco para configurar desde cero
    return MatrizFallasEquipoEntity(
      tipoEquipo: tipoEquipo,
      categorias: const [],
    );
  }
}
