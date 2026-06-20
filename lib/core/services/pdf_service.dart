import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../features/tickets/domain/entities/ticket_entity.dart';

class PdfService {
  // Patrón Singleton opcional si prefieres no instanciarlo cada vez, 
  // pero mantengamos la inyección de dependencias limpia.
  
  Future<Uint8List> generateActaRecepcion({
    required TicketEntity ticket,
    required String tipoRequerimiento,
    required String descripcion,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Header(level: 0, text: 'ACTA DE RECEPCIÓN TÉCNICA'),
              
              _buildSection("Datos del Cliente", [
                "Cliente: ${ticket.clienteId}",
                "Quien entrega: ${ticket.nombreContacto}",
                "Celular: ${ticket.telefonoContacto}",
              ]),
              
              _buildSection("Detalles del Equipo", [
                "Tipo: ${ticket.equipo.name.toUpperCase()}",
                "Serie: ${ticket.numeroSerie ?? 'N/A'}",
              ]),
              
              _buildSection("Gestión Técnica", [
                "Requerimiento: $tipoRequerimiento",
                "Descripción: $descripcion",
              ]),
              
              _buildSection("Control y Registro", [
                "Fecha: ${DateTime.now().toString().substring(0, 16)}",
              ]),
            ],
          );
        },
      ),
    );
    return pdf.save();
  }

  // ✅ Método privado: Ahora pertenece al scope de la clase, no está suelto en el archivo.
  pw.Widget _buildSection(String title, List<String> content) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.only(top: 10),
          child: pw.Text(title, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        ),
        ...content.map((item) => pw.Text(item)),
        pw.SizedBox(height: 10),
      ],
    );
  }
}