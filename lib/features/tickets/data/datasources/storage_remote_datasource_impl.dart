import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/errors/exceptions.dart';
import 'storage_remote_datasource.dart';
import 'dart:typed_data';

class StorageRemoteDataSourceImpl implements StorageRemoteDataSource {
  final FirebaseStorage storage;

  StorageRemoteDataSourceImpl({required this.storage});

@override
  Future<String> subirEvidencia(XFile file, String ticketId) async {
    try {
      // 1. Obtenemos los bytes del XFile (Universal para Web y Nativo)
      final Uint8List bytes = await file.readAsBytes();
      
      // 2. Generamos el nombre del archivo
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.name}';
      final ref = storage.ref().child('tickets/$ticketId/evidencia/$fileName');

      // 3. Subimos los bytes directamente (putData es la clave aquí)
      // putData no distingue entre si es web o nativo, simplemente recibe el buffer
      final uploadTask = await ref.putData(
        bytes, 
        SettableMetadata(contentType: _tipoContenido(file)) // imagen o video, según el archivo
      );
      
      return await uploadTask.ref.getDownloadURL();
      
    } catch (e) {
      throw ServerException('Fallo crítico al subir a Firebase Storage: $e');
    }
}

  @override
  Future<String> subirBytes({
    required Uint8List bytes,
    required String nombre,
    String? tipoContenido,
    required String ticketId,
    required String carpeta,
  }) async {
    try {
      final ref = storage.ref().child('tickets/$ticketId/$carpeta/${DateTime.now().millisecondsSinceEpoch}_$nombre');
      final subida = await ref.putData(bytes, SettableMetadata(contentType: _tipoDe(tipoContenido, nombre)));
      return await subida.ref.getDownloadURL();
    } catch (e) {
      throw ServerException('Fallo crítico al subir a Firebase Storage: $e');
    }
  }

  /// Tipo del archivo para Storage (así los videos se reproducen en el
  /// navegador). Si no se puede saber, se asume foto JPEG como antes.
  static String _tipoContenido(XFile file) => _tipoDe(file.mimeType, file.name);

  static String _tipoDe(String? mime, String nombreArchivo) {
    if (mime != null && mime.contains('/')) return mime;
    final nombre = nombreArchivo.toLowerCase();
    final extension = nombre.contains('.') ? nombre.split('.').last : '';
    return switch (extension) {
      'mp4' || 'm4v' => 'video/mp4',
      'mov' => 'video/quicktime',
      'webm' => 'video/webm',
      '3gp' => 'video/3gpp',
      'png' => 'image/png',
      'heic' => 'image/heic',
      'webp' => 'image/webp',
      _ => 'image/jpeg',
    };
  }
}