import '../repositories/ticket_repository.dart';

class EscucharEstadoExcelUseCase {
  final ITicketRepository repository;

  EscucharEstadoExcelUseCase(this.repository);

  // Usamos 'call' para que la clase actúe como una función (Callable class)
  Stream<String?> call(String ticketId) {
    return repository.escucharEstadoProcesamientoExcel(ticketId);
  }
}