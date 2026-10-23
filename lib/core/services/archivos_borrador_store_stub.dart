// lib/core/services/archivos_borrador_store_stub.dart
//
// Versión para Android/iOS: no hay IndexedDB. `disponible` es false y el
// borrador usa la lógica de BorradorStorageService (base64 + ruta).

import 'dart:typed_data';

class ArchivosBorradorStore {
  static bool get disponible => false;

  static Future<bool> guardar(String clave, Uint8List bytes) async => false;

  static Future<Uint8List?> leer(String clave) async => null;

  static Future<List<String>> listarClaves(String prefijo) async => const [];

  static Future<void> eliminar(String clave) async {}

  static Future<void> eliminarPrefijo(String prefijo) async {}

  static Future<void> marcarActividad(String prefijo) async {}

  static Future<List<String>> limpiarAntiguos(Duration edadMaxima, {String? excluirPrefijo}) async => const [];

  static Future<void> solicitarPersistencia() async {}
}
