import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:image/image.dart' as img; // ✅ Paquete 'image' para compresión
import '../../features/tickets/domain/entities/ticket_entity.dart';

class PdfService {
  
  Future<Uint8List> generateActaRecepcion({
    required TicketEntity ticket,
    required String tipoRequerimiento,
    // Eliminamos 'descripcion' porque no se usaba
    required List<XFile> evidencias, 
  }) async {
    final pdf = pw.Document();
    final List<pw.MemoryImage> imagenesProcesadas = [];

    // ⚙️ PROCESAMIENTO Y COMPRESIÓN DE IMÁGENES (Prevención de OOM)
    for (var file in evidencias) {
      // Validación más segura usando mimeType si está disponible
      if (file.mimeType?.startsWith('video/') ?? false) continue;
      
      // Fallback para extensiones en móvil (evitando web paths ciegamente)
      final pathLower = file.path.toLowerCase();
      if (pathLower.endsWith('.mp4') || pathLower.endsWith('.mov')) continue;

      try {
        final Uint8List rawBytes = await file.readAsBytes();
        
        // Redimensionamos la imagen para que el PDF no pese una tonelada
        // Esto requiere el paquete 'image' en tu pubspec.yaml
        final img.Image? decodedImage = img.decodeImage(rawBytes);
        if (decodedImage != null) {
          final img.Image resizedImage = img.copyResize(decodedImage, width: 800); // Ancho estándar para A4
          final Uint8List compressedBytes = img.encodeJpg(resizedImage, quality: 75);
          
          imagenesProcesadas.add(pw.MemoryImage(compressedBytes));
        }
      } catch (e) {
        // En un log de telemetría real registraríamos esto
        print('Error procesando evidencia visual: $e');
      }
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (pw.Context context) => _buildHeader(ticket),
        footer: (pw.Context context) => _buildFooter(context),
        build: (pw.Context context) {
          return [
            pw.SizedBox(height: 20),
            
            _buildGridSection("DATOS DEL CLIENTE", {
              "Razón Social / Cliente": ticket.clienteId,
              "Persona que entrega": ticket.nombreContacto,
              "Teléfono de Contacto": ticket.telefonoContacto ?? 'N/A',
              "Lugar de recepción": ticket.sede.name.toUpperCase(),
            }),
            pw.SizedBox(height: 15),
            
            _buildGridSection("ESPECIFICACIONES DEL EQUIPO", {
              "Tipo de Equipo": ticket.equipo.name.toUpperCase(),
              "Número de Serie": ticket.numeroSerie ?? 'No registrado',
            }),
            pw.SizedBox(height: 15),
            
            _buildGridSection("INSPECCIÓN TÉCNICA", {
              "Tipo de Requerimiento": tipoRequerimiento,
              // ✅ La Entidad ya viene procesada desde el Mapper/BLoC. Cero lógica aquí.
              "Falla Reportada (Cliente)": ticket.fallaReportada, 
              "Notas de Recepción (Físico)": ticket.notasRecepcion ?? 'N/A',
            }),

            pw.SizedBox(height: 20),

            if (imagenesProcesadas.isNotEmpty) ...[
              pw.Text("EVIDENCIA FOTOGRÁFICA", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              _buildEvidenciasVisuales(imagenesProcesadas),
            ],

            pw.SizedBox(height: 40),
            _buildSignatureBlock(),
          ];
        },
      ),
    );
    return pdf.save();
  }
  // --- SUBRUTINAS ---

  // (Mantenemos _buildHeader, _buildGridSection, _buildSignatureBlock y _buildFooter igual que antes)
  

  
  pw.Widget _buildHeader(TicketEntity ticket) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey700, width: 1),
      columnWidths: {
        0: const pw.FlexColumnWidth(1),
        1: const pw.FlexColumnWidth(2.5),
        2: const pw.FlexColumnWidth(1.2),
      },
      children: [
        pw.TableRow(
          children: [
            pw.Container(
              height: 60, padding: const pw.EdgeInsets.all(8), alignment: pw.Alignment.center,
              child: pw.Text('LOGO EMPRESA', style: const pw.TextStyle(color: PdfColors.grey500, fontSize: 10)),
            ),
            pw.Container(
              height: 60, alignment: pw.Alignment.center,
              child: pw.Text('ACTA DE RECEPCIÓN\nY SERVICIO TÉCNICO', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            ),
            pw.Container(
              height: 60, padding: const pw.EdgeInsets.all(6),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start, mainAxisAlignment: pw.MainAxisAlignment.center,
                children: [
                  pw.Text('CÓDIGO: FR-ST-01', style: const pw.TextStyle(fontSize: 8)),
                  pw.SizedBox(height: 4),
                  pw.Text('TICKET: ${ticket.id}', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 4),
                  pw.Text('FECHA: ${DateTime.now().toString().substring(0, 10)}', style: const pw.TextStyle(fontSize: 8)),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildGridSection(String title, Map<String, String> data) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          width: double.infinity, padding: const pw.EdgeInsets.all(6),
          decoration: const pw.BoxDecoration(color: PdfColors.grey300),
          child: pw.Text(title, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
        ),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
          columnWidths: { 0: const pw.FlexColumnWidth(1), 1: const pw.FlexColumnWidth(2) },
          children: data.entries.map((entry) {
            return pw.TableRow(
              children: [
                pw.Container(padding: const pw.EdgeInsets.all(6), color: PdfColors.grey100, child: pw.Text(entry.key, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))),
                pw.Container(padding: const pw.EdgeInsets.all(6), child: pw.Text(entry.value, style: const pw.TextStyle(fontSize: 9))),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }

  // ✅ NUEVO: Subrutina para pintar las fotos como un rack industrial
  pw.Widget _buildEvidenciasVisuales(List<pw.MemoryImage> imagenes) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          width: double.infinity, padding: const pw.EdgeInsets.all(6),
          decoration: const pw.BoxDecoration(color: PdfColors.grey300),
          child: pw.Text("REGISTRO FOTOGRÁFICO DE RECEPCIÓN", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
        ),
        pw.SizedBox(height: 10),
        // pw.Wrap permite que las imágenes se acomoden automáticamente en filas y columnas
        pw.Wrap(
          spacing: 10,
          runSpacing: 10,
          children: imagenes.map((img) {
            return pw.Container(
              width: 150, // Ancho fijo para mantener simetría
              height: 150, // Alto fijo
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey500, width: 1),
              ),
              child: pw.Image(img, fit: pw.BoxFit.cover),
            );
          }).toList(),
        ),
      ],
    );
  }

  pw.Widget _buildSignatureBlock() {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
      children: [
        pw.Column(children: [pw.Container(width: 150, height: 1, color: PdfColors.black), pw.SizedBox(height: 4), pw.Text('Firma del Cliente', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)), pw.Text('Acepta condiciones de recepción', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700))]),
        pw.Column(children: [pw.Container(width: 150, height: 1, color: PdfColors.black), pw.SizedBox(height: 4), pw.Text('Firma Técnico Responsable', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)), pw.Text('Control de Calidad', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700))]),
      ],
    );
  }

  pw.Widget _buildFooter(pw.Context context) {
    return pw.Container(alignment: pw.Alignment.centerRight, margin: const pw.EdgeInsets.only(top: 10), child: pw.Text('Página ${context.pageNumber} de ${context.pagesCount}', style: const pw.TextStyle(color: PdfColors.grey, fontSize: 8)));
  }
}