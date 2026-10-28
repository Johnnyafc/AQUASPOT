// lib/features/plan_preventivo/domain/repositories/plan_preventivo_repository.dart

import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../../tickets/domain/entities/mantenimiento_interno_entity.dart';
import '../entities/actividad_preventiva_entity.dart';

abstract class PlanPreventivoRepository {
  /// Todas las actividades de la máquina (también las desactivadas, para no
  /// repetir códigos).
  Future<Either<Failure, List<ActividadPreventivaEntity>>> obtenerPorMaquina(TipoActivoMantenimiento tipo);

  /// Crea o actualiza (por máquina + código). Devuelve la guardada (con id).
  Future<Either<Failure, ActividadPreventivaEntity>> guardar(ActividadPreventivaEntity actividad);

  /// La oculta sin borrarla (activo = false).
  Future<Either<Failure, void>> desactivar(String id, {required String usuarioNombre});
}
