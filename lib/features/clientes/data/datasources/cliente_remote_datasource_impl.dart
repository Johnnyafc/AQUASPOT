import 'package:cloud_firestore/cloud_firestore.dart';
import 'cliente_remote_datasource.dart';
import '../models/cliente_model.dart';

// ⚙️ El módulo de hardware que ejecuta la inserción real
class ClienteRemoteDataSourceImpl implements ClienteRemoteDataSource {
  final FirebaseFirestore firestore;

  ClienteRemoteDataSourceImpl({required this.firestore});

  @override
  Future<void> registrarCliente(ClienteModel cliente) async {
    try {
      // 📡 Comando de escritura (Firestore genera el ID alfanumérico automáticamente)
      await firestore.collection('clientes').add(cliente.toJson());
    } catch (e) {
      // Si el enlace falla, disparamos una excepción dura para que el relé la capture
      throw Exception('Cortocircuito al intentar escribir en Firestore: $e');
    }
  }
}