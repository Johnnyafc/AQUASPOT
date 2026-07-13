import 'package:dartz/dartz.dart';
import 'package:file_picker/file_picker.dart';
import '../../../../core/errors/failures.dart';
import '../repositories/ticket_repository.dart';

class SubirDocumentoComercialUseCase {
  final ITicketRepository repository;

  SubirDocumentoComercialUseCase(this.repository);

  // 🔌 Recibe el ID, el archivo y una etiqueta ('cotizacion_pdf' o 'cotizacion_excel')
  Future<Either<Failure, String>> call(String ticketId, PlatformFile archivo, String tipoDocumento) async {
    return await repository.subirDocumentoComercial(ticketId, archivo, tipoDocumento);
  }
}