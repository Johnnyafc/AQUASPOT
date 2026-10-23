// lib/core/services/archivos_borrador_store_web.dart
//
// Implementación Web con IndexedDB (via `package:web`, sin librerías nuevas).
// Base `aquaspot_borradores`:
//   - `archivos`: clave (p. ej. "evaluacion_REQ-00012/1712345678-3") → bytes
//   - `meta`: prefijo del borrador (p. ej. "evaluacion_REQ-00012/") → fecha
//     (ms) de la última modificación, para limpiar los abandonados.

import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

class ArchivosBorradorStore {
  static const String _nombreBase = 'aquaspot_borradores';
  static const String _storeArchivos = 'archivos';
  static const String _storeMeta = 'meta';

  static Future<web.IDBDatabase>? _db;

  static bool get disponible => true;

  static Future<JSAny?> _esperar(web.IDBRequest request) {
    final completer = Completer<JSAny?>();
    request.onsuccess = ((web.Event _) {
      if (!completer.isCompleted) completer.complete(request.result);
    }).toJS;
    request.onerror = ((web.Event _) {
      if (!completer.isCompleted) {
        completer.completeError(Exception('IndexedDB: ${request.error?.message ?? 'error desconocido'}'));
      }
    }).toJS;
    return completer.future;
  }

  static Future<web.IDBDatabase> _abrir() {
    return _db ??= () async {
      final request = web.window.indexedDB.open(_nombreBase, 1);
      request.onupgradeneeded = ((web.Event _) {
        final db = request.result as web.IDBDatabase;
        if (!db.objectStoreNames.contains(_storeArchivos)) db.createObjectStore(_storeArchivos);
        if (!db.objectStoreNames.contains(_storeMeta)) db.createObjectStore(_storeMeta);
      }).toJS;
      final resultado = await _esperar(request);
      return resultado as web.IDBDatabase;
    }();
  }

  static Future<web.IDBObjectStore> _store(String nombre, {bool escritura = false}) async {
    final db = await _abrir();
    final tx = db.transaction(nombre.toJS, escritura ? 'readwrite' : 'readonly');
    return tx.objectStore(nombre);
  }

  static web.IDBKeyRange _rango(String prefijo) =>
      web.IDBKeyRange.bound(prefijo.toJS, '$prefijo￿'.toJS);

  static Future<bool> guardar(String clave, Uint8List bytes) async {
    try {
      final store = await _store(_storeArchivos, escritura: true);
      await _esperar(store.put(bytes.toJS, clave.toJS));
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<Uint8List?> leer(String clave) async {
    try {
      final store = await _store(_storeArchivos);
      final resultado = await _esperar(store.get(clave.toJS));
      if (resultado == null || resultado.isUndefinedOrNull) return null;
      return (resultado as JSUint8Array).toDart;
    } catch (_) {
      return null;
    }
  }

  static Future<List<String>> listarClaves(String prefijo) async {
    try {
      final store = await _store(_storeArchivos);
      final resultado = await _esperar(store.getAllKeys(_rango(prefijo)));
      if (resultado == null) return const [];
      return (resultado as JSArray<JSAny?>).toDart.map((k) => (k as JSString).toDart).toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<void> eliminar(String clave) async {
    try {
      final store = await _store(_storeArchivos, escritura: true);
      await _esperar(store.delete(clave.toJS));
    } catch (_) {}
  }

  static Future<void> eliminarPrefijo(String prefijo) async {
    try {
      final archivos = await _store(_storeArchivos, escritura: true);
      await _esperar(archivos.delete(_rango(prefijo)));
      final meta = await _store(_storeMeta, escritura: true);
      await _esperar(meta.delete(prefijo.toJS));
    } catch (_) {}
  }

  /// Registra que el borrador [prefijo] se modificó ahora.
  static Future<void> marcarActividad(String prefijo) async {
    try {
      final meta = await _store(_storeMeta, escritura: true);
      await _esperar(meta.put(DateTime.now().millisecondsSinceEpoch.toJS, prefijo.toJS));
    } catch (_) {}
  }

  /// Borra los borradores sin modificar hace más de [edadMaxima].
  /// Devuelve los prefijos eliminados. [excluirPrefijo] (el borrador abierto)
  /// nunca se toca.
  static Future<List<String>> limpiarAntiguos(Duration edadMaxima, {String? excluirPrefijo}) async {
    try {
      final meta = await _store(_storeMeta);
      final claves = await _esperar(meta.getAllKeys());
      final valores = await _esperar((await _store(_storeMeta)).getAll());
      if (claves == null || valores == null) return const [];
      final listaClaves = (claves as JSArray<JSAny?>).toDart;
      final listaValores = (valores as JSArray<JSAny?>).toDart;
      final limite = DateTime.now().subtract(edadMaxima).millisecondsSinceEpoch;
      final eliminados = <String>[];
      for (var i = 0; i < listaClaves.length && i < listaValores.length; i++) {
        final fecha = (listaValores[i] as JSNumber).toDartDouble;
        final prefijo = (listaClaves[i] as JSString).toDart;
        if (fecha < limite && prefijo != excluirPrefijo) {
          await eliminarPrefijo(prefijo);
          eliminados.add(prefijo);
        }
      }
      return eliminados;
    } catch (_) {
      return const [];
    }
  }

  /// Pide al navegador que no borre estos datos aunque le falte espacio.
  static Future<void> solicitarPersistencia() async {
    try {
      await web.window.navigator.storage.persist().toDart;
    } catch (_) {}
  }
}
