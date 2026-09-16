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

  @override
  Future<List<ClienteModel>> obtenerClientes() async {
    try {
      final snapshot = await firestore.collection('clientes').get();
      return snapshot.docs.map((doc) => ClienteModel.fromJson(doc.data(), doc.id)).toList();
    } catch (e) {
      throw Exception('Cortocircuito al consultar clientes en Firestore: $e');
    }
  }

  @override
  Future<void> actualizarCliente(ClienteModel cliente) async {
    try {
      await firestore.collection('clientes').doc(cliente.id).update(cliente.toUpdateJson());
    } catch (e) {
      throw Exception('Cortocircuito al actualizar cliente en Firestore: $e');
    }
  }
}