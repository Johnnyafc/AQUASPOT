// lib/features/tickets/data/repositories/borrador_repository_impl.dart
//
// 💾 Borradores locales: los datos van en el almacenamiento normal
// (BorradorStorageService) y los archivos en el almacenamiento grande del
// navegador (ArchivosBorradorStore / IndexedDB, sin el límite de ~5 MB).
// Solo se escriben los archivos nuevos: los que ya estaban (mismo id) no se
// vuelven a copiar en cada guardado. En el celular (sin IndexedDB) los
// archivos van en base64 dentro de los datos, hasta 4 MB cada uno. Un
// borrador sin tocar hace más de [edadMaxima] ya no se recupera: se borra.

import 'dart:convert';
import 'dart:typed_data';
import '../../../../core/services/archivos_borrador_store.dart';
import '../../../../core/services/borrador_storage_service.dart';
import '../../domain/entities/archivo_adjunto.dart';
import '../../domain/repositories/borrador_repository.dart';

class BorradorRepositoryImpl implements IBorradorRepository {
  static const String _campoArchivos = '__archivos';
  final Duration edadMaxima;

  BorradorRepositoryImpl({this.edadMaxima = const Duration(days: 30)});

  String _prefijo(String clave) => '$clave/';

  @override
  Future<void> guardar(String clave, BorradorLocal borrador) async {
    final meta = <String, dynamic>{};
    if (ArchivosBorradorStore.disponible) {
      final prefijo = _prefijo(clave);
      final existentes = (await ArchivosBorradorStore.listarClaves(prefijo)).toSet();
      for (final e in borrador.archivos.entries) {
        final claveArchivo = '$prefijo${e.key}';
        // Si no se pudo escribir, no se anota: al recuperar no se esperará.
        if (!existentes.contains(claveArchivo) && !await ArchivosBorradorStore.guardar(claveArchivo, e.value.bytes)) {
          continue;
        }
        meta[e.key] = {'nombre': e.value.nombre, 'tipo': e.value.tipoContenido};
      }
      for (final vieja in existentes) {
        if (!borrador.archivos.containsKey(vieja.substring(prefijo.length))) {
          await ArchivosBorradorStore.eliminar(vieja);
        }
      }
      await ArchivosBorradorStore.marcarActividad(prefijo);
    } else {
      for (final e in borrador.archivos.entries) {
        if (e.value.bytes.length > BorradorStorageService.kMaxBytesParaBase64) continue;
        meta[e.key] = {'nombre': e.value.nombre, 'tipo': e.value.tipoContenido, 'base64': base64Encode(e.value.bytes)};
      }
    }
    await BorradorStorageService.guardarBorrador(clave: clave, datos: {...borrador.datos, _campoArchivos: meta});
  }

  @override
  Future<BorradorLocal?> obtener(String clave) async {
    try {
      final guardado = await BorradorStorageService.obtenerBorrador(clave);
      if (guardado == null) return null;
      final fecha = DateTime.tryParse(guardado['timestampUltimaModificacion'] as String? ?? '');
      if (fecha != null && DateTime.now().difference(fecha) > edadMaxima) {
        await eliminar(clave);
        return null;
      }
      final datos = Map<String, dynamic>.from(guardado)..remove('timestampUltimaModificacion');
      final meta = Map<String, dynamic>.from(datos.remove(_campoArchivos) as Map? ?? const {});
      final archivos = <String, ArchivoAdjunto>{};
      for (final e in meta.entries) {
        final m = Map<String, dynamic>.from(e.value as Map);
        final Uint8List? bytes = ArchivosBorradorStore.disponible
            ? await ArchivosBorradorStore.leer('${_prefijo(clave)}${e.key}')
            : (m['base64'] is String ? base64Decode(m['base64'] as String) : null);
        if (bytes == null) continue;
        archivos[e.key] = ArchivoAdjunto(bytes: bytes, nombre: m['nombre'] as String? ?? e.key, tipoContenido: m['tipo'] as String?);
      }
      return BorradorLocal(datos: datos, archivos: archivos);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> eliminar(String clave) async {
    await BorradorStorageService.eliminarBorrador(clave);
    if (ArchivosBorradorStore.disponible) await ArchivosBorradorStore.eliminarPrefijo(_prefijo(clave));
  }
}
