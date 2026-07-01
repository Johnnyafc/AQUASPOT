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
        SettableMetadata(contentType: 'image/jpeg') // Ajusta según el tipo de archivo
      );
      
      return await uploadTask.ref.getDownloadURL();
      
    } catch (e) {
      throw ServerException('Fallo crítico al subir a Firebase Storage: $e');
    }
}
}