// lib/features/tickets/presentation/services/generador_pdf_mantenimiento.dart
//
// 📄 Orden de trabajo (informe técnico) de un MANTENIMIENTO INTERNO (mismo estilo que el de
// reparación, sin datos de cliente y sin la NOTA de daños ocultos). Solo da
// formato: los datos, hallazgos, "Incluye" y firma salen de
// EvaluacionMantenimientoService.

import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../domain/entities/actividad_mantenimiento.dart';
import '../../domain/entities/ticket_entity.dart';
import '../../domain/services/evaluacion_mantenimiento_service.dart';

typedef _S = EvaluacionMantenimientoService;

class GeneradorPdfMantenimiento {
  static Future<Uint8List> generar({
    required TicketEntity ticket,
    required List<ActividadMantenimiento> actividades,
    required String nombreTecnico,
    DateTime? fecha,
  }) async {
    final pdf = pw.Document();

    pw.MemoryImage? logo;
    try {
      final bytes = await rootBundle.load('assets/images/logo.png');
      logo = pw.MemoryImage(bytes.buffer.asUint8List());
    } catch (_) {}

    final azul = PdfColors.blue800;
    final datos = _S.datosInforme(ticket, fecha: fecha ?? DateTime.now());

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                if (logo != null)
                  pw.Image(logo, width: 140)
                else
                  pw.Text('AQUASPOT', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 18, color: azul)),
                pw.Text('ORDEN DE TRABAJO #${ticket.id}',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16, color: azul)),
              ],
            ),
            pw.Divider(thickness: 1.5, color: azul),
            pw.SizedBox(height: 8),
          ],
        ),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text('Página ${context.pageNumber} de ${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey)),
        ),
        build: (context) => [
          // Datos del mantenimiento
          pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: const pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: pw.BorderRadius.all(pw.Radius.circular(4)),
            ),
            child: pw.Column(children: [for (final (etiqueta, valor) in datos) _fila(etiqueta, valor)]),
          ),
          pw.SizedBox(height: 16),

          // Hallazgos con fotos
          _titulo('HALLAZGOS'),
          for (var i = 0; i < actividades.length; i++)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 16),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('${i + 1}. ${_S.hallazgo(actividades[i])}', style: const pw.TextStyle(fontSize: 11, lineSpacing: 2)),
                  if (actividades[i].fotos.isNotEmpty) ...[
                    pw.SizedBox(height: 8),
                    pw.Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        for (final foto in actividades[i].fotos)
                          pw.Container(
                            width: 220,
                            height: 150,
                            decoration: pw.BoxDecoration(
                              border: pw.Border.all(color: PdfColors.grey300),
                              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                            ),
                            child: pw.Center(child: pw.Image(pw.MemoryImage(foto.bytes), fit: pw.BoxFit.contain)),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          pw.SizedBox(height: 8),
          pw.Divider(thickness: 1, color: PdfColors.grey400),
          pw.SizedBox(height: 8),

          // Actividades a realizar con todos sus repuestos
          _titulo('ACTIVIDADES A REALIZAR'),
          for (var i = 0; i < actividades.length; i++)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 10),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('${i + 1}  ${actividades[i].nombre.toUpperCase()}',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                  if (_S.textoIncluye(actividades[i]).isNotEmpty)
                    pw.Padding(
                      padding: const pw.EdgeInsets.only(top: 2, left: 16),
                      child: pw.Text(_S.textoIncluye(actividades[i]),
                          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey800)),
                    ),
                ],
              ),
            ),
          pw.SizedBox(height: 30),

          // Firma (sin la NOTA de daños ocultos: no hay cliente ni presupuesto)
          pw.Text('Cordialmente,', style: const pw.TextStyle(fontSize: 11)),
          pw.SizedBox(height: 4),
          pw.Text(_S.firma(nombreTecnico), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
          pw.Text('AQUASPOT', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, color: azul)),
        ],
      ),
    );
    return pdf.save();
  }

  static pw.Widget _titulo(String texto) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 10),
        child: pw.Text(texto, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14, color: PdfColors.blue900)),
      );

  static pw.Widget _fila(String etiqueta, String valor) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 2),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.SizedBox(
              width: 110,
              child: pw.Text(etiqueta, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.grey700)),
            ),
            pw.Expanded(child: pw.Text(valor, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
          ],
        ),
      );
}
