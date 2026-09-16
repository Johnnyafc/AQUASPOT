import '../models/cliente_model.dart';

abstract class ClienteRemoteDataSource {
  Future<void> registrarCliente(ClienteModel cliente);
  Future<List<ClienteModel>> obtenerClientes();
  Future<void> actualizarCliente(ClienteModel cliente);
}