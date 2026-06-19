import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import '../../../../core/errors/exceptions.dart';
import 'storage_remote_datasource.dart';

class StorageRemoteDataSourceImpl implements StorageRemoteDataSource {
  final FirebaseStorage storage;

  StorageRemoteDataSourceImpl({required this.storage});

  @override
  Future<String> subirEvidencia(File file, String ticketId) async {
    try {
      // Trazabilidad: Ruta inmutable basada en el ID del ticket y marca de tiempo
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = storage.ref().child('tickets/$ticketId/evidencia/$fileName');

      // Transmisión de datos
      final uploadTask = await ref.putFile(file);
      
      // Verificación y retorno del enlace de telemetría
      return await uploadTask.ref.getDownloadURL();
      
    } catch (e) {
      throw ServerException('Fallo al subir evidencia a Firebase Storage: $e');
    }
  }
}