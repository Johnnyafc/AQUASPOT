// lib/features/tickets/presentation/services/generador_pdf_evaluacion.dart
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../domain/entities/ticket_entity.dart';
import '../../domain/entities/actividad_evaluacion_seleccionada.dart';

class GeneradorPdfEvaluacion {
  static const List<String> _meses = [
    'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
    'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'
  ];

  static String _fechaEspanol(DateTime dt) {
    final dia = dt.day;
    final mes = _meses[dt.month - 1];
    final anio = dt.year;
    return '$dia de $mes de $anio';
  }

  static Future<Uint8List> generarPdf({
    required TicketEntity ticket,
    required List<ActividadEvaluacionSeleccionada> actividadesSeleccionadas,
    required String nombreTecnico,
  }) async {
    final pdf = pw.Document();

    // Cargar Logo institucional
    pw.MemoryImage? logoImage;
    try {
      final logoBytes = await rootBundle.load('assets/images/logo.png');
      logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());
    } catch (_) {}

    // Cargar todas las imágenes de evidencias por actividad
    final Map<int, List<pw.MemoryImage>> mapaFotos = {};
    for (int i = 0; i < actividadesSeleccionadas.length; i++) {
      final act = actividadesSeleccionadas[i];
      final fotosCargadas = <pw.MemoryImage>[];
      for (final xfile in act.fotos) {
        try {
          final b = await xfile.readAsBytes();
          fotosCargadas.add(pw.MemoryImage(b));
        } catch (_) {}
      }
      mapaFotos[i] = fotosCargadas;
    }

    final fechaStr = _fechaEspanol(DateTime.now());

    // =========================================================================
    // 📄 PÁGINA 1: CABECERA Y PRIMEROS HALLAZGOS
    // =========================================================================
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                if (logoImage != null)
                  pw.Image(logoImage, width: 140)
                else
                  pw.Text('AQUASPOT', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 18, color: PdfColors.blue800)),
                pw.Text(
                  'REVISIÓN TÉCNICA #${ticket.id}',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16, color: PdfColors.blue800),
                ),
              ],
            ),
            pw.Divider(thickness: 1.5, color: PdfColors.blue800),
            pw.SizedBox(height: 8),
          ],
        ),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Página ${context.pageNumber} de ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey),
          ),
        ),
        build: (context) => [
          // Metadatos de Cabecera
          pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
            ),
            child: pw.Column(
              children: [
                _buildFilaDato('FECHA:', fechaStr),
                _buildFilaDato('INGRESO:', ticket.id),
                _buildFilaDato('CLIENTE:', ticket.clienteId.isNotEmpty ? ticket.clienteId : 'NO REGISTRADO'),
                _buildFilaDato('ACTIVIDAD:', 'MANTENIMIENTO'),
                _buildFilaDato('EQUIPO:', ticket.equipo.name.toUpperCase()),
                _buildFilaDato('MARCA:', ticket.marca.isNotEmpty ? ticket.marca : 'IOSA'),
                _buildFilaDato('N° SERIE:', ticket.numeroSerie ?? 'S/N'),
              ],
            ),
          ),
          pw.SizedBox(height: 16),

          // Título de HALLAZGOS
          pw.Text(
            'HALLAZGOS',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14, color: PdfColors.blue900),
          ),
          pw.SizedBox(height: 10),

          // Lista de Hallazgos con fotos
          ...actividadesSeleccionadas.asMap().entries.map((entry) {
            final idx = entry.key;
            final actSel = entry.value;
            final fotos = mapaFotos[idx] ?? [];

            return pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 16),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    '${idx + 1}. ${actSel.observacion.isNotEmpty ? actSel.observacion : actSel.actividad.nombre}',
                    style: const pw.TextStyle(fontSize: 11, lineSpacing: 2),
                  ),
                  if (fotos.isNotEmpty) ...[
                    pw.SizedBox(height: 8),
                    pw.Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: fotos.map((foto) {
                        return pw.Container(
                          width: 220,
                          height: 150,
                          decoration: pw.BoxDecoration(
                            border: pw.Border.all(color: PdfColors.grey300),
                            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                          ),
                          child: pw.ClipRRect(
                            horizontalRadius: 4,
                            verticalRadius: 4,
                            child: pw.Image(foto, fit: pw.BoxFit.cover),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            );
          }),

          pw.SizedBox(height: 16),
          pw.Divider(thickness: 1, color: PdfColors.grey400),
          pw.SizedBox(height: 8),

          // Sección ACTIVIDADES A REALIZAR
          pw.Text(
            'ACTIVIDADES A REALIZAR',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14, color: PdfColors.blue900),
          ),
          pw.SizedBox(height: 10),

          ...actividadesSeleccionadas.asMap().entries.map((entry) {
            final idx = entry.key;
            final actSel = entry.value;
            final textoIncluye = actSel.textoIncluyeDinamico;
            return pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 10),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    '${idx + 1}  ${actSel.actividad.nombre.toUpperCase()}',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
                  ),
                  if (textoIncluye.isNotEmpty)
                    pw.Padding(
                      padding: const pw.EdgeInsets.only(top: 2, left: 16),
                      child: pw.Text(
                        textoIncluye,
                        style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey800),
                      ),
                    ),
                ],
              ),
            );
          }),

          pw.SizedBox(height: 30),

          // Firma de Cierre
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Cordialmente,', style: const pw.TextStyle(fontSize: 11)),
              pw.SizedBox(height: 4),
              pw.Text(
                nombreTecnico.isNotEmpty ? nombreTecnico : 'Técnico de Servicio',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
              ),
              pw.Text('AQUASPOT', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, color: PdfColors.blue800)),
            ],
          ),
        ],
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildFilaDato(String label, String valor) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 100,
            child: pw.Text(label, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.grey700)),
          ),
          pw.Expanded(
            child: pw.Text(valor, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.black)),
          ),
        ],
      ),
    );
  }
}
