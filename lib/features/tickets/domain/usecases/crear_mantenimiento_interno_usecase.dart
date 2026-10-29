// lib/features/tickets/domain/usecases/crear_mantenimiento_interno_usecase.dart
//
// Crea un requerimiento de MANTENIMIENTO INTERNO: vuelve a validar el
// formulario (contra el catálogo de series / placas leído) y crea el ticket
// (código OT-00001, ver CodigoRequerimientoService). Las fotos se suben
// después con SubirEvidenciaUseCase y se adjuntan con
// AdjuntarEvidenciasMantenimientoUseCase.

import 'package:dartz/dartz.dart';
import '../../../../core/enum/rol_usuario.dart';
import '../../../../core/errors/failures.dart';
import '../entities/ticket_entity.dart';
import '../repositories/ticket_repository.dart';
import '../services/formulario_mantenimiento_service.dart';

class CrearMantenimientoInternoUseCase {
  final ITicketRepository repository;

  CrearMantenimientoInternoUseCase(this.repository);

  Future<Either<Failure, TicketEntity>> call(
    DatosMantenimientoInterno datos, {
    required String usuarioNombre,
    required RolUsuario rol,
    DateTime? ahora,
    CatalogoActivos catalogo = FormularioMantenimientoService.catalogoPorDefecto,
  }) async {
    final momento = ahora ?? DateTime.now();
    final errores = FormularioMantenimientoService.validar(datos, ahora: momento, catalogo: catalogo);
    if (errores.isNotEmpty) return Left(ValidationFailure(errores.join('\n')));
    final ticket = FormularioMantenimientoService.construirTicket(
      datos,
      usuarioNombre: usuarioNombre,
      rol: rol,
      ahora: momento,
    );
    return repository.crearTicket(ticket);
  }
}
