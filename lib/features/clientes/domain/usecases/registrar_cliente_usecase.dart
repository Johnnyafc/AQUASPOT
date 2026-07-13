import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../repositories/cliente_repository.dart';

class RegistrarClienteUseCase {
  final ClienteRepository repository;

  RegistrarClienteUseCase(this.repository);

  Future<Either<Failure, void>> call({
    required String camaronera,
    required String celular,
    required String direccion,
    required String emailContacto,
    required String nombreContacto,
    required String subSector,
  }) async {
    
    // ⚙️ ENCLAVAMIENTO: Validamos los campos críticos
    if (direccion.trim().isEmpty || camaronera.trim().isEmpty) {
      return Left(ServerFailure('La Razón Social (dirección) y la Camaronera son campos obligatorios.'));
    }

    return await repository.registrarCliente(
      camaronera: camaronera.trim(),
      celular: celular.trim(),
      direccion: direccion.trim(),
      emailContacto: emailContacto.trim(),
      nombreContacto: nombreContacto.trim(),
      subSector: subSector.trim(),
    );
  }
}