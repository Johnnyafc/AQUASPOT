import 'package:aquaspot_postventa/core/enum/ticket_enums.dart';
import 'package:aquaspot_postventa/core/errors/failures.dart';
import 'package:aquaspot_postventa/features/tickets/domain/entities/ticket_entity.dart';
import 'package:aquaspot_postventa/features/tickets/domain/repositories/ticket_repository.dart';
import 'package:dartz/dartz.dart';

class AceptarProformaComercialUseCase {
  final ITicketRepository repository;

  AceptarProformaComercialUseCase(this.repository);

  // Este motor recibe el ticket actual, inyecta las órdenes y cambia el estado
  Future<Either<Failure, TicketEntity>> call({
    required TicketEntity ticket,
    required List<String> ordenesVentaUrls,
    required List<String> ordenesCompraUrls,
  }) async {
    
    final ticketActualizado = ticket.copyWith(
      codigoOrdenVenta: ordenesVentaUrls,
      codigoOrdenCompra: ordenesCompraUrls,
      estadoActual: EstadoTicket.aprobacionComercial, // 🔀 Lo manda al paralelismo
      isCostosCompletado: false, // Cerramos válvulas por seguridad
      isComprasCompletado: false,
    );

    return await repository.actualizarTicket(ticketActualizado);
  }
}