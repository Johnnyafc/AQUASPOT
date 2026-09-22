// lib/core/services/borrador_storage_service.dart

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Servicio Universal de Persistencia de Borradores en Almacenamiento Local.
/// Garantiza que si el usuario sale de la pantalla, recibe una llamada o cambia
/// de aplicación o pestaña web, sus formularios, notas, fotos, videos,
/// informes técnicos y diagnósticos se mantengan 100% seguros y se restauren automáticamente.
class BorradorStorageService {
  // Claves maestras estandarizadas
  static const String kClaveDraftCreacionTicket = 'draft_creacion_ticket';

  static String claveDraftRecepcion(String ticketId) => 'draft_recepcion_$ticketId';
  static String claveDraftTrabajo(String ticketId) => 'draft_trabajo_$ticketId';
  static String claveDraftEvaluacion(String ticketId) => 'draft_evaluacion_$ticketId';
  static String claveDraftEntrega(String ticketId) => 'draft_entrega_$ticketId';

  static const int kMaxBytesParaBase64 = 4 * 1024 * 1024; // 4 MB por archivo

  /// Guarda un mapa serializable como JSON en SharedPreferences.
  /// Incluye protección contra desbordamiento de cuota de almacenamiento (ej. en Web).
  static Future<bool> guardarBorrador({
    required String clave,
    required Map<String, dynamic> datos,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final copia = Map<String, dynamic>.from(datos);
      copia['timestampUltimaModificacion'] = DateTime.now().toIso8601String();
      final jsonStr = jsonEncode(copia);
      return await prefs.setString(clave, jsonStr);
    } catch (e) {
      // Si falla por tamaño (ej: QuotaExceededError en Web), intentamos guardar sin payloads base64
      try {
        final prefs = await SharedPreferences.getInstance();
        final copiaLigera = _limpiarPayloadsPesados(Map<String, dynamic>.from(datos));
        copiaLigera['timestampUltimaModificacion'] = DateTime.now().toIso8601String();
        copiaLigera['borradorAligeradoPorCuota'] = true;
        return await prefs.setString(clave, jsonEncode(copiaLigera));
      } catch (_) {
        return false;
      }
    }
  }

  static Map<String, dynamic> _limpiarPayloadsPesados(Map<String, dynamic> mapa) {
    final Map<String, dynamic> resultado = {};
    mapa.forEach((key, value) {
      if (value is List) {
        resultado[key] = value.map((item) {
          if (item is Map) {
            final copiaItem = Map<String, dynamic>.from(item);
            copiaItem.remove('base64');
            return copiaItem;
          }
          return item;
        }).toList();
      } else if (value is Map) {
        final copiaMap = Map<String, dynamic>.from(value);
        copiaMap.remove('base64');
        resultado[key] = copiaMap;
      } else {
        resultado[key] = value;
      }
    });
    return resultado;
  }

  /// Obtiene y decodifica el borrador almacenado bajo la clave indicada
  static Future<Map<String, dynamic>?> obtenerBorrador(String clave) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(clave);
      if (jsonStr == null || jsonStr.trim().isEmpty) return null;
      final map = jsonDecode(jsonStr);
      if (map is Map<String, dynamic>) return map;
      return Map<String, dynamic>.from(map as Map);
    } catch (e) {
      return null;
    }
  }

  /// Elimina de forma segura el borrador tras un envío exitoso o descarte
  static Future<bool> eliminarBorrador(String clave) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.remove(clave);
    } catch (e) {
      return false;
    }
  }

  /// Verifica si existe un borrador guardado para la clave dada
  static Future<bool> existeBorrador(String clave) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.containsKey(clave) && (prefs.getString(clave)?.isNotEmpty ?? false);
    } catch (e) {
      return false;
    }
  }

  // =========================================================================
  // 📁 UTILITARIOS PARA PLATFORM_FILE (WEB + NATIVO)
  // =========================================================================

  /// Convierte un PlatformFile a JSON guardando nombre, tamaño, ruta y bytes (Base64)
  static Map<String, dynamic> platformFileToJson(PlatformFile file) {
    String? base64Content;
    final int tamanio = file.size;

    if (tamanio <= kMaxBytesParaBase64) {
      if (file.bytes != null && file.bytes!.isNotEmpty) {
        base64Content = base64Encode(file.bytes!);
      } else if (!kIsWeb && file.path != null && file.path!.isNotEmpty) {
        try {
          final f = File(file.path!);
          if (f.existsSync()) {
            base64Content = base64Encode(f.readAsBytesSync());
          }
        } catch (_) {}
      }
    }

    return {
      'name': file.name,
      'size': file.size,
      'path': file.path,
      'extension': file.extension,
      'base64': ?base64Content,
    };
  }

  /// Reconstruye un PlatformFile desde JSON con soporte multiplataforma
  static PlatformFile? jsonToPlatformFile(dynamic json) {
    if (json == null || json is! Map) return null;
    try {
      final map = Map<String, dynamic>.from(json);
      final name = map['name'] as String? ?? 'archivo';
      final size = map['size'] as int? ?? 0;
      final path = map['path'] as String?;
      final base64Str = map['base64'] as String?;

      Uint8List? bytes;
      if (base64Str != null && base64Str.isNotEmpty) {
        try {
          bytes = base64Decode(base64Str);
        } catch (_) {}
      } else if (!kIsWeb && path != null && path.isNotEmpty) {
        try {
          final f = File(path);
          if (f.existsSync()) {
            bytes = f.readAsBytesSync();
          }
        } catch (_) {}
      }

      if (bytes == null && (path == null || path.isEmpty)) {
        return PlatformFile(
          name: name,
          size: size,
          path: path,
        );
      }

      return PlatformFile(
        name: name,
        size: bytes?.length ?? size,
        path: path,
        bytes: bytes,
      );
    } catch (_) {
      return null;
    }
  }

  /// Convierte lista de PlatformFile a lista de JSON
  static List<Map<String, dynamic>> platformFilesToJson(List<PlatformFile> files) {
    return files.map((f) => platformFileToJson(f)).toList();
  }

  /// Reconstruye lista de PlatformFile desde lista de JSON
  static List<PlatformFile> jsonToPlatformFiles(List<dynamic>? list) {
    if (list == null) return [];
    final List<PlatformFile> result = [];
    for (final item in list) {
      final pf = jsonToPlatformFile(item);
      if (pf != null) result.add(pf);
    }
    return result;
  }

  // =========================================================================
  // 📸 UTILITARIOS PARA XFILE (IMÁGENES / CÁMARA)
  // =========================================================================

  /// Convierte un XFile a JSON con bytes en Base64
  static Future<Map<String, dynamic>> xFileToJson(XFile file) async {
    String? base64Content;
    try {
      final bytes = await file.readAsBytes();
      if (bytes.length <= kMaxBytesParaBase64) {
        base64Content = base64Encode(bytes);
      }
    } catch (_) {}

    final resolvedName = file.name.isNotEmpty
        ? file.name
        : (file.path.isNotEmpty ? file.path.split(RegExp(r'[/\\]')).last : 'imagen');

    return {
      'name': resolvedName,
      'path': file.path,
      'base64': base64Content,
    };
  }

  /// Reconstruye un XFile desde JSON
  static XFile? jsonToXFile(dynamic json) {
    if (json == null || json is! Map) return null;
    try {
      final map = Map<String, dynamic>.from(json);
      final name = map['name'] as String? ?? 'imagen';
      final path = map['path'] as String?;
      final base64Str = map['base64'] as String?;

      if (base64Str != null && base64Str.isNotEmpty) {
        try {
          final bytes = base64Decode(base64Str);
          return XFile.fromData(
            bytes,
            name: name,
            path: (path != null && path.isNotEmpty) ? path : name,
          );
        } catch (_) {}
      }

      if (!kIsWeb && path != null && path.isNotEmpty) {
        final f = File(path);
        if (f.existsSync()) {
          return XFile(path, name: name);
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Convierte lista de XFile a lista de JSON con bytes
  static Future<List<Map<String, dynamic>>> xFilesToJson(List<XFile> files) async {
    final List<Map<String, dynamic>> result = [];
    for (final f in files) {
      result.add(await xFileToJson(f));
    }
    return result;
  }

  /// Reconstruye lista de XFile desde lista de JSON
  static List<XFile> jsonToXFiles(List<dynamic>? list) {
    if (list == null) return [];
    final List<XFile> result = [];
    for (final item in list) {
      final xf = jsonToXFile(item);
      if (xf != null) result.add(xf);
    }
    return result;
  }

  // =========================================================================
  // 🔄 MÉTODOS DE COMPATIBILIDAD RETROACTIVA (RUTAS)
  // =========================================================================

  static List<String> xFilesToPaths(List<XFile> files) {
    return files.map((f) => f.path).where((p) => p.isNotEmpty).toList();
  }

  static List<XFile> pathsToXFiles(List<dynamic>? paths) {
    if (paths == null) return [];
    if (kIsWeb) return [];
    final List<XFile> result = [];
    for (final p in paths) {
      if (p is String && p.isNotEmpty) {
        try {
          final f = File(p);
          if (f.existsSync()) {
            result.add(XFile(p));
          }
        } catch (_) {}
      }
    }
    return result;
  }

  static List<String> platformFilesToPaths(List<PlatformFile> files) {
    return files
        .map((f) => f.path)
        .whereType<String>()
        .where((p) => p.isNotEmpty)
        .toList();
  }

  static List<PlatformFile> pathsToPlatformFiles(List<dynamic>? paths) {
    if (paths == null) return [];
    if (kIsWeb) return [];
    final List<PlatformFile> result = [];
    for (final p in paths) {
      if (p is String && p.isNotEmpty) {
        final pf = pathToPlatformFile(p);
        if (pf != null) result.add(pf);
      }
    }
    return result;
  }

  static PlatformFile? pathToPlatformFile(String? path) {
    if (path == null || path.isEmpty) return null;
    if (kIsWeb) return null;
    try {
      final f = File(path);
      if (!f.existsSync()) return null;
      final bytes = f.readAsBytesSync();
      final name = path.replaceAll('\\', '/').split('/').last;
      return PlatformFile(
        name: name,
        size: f.lengthSync(),
        path: path,
        bytes: bytes,
      );
    } catch (_) {
      return null;
    }
  }
}
