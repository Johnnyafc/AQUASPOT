// lib/features/tickets/domain/repositories/catalogo_activos_mantenimiento_repository.dart
//
// Catálogo de series (máquinas) y placas (vehículos) de MANTENIMIENTO
// INTERNO, que el administrador llena en Firestore.

import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';

abstract class ICatalogoActivosMantenimientoRepository {
  /// Nombre del tipo de máquina → series / placas, tal como están guardadas
  /// (vacío si el documento aún no existe).
  Future<Either<Failure, Map<String, List<String>>>> obtener();
}
