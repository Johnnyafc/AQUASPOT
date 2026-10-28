// lib/features/tickets/presentation/services/generador_excel_mantenimiento.dart
//
// 📊 Solicitud de materiales de un MANTENIMIENTO INTERNO (mismo formato que
// la de reparación, sin la propuesta comercial): hoja MATERIAL con TODOS
// los repuestos de todas las actividades (sumados; los no registrados como
// "SIN CÓDIGO") y hoja ACTIVIDADES. Solo da formato: los datos salen de
// EvaluacionMantenimientoService.

import 'dart:typed_data';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xlsio;
import '../../domain/entities/actividad_mantenimiento.dart';
import '../../domain/entities/mantenimiento_interno_entity.dart';
import '../../domain/entities/ticket_entity.dart';
import '../../domain/services/evaluacion_mantenimiento_service.dart';

typedef _S = EvaluacionMantenimientoService;

class GeneradorExcelMantenimiento {
  static Uint8List generar({
    required TicketEntity ticket,
    required List<ActividadMantenimiento> actividades,
    DateTime? fecha,
  }) {
    final libro = xlsio.Workbook(2);
    final hoja = libro.worksheets[0];
    hoja.name = 'MATERIAL';
    final f = fecha ?? DateTime.now();
    final m = ticket.mantenimientoInterno;
    final enc = _S.encabezadoSolicitud;

    hoja.getRangeByName('C1').setText('SOLICITUD DE MATERIALES');
    hoja.getRangeByName('C1').cellStyle
      ..bold = true
      ..fontSize = 14;

    void dato(String celdaEtiqueta, String etiqueta, String celdaValor, String valor) {
      hoja.getRangeByName(celdaEtiqueta).setText(etiqueta);
      hoja.getRangeByName(celdaEtiqueta).cellStyle.bold = true;
      hoja.getRangeByName(celdaValor).setText(valor);
    }

    dato('A2', 'ORDEN DE TRABAJO:', 'B2', ticket.id);
    dato('D2', 'FECHA:', 'E2', '${f.day.toString().padLeft(2, '0')}/${f.month.toString().padLeft(2, '0')}/${f.year}');
    dato('A3', m?.placa != null ? 'PLACA:' : 'SERIE:', 'B3', m?.placa ?? ticket.numeroSerie ?? 'S/N');
    dato('D3', 'EQUIPO:', 'E3', (m?.tipoActivo.etiqueta ?? ticket.equipo.name).toUpperCase());
    dato('D4', 'CARGO:', 'E4', enc.cargo);
    dato('A5', 'CENTRO DE COSTO:', 'B5', enc.centroCosto);
    dato('D5', 'CONSUMO/TRANSFERENCIA:', 'E5', 'CONSUMO');

    hoja.getRangeByName('A6').setText('PARTES Y REPUESTOS REQUERIDOS');
    hoja.getRangeByName('A6').cellStyle.bold = true;
    hoja.getRangeByName('A7').setText('ITEM');
    hoja.getRangeByName('B7').setText('CODIGO SISTEMA');
    hoja.getRangeByName('C7').setText('DESCRIPCION ITEM');
    hoja.getRangeByName('F7').setText('UN/MED.');
    hoja.getRangeByName('G7').setText('CANTIDAD');
    hoja.getRangeByName('G8').setText('Requerido');
    hoja.getRangeByName('H8').setText('Entregado');
    hoja.getRangeByName('A7:H8').cellStyle.bold = true;

    var fila = 9;
    var item = 1;
    for (final r in _S.consolidar(actividades)) {
      hoja.getRangeByName('A$fila').setNumber(item.toDouble());
      hoja.getRangeByName('B$fila').setText(_S.esSinCodigo(r) ? 'SIN CÓDIGO' : r.codigo);
      if (_S.esSinCodigo(r)) {
        hoja.getRangeByName('B$fila').cellStyle
          ..bold = true
          ..fontColor = '#E65100';
      }
      hoja.getRangeByName('C$fila').setText(r.descripcion);
      hoja.getRangeByName('F$fila').setText(r.unidad);
      hoja.getRangeByName('G$fila').setNumber(r.cantidad);
      item++;
      fila++;
    }
    final firmas = fila + 3;
    hoja.getRangeByName('B$firmas').setText('ENTREGUE CONFORME\nBODEGA');
    hoja.getRangeByName('F$firmas').setText('RECIBI CONFORME');
    hoja.getRangeByName('B${firmas + 1}').setText('NOMBRE:');
    hoja.getRangeByName('F${firmas + 1}').setText('NOMBRE:');
    for (final c in [1, 2, 3, 6, 7]) {
      hoja.autoFitColumn(c);
    }

    // Hoja 2: actividades con su "Incluye"
    final hojaAct = libro.worksheets[1];
    hojaAct.name = 'ACTIVIDADES';
    hojaAct.getRangeByName('A1').setText('ITEM');
    hojaAct.getRangeByName('B1').setText('DESCRIPCIÓN');
    hojaAct.getRangeByName('C1').setText('HH');
    hojaAct.getRangeByName('A1:C1').cellStyle.bold = true;
    var filaAct = 2;
    for (var i = 0; i < actividades.length; i++) {
      final a = actividades[i];
      hojaAct.getRangeByName('A$filaAct').setNumber(i + 1);
      hojaAct.getRangeByName('B$filaAct').setText('${a.codigo} — ${a.nombre}');
      hojaAct.getRangeByName('C$filaAct').setNumber(a.horasHombre);
      hojaAct.getRangeByName('A$filaAct:C$filaAct').cellStyle.bold = true;
      filaAct++;
      final incluye = _S.textoIncluye(a);
      if (incluye.isNotEmpty) {
        hojaAct.getRangeByName('B$filaAct').setText(incluye);
        hojaAct.getRangeByName('B$filaAct').cellStyle.italic = true;
        filaAct++;
      }
    }
    hojaAct.getRangeByName('B${filaAct + 1}').setText('TOTAL MANO DE OBRA (HH)');
    hojaAct.getRangeByName('C${filaAct + 1}').setNumber(_S.totalHoras(actividades));
    hojaAct.getRangeByName('B${filaAct + 1}:C${filaAct + 1}').cellStyle.bold = true;
    hojaAct.autoFitColumn(1);
    hojaAct.autoFitColumn(2);

    final bytes = libro.saveAsStream();
    libro.dispose();
    return Uint8List.fromList(bytes);
  }
}
