// lib/features/tickets/domain/usecases/borrador_usecases.dart
//
// Casos de uso de los borradores locales (IBorradorRepository).

import '../repositories/borrador_repository.dart';

class GuardarBorradorUseCase {
  final IBorradorRepository repository;
  GuardarBorradorUseCase(this.repository);
  Future<void> call(String clave, BorradorLocal borrador) => repository.guardar(clave, borrador);
}

class ObtenerBorradorUseCase {
  final IBorradorRepository repository;
  ObtenerBorradorUseCase(this.repository);
  Future<BorradorLocal?> call(String clave) => repository.obtener(clave);
}

class EliminarBorradorUseCase {
  final IBorradorRepository repository;
  EliminarBorradorUseCase(this.repository);
  Future<void> call(String clave) => repository.eliminar(clave);
}
