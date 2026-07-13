import '../models/cliente_model.dart';

abstract class ClienteRemoteDataSource {
  Future<void> registrarCliente(ClienteModel cliente);
}