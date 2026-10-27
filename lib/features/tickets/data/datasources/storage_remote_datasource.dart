import 'dart:io';

import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

abstract class StorageRemoteDataSource {
  /// Sube un archivo físico al servidor y retorna la URL de descarga.
  Future<String> subirEvidencia(XFile file, String ticketId);

  /// Sube bytes a `tickets/{ticketId}/{carpeta}/` y retorna la URL de descarga.
  Future<String> subirBytes({
    required Uint8List bytes,
    required String nombre,
    String? tipoContenido,
    required String ticketId,
    required String carpeta,
  });
}