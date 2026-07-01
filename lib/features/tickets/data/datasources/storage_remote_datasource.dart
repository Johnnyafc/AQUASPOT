import 'dart:io';

import 'package:image_picker/image_picker.dart';

abstract class StorageRemoteDataSource {
  /// Sube un archivo físico al servidor y retorna la URL de descarga.
  Future<String> subirEvidencia(XFile file, String ticketId);
}