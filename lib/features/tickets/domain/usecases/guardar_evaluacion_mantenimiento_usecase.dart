// lib/features/tickets/domain/usecases/guardar_evaluacion_mantenimiento_usecase.dart
//
// Guarda la EVALUACIÓN TÉCNICA de un mantenimiento interno (actividades con
// sus fotos ya subidas) y pasa el ticket a Compras. Valida antes de escribir
// (EvaluacionMantenimientoService); en Caracol aparta el stock en la misma
// transacción, igual que en reparación.

import 'package:dartz/dartz.dart';
import '../../../../core/enum/rol_usuario.dart';
import '../../../../core/errors/failures.dart';
import '../entities/actividad_mantenimiento.dart';
import '../entities/ticket_entity.dart';
import '../repositories/ticket_repository.dart';
import '../services/evaluacion_mantenimiento_service.dart';

class GuardarEvaluacionMantenimientoUseCase {
  final ITicketRepository repository;

  GuardarEvaluacionMantenimientoUseCase(this.repository);

  Future<Either<Failure, TicketEntity>> call(
    TicketEntity ticket,
    List<ActividadMantenimiento> actividades, {
    required bool necesitaCompras,
    String? motivoNoCompras,
    required String usuarioNombre,
    required RolUsuario rol,
    DateTime? ahora,
  }) async {
    final errores = EvaluacionMantenimientoService.validar(actividades);
    if (errores.isNotEmpty) return Left(ValidationFailure(errores.join('\n')));

    final evaluado = EvaluacionMantenimientoService.construirTicketEvaluado(
      ticket,
      actividades,
      necesitaCompras: necesitaCompras,
      motivoNoCompras: motivoNoCompras,
      usuarioNombre: usuarioNombre,
      rol: rol,
      ahora: ahora ?? DateTime.now(),
    );

    if (!EvaluacionMantenimientoService.reservaStock(evaluado)) {
      return repository.actualizarTicket(evaluado);
    }
    final reserva = await repository.guardarEvaluacionTecnicaConReservaStock(
      ticket: evaluado,
      itemsAReservar: [
        for (final r in evaluado.evaluacionTecnica!.repuestosTaller) {'codigo': r.codigo, 'cantidad': r.cantidad},
      ],
    );
    return reserva.map((_) => evaluado);
  }
}
