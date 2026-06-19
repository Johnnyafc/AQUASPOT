import 'dart:io';

abstract class StorageRemoteDataSource {
  /// Sube un archivo físico al servidor y retorna la URL de descarga.
  Future<String> subirEvidencia(File file, String ticketId);
}