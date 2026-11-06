// lib/features/tickets/presentation/services/generador_pdf_mantenimiento.dart
//
// 📄 Orden de trabajo (informe técnico) de un MANTENIMIENTO INTERNO (mismo estilo que el de
// reparación, sin datos de cliente y sin la NOTA de daños ocultos): datos
// del mantenimiento, ACTIVIDADES A REALIZAR (cada una con su "Incluye", su
// observación y sus fotos) y firma. Solo da formato: los datos, el "Incluye"
// y la firma salen de EvaluacionMantenimientoService.

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

          // Actividades a realizar: cada una con sus repuestos, la observación
          // del técnico y las fotos que subió en esa actividad.
          _titulo('ACTIVIDADES A REALIZAR'),
          for (var i = 0; i < actividades.length; i++) ..._actividad(i + 1, actividades[i]),
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

  /// Una actividad como varios bloques (nombre e "Incluye", observación y
  /// una fila de 2 fotos por bloque): así el PDF puede pasar a la página
  /// siguiente entre filas, aunque la actividad tenga muchas fotos.
  static List<pw.Widget> _actividad(int numero, ActividadMantenimiento a) {
    final incluye = _S.textoIncluye(a);
    final observacion = a.observacion.trim();
    return [
      pw.Padding(
        padding: const pw.EdgeInsets.only(top: 4),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('$numero  ${a.nombre.toUpperCase()}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
            if (incluye.isNotEmpty)
              pw.Padding(
                padding: const pw.EdgeInsets.only(top: 2, left: 16),
                child: pw.Text(incluye, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey800)),
              ),
            if (observacion.isNotEmpty)
              pw.Padding(
                padding: const pw.EdgeInsets.only(top: 3, left: 16),
                child: pw.RichText(
                  text: pw.TextSpan(children: [
                    pw.TextSpan(text: 'Observación: ', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                    pw.TextSpan(text: observacion, style: const pw.TextStyle(fontSize: 10)),
                  ]),
                ),
              ),
          ],
        ),
      ),
      for (var j = 0; j < a.fotos.length; j += 2)
        pw.Padding(
          padding: const pw.EdgeInsets.only(top: 8, left: 16),
          child: pw.Row(children: [
            for (final foto in a.fotos.skip(j).take(2))
              pw.Padding(
                padding: const pw.EdgeInsets.only(right: 12),
                child: pw.Container(
                  width: 220,
                  height: 150,
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                  ),
                  child: pw.Center(child: pw.Image(pw.MemoryImage(foto.bytes), fit: pw.BoxFit.contain)),
                ),
              ),
          ]),
        ),
      pw.SizedBox(height: 14),
    ];
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
