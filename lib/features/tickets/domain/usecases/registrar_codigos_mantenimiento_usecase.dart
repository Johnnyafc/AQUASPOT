// lib/features/tickets/domain/usecases/registrar_codigos_mantenimiento_usecase.dart
//
// 🧾 Costos registra el código oficial (y la descripción con la que lo creó
// en el ERP) de cada repuesto SIN CÓDIGO de un mantenimiento interno. En una
// sola transacción: los repuestos pasan a la lista de despacho de Bodega
// (Compras los valida), entran al inventario con stock 0 (si el código no
// existía) y, si el ticket esperaba en Costos, pasa a Compras. Las reglas
// están en CreacionCodigosMantenimientoService.

import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/ticket_entity.dart';
import '../repositories/ticket_repository.dart';
import '../services/creacion_codigos_mantenimiento_service.dart';

class RegistrarCodigosMantenimientoUseCase {
  final ITicketRepository repository;

  RegistrarCodigosMantenimientoUseCase(this.repository);

  Future<Either<Failure, TicketEntity>> call({
    required String ticketId,
    required List<CodigoCreadoMantenimiento> codigos,
    required String usuarioNombre,
    required String usuarioRol,
    DateTime? ahora,
  }) async {
    if (codigos.isEmpty || codigos.any((c) => c.codigo.trim().isEmpty || c.descripcion.trim().isEmpty)) {
      return const Left(ValidationFailure('Ingrese el código y la descripción de cada repuesto.'));
    }
    final claves = codigos.map((c) => c.codigo.trim().toUpperCase()).toList();
    if (claves.toSet().length != claves.length) {
      return const Left(ValidationFailure('Hay códigos repetidos: cada repuesto debe tener su propio código.'));
    }
    final momento = ahora ?? DateTime.now();
    return repository.actualizarMantenimientoEnTransaccion(
      ticketId: ticketId,
      aplicar: (actual) => CreacionCodigosMantenimientoService.aplicarCodigos(
        actual,
        codigos,
        usuarioNombre: usuarioNombre,
        usuarioRol: usuarioRol,
        ahora: momento,
      ),
    );
  }
}
