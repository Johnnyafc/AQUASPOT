import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/cliente_entity.dart';
import '../../domain/repositories/cliente_repository.dart';
import '../datasources/cliente_remote_datasource.dart';
import '../models/cliente_model.dart';

// ⚙️ El bloque de control central del módulo de datos
class ClienteRepositoryImpl implements ClienteRepository {
  final ClienteRemoteDataSource remoteDataSource;

  ClienteRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, void>> registrarCliente({
    required String camaronera,
    required String celular,
    required String direccion,
    required String emailContacto,
    required String nombreContacto,
    required String subSector,
  }) async {
    try {
      // 1. Ensamblaje de la carga útil (Payload)
      final clienteModel = ClienteModel(
        id: '', // Se deja vacío, Firestore auto-asigna el UID del documento
        camaronera: camaronera,
        celular: celular,
        direccion: direccion,
        emailContacto: emailContacto,
        estadoActual: 'activo', // Estado nominal
        nombreContacto: nombreContacto,
        subSector: subSector,
        fechaRegistro: null, // Dejamos que el toJson() asigne el FieldValue.serverTimestamp()
      );

      // 2. Transmisión al módulo remoto
      await remoteDataSource.registrarCliente(clienteModel);
      
      return const Right(null); // ✅ Señal de OK
      
    } on Exception catch (e) {
      // 🛑 Salto del breaker de protección
      return Left(ServerFailure('Fallo de infraestructura en BD: $e'));
    }
  }

  @override
  Future<Either<Failure, List<ClienteEntity>>> obtenerClientes() async {
    try {
      final clientes = await remoteDataSource.obtenerClientes();
      return Right(clientes.cast<ClienteEntity>());
    } on Exception catch (e) {
      return Left(ServerFailure('Error al obtener clientes: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> actualizarCliente(ClienteEntity cliente) async {
    try {
      final model = ClienteModel.fromEntity(cliente);
      await remoteDataSource.actualizarCliente(model);
      return const Right(null);
    } on Exception catch (e) {
      return Left(ServerFailure('Error al actualizar cliente: $e'));
    }
  }
}