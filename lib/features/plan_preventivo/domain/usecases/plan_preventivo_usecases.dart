// lib/features/plan_preventivo/domain/usecases/plan_preventivo_usecases.dart

import 'package:dartz/dartz.dart';
import '../../../../core/enum/rol_usuario.dart';
import '../../../../core/errors/failures.dart';
import '../../../tickets/domain/entities/mantenimiento_interno_entity.dart';
import '../entities/actividad_preventiva_entity.dart';
import '../repositories/plan_preventivo_repository.dart';
import '../services/plan_preventivo_service.dart';

class ObtenerPlanPreventivoUseCase {
  final PlanPreventivoRepository repository;
  ObtenerPlanPreventivoUseCase(this.repository);

  Future<Either<Failure, List<ActividadPreventivaEntity>>> call(TipoActivoMantenimiento tipo) =>
      repository.obtenerPorMaquina(tipo);
}

/// Valida (PlanPreventivoService) y guarda; solo supervisor y admin.
class GuardarActividadPreventivaUseCase {
  final PlanPreventivoRepository repository;
  GuardarActividadPreventivaUseCase(this.repository);

  Future<Either<Failure, ActividadPreventivaEntity>> call(
    ActividadPreventivaEntity actividad, {
    required String usuarioNombre,
    required RolUsuario rol,
  }) async {
    if (!PlanPreventivoService.puedeAdministrar(rol)) {
      return const Left(ValidationFailure('Solo un supervisor o administrador puede modificar el Plan Preventivo.'));
    }
    final errores = PlanPreventivoService.validar(actividad);
    if (errores.isNotEmpty) return Left(ValidationFailure(errores.join('\n')));
    return repository.guardar(PlanPreventivoService.paraGuardar(actividad, usuarioNombre: usuarioNombre));
  }
}

class DesactivarActividadPreventivaUseCase {
  final PlanPreventivoRepository repository;
  DesactivarActividadPreventivaUseCase(this.repository);

  Future<Either<Failure, void>> call(
    ActividadPreventivaEntity actividad, {
    required String usuarioNombre,
    required RolUsuario rol,
  }) async {
    if (!PlanPreventivoService.puedeAdministrar(rol)) {
      return const Left(ValidationFailure('Solo un supervisor o administrador puede modificar el Plan Preventivo.'));
    }
    if (actividad.id.isEmpty) return const Left(ValidationFailure('La actividad aún no está guardada.'));
    return repository.desactivar(actividad.id, usuarioNombre: usuarioNombre);
  }
}
