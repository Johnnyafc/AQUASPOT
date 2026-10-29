// lib/features/tickets/domain/usecases/obtener_catalogo_activos_mantenimiento_usecase.dart
//
// Series y placas para el formulario de MANTENIMIENTO INTERNO: lo guardado
// en Firestore combinado con el catálogo por defecto
// (FormularioMantenimientoService.combinarCatalogo).

import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../repositories/catalogo_activos_mantenimiento_repository.dart';
import '../services/formulario_mantenimiento_service.dart';

class ObtenerCatalogoActivosMantenimientoUseCase {
  final ICatalogoActivosMantenimientoRepository repository;

  ObtenerCatalogoActivosMantenimientoUseCase(this.repository);

  Future<Either<Failure, CatalogoActivos>> call() async =>
      (await repository.obtener()).map(FormularioMantenimientoService.combinarCatalogo);
}
