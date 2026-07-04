import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/enum/segmento_operativo.dart';
import '../../../../core/enum/rol_usuario.dart'; // Ajusta la ruta a tu enum de Rol
import '../repositories/auth_repository.dart';

// ⚙️ El variador de frecuencia. Recibe la orden del BLoC y la transfiere al Repositorio.
class RegistrarUsuarioUseCase {
  final AuthRepository repository;

  // Inyección de dependencias estricta
  RegistrarUsuarioUseCase(this.repository);

  Future<Either<Failure, void>> call({
    required String nombre,
    required String email,
    required String password,
    required SegmentoOperativo segmento,
    required RolUsuario rol,
  }) async {
    // Aquí podrías agregar validaciones de dominio si quisieras
    // (Ej. verificar que el password tenga cierta longitud mínima antes de gastar ancho de banda)
    
    return await repository.registrarUsuario(
      nombre: nombre,
      email: email,
      password: password,
      segmento: segmento,
      rol: rol,
    );
  }
}