import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/cliente_entity.dart';

abstract class ClienteRepository {
  Future<Either<Failure, void>> registrarCliente({
    required String camaronera,
    required String celular,
    required String direccion,
    required String emailContacto,
    required String nombreContacto,
    required String subSector,
  });

  Future<Either<Failure, List<ClienteEntity>>> obtenerClientes();
  Future<Either<Failure, void>> actualizarCliente(ClienteEntity cliente);
}