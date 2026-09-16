import 'dart:typed_data';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xlsio;
import '../../domain/entities/ticket_entity.dart';
import '../../domain/entities/item_despacho_bodega_entity.dart';

enum ModoExcelDespacho {
  seleccionActual,  // Solo los repuestos validados y cantidades seleccionadas para descontar ahora
  faltantes,        // Solo los repuestos pendientes por despachar
  consolidadoTodos, // Todos los repuestos con estado general
}

class GeneradorExcelDespachoBodega {
  static Uint8List generarExcel({
    required TicketEntity ticket,
    required ModoExcelDespacho modo,
    required List<ItemDespachoBodegaEntity> items,
    Map<String, double>? cantidadesSeleccionadas,
    String? operadorBodega,
  }) {
    final xlsio.Workbook workbook = xlsio.Workbook(1);
    final xlsio.Worksheet sheet = workbook.worksheets[0];
    sheet.name = 'DESPACHO_BODEGA';

    // 1. TÍTULO PRINCIPAL
    sheet.getRangeByName('A1:H1').merge();
    sheet.getRangeByName('A1').setText('AQUASPOT - VALE DE DESPACHO DE BODEGA');
    sheet.getRangeByName('A1').cellStyle.bold = true;
    sheet.getRangeByName('A1').cellStyle.fontSize = 14;
    sheet.getRangeByName('A1').cellStyle.backColor = '#005A9C';
    sheet.getRangeByName('A1').cellStyle.fontColor = '#FFFFFF';
    sheet.getRangeByName('A1').cellStyle.hAlign = xlsio.HAlignType.center;

    // 2. SUBTÍTULO CON MODO
    String subtitulo = '';
    switch (modo) {
      case ModoExcelDespacho.seleccionActual:
        subtitulo = 'REMISIÓN DE LOTE SELECCIONADO (REPUESTOS HABILITADOS POR COMPRAS PARA ERP)';
        break;
      case ModoExcelDespacho.faltantes:
        subtitulo = 'LISTADO DE REPUESTOS PENDIENTES POR DESPACHAR / COMPRAR';
        break;
      case ModoExcelDespacho.consolidadoTodos:
        subtitulo = 'CONSOLIDADO GENERAL DE MATERIALES E INSUMOS';
        break;
    }
    sheet.getRangeByName('A2:H2').merge();
    sheet.getRangeByName('A2').setText(subtitulo);
    sheet.getRangeByName('A2').cellStyle.bold = true;
    sheet.getRangeByName('A2').cellStyle.fontSize = 10;
    sheet.getRangeByName('A2').cellStyle.hAlign = xlsio.HAlignType.center;

    // 3. METADATOS DEL TICKET
    final fecha = DateTime.now();
    final fechaStr = '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year} ${fecha.hour.toString().padLeft(2, '0')}:${fecha.minute.toString().padLeft(2, '0')}';

    sheet.getRangeByName('A4').setText('TICKET ID:');
    sheet.getRangeByName('B4').setText(ticket.id);
    sheet.getRangeByName('D4').setText('FECHA:');
    sheet.getRangeByName('E4').setText(fechaStr);

    sheet.getRangeByName('A5').setText('EQUIPO:');
    sheet.getRangeByName('B5').setText(ticket.equipo.name.toUpperCase());
    sheet.getRangeByName('D5').setText('SERIE:');
    sheet.getRangeByName('E5').setText(ticket.numeroSerie ?? 'S/N');

    sheet.getRangeByName('A6').setText('CLIENTE / PROYECTO:');
    sheet.getRangeByName('B6').setText(ticket.campamento.isNotEmpty ? ticket.campamento : ticket.clienteId);
    sheet.getRangeByName('D6').setText('DESPACHADOR:');
    sheet.getRangeByName('E6').setText(operadorBodega ?? 'BODEGA CENTRAL');

    sheet.getRangeByName('A4:A6').cellStyle.bold = true;
    sheet.getRangeByName('D4:D6').cellStyle.bold = true;

    // 4. CABECERA DE TABLA
    int rowHeader = 8;
    sheet.getRangeByName('A$rowHeader').setText('N°');
    sheet.getRangeByName('B$rowHeader').setText('CÓDIGO');
    sheet.getRangeByName('C$rowHeader').setText('DESCRIPCIÓN DEL REPUESTO / INSUMO');
    sheet.getRangeByName('D$rowHeader').setText('UNIDAD');
    sheet.getRangeByName('E$rowHeader').setText('SOLICITADO');
    
    if (modo == ModoExcelDespacho.seleccionActual) {
      sheet.getRangeByName('F$rowHeader').setText('A DESPACHAR AHORA');
      sheet.getRangeByName('G$rowHeader').setText('RESTANTE DESPUÉS');
      sheet.getRangeByName('H$rowHeader').setText('ESTADO COMPRAS');
    } else if (modo == ModoExcelDespacho.faltantes) {
      sheet.getRangeByName('F$rowHeader').setText('YA DESPACHADO');
      sheet.getRangeByName('G$rowHeader').setText('CANTIDAD PENDIENTE');
      sheet.getRangeByName('H$rowHeader').setText('ESTADO COMPRAS');
    } else {
      sheet.getRangeByName('F$rowHeader').setText('TOTAL DESPACHADO');
      sheet.getRangeByName('G$rowHeader').setText('SALDO PENDIENTE');
      sheet.getRangeByName('H$rowHeader').setText('ESTADO COMPRAS');
    }

    final headerRange = sheet.getRangeByName('A$rowHeader:H$rowHeader');
    headerRange.cellStyle.bold = true;
    headerRange.cellStyle.backColor = '#E3F2FD';
    headerRange.cellStyle.hAlign = xlsio.HAlignType.center;

    // 5. FILAS DE DATOS
    int currentRow = 9;
    int indexNum = 1;

    for (final item in items) {
      double cantMostrar = 0.0;
      double saldoMostrar = 0.0;

      if (modo == ModoExcelDespacho.seleccionActual) {
        // En selección actual: solo ítems validados por compras
        if (!item.validadoPorCompras) continue;
        cantMostrar = cantidadesSeleccionadas?[item.codigo] ?? item.cantidadFaltante;
        if (cantMostrar <= 0) continue;
        saldoMostrar = (item.cantidadFaltante - cantMostrar).clamp(0.0, double.infinity);
      } else if (modo == ModoExcelDespacho.faltantes) {
        if (item.cantidadFaltante <= 0) continue;
        cantMostrar = item.cantidadDespachada;
        saldoMostrar = item.cantidadFaltante;
      } else {
        // Consolidado todos
        cantMostrar = item.cantidadDespachada;
        saldoMostrar = item.cantidadFaltante;
      }

      sheet.getRangeByName('A$currentRow').setNumber(indexNum.toDouble());
      sheet.getRangeByName('B$currentRow').setText(item.codigo);
      sheet.getRangeByName('C$currentRow').setText(item.descripcion);
      sheet.getRangeByName('D$currentRow').setText(item.unidad);
      sheet.getRangeByName('E$currentRow').setNumber(item.cantidadSolicitada);
      sheet.getRangeByName('F$currentRow').setNumber(cantMostrar);
      sheet.getRangeByName('G$currentRow').setNumber(saldoMostrar);
      sheet.getRangeByName('H$currentRow').setText(
        item.validadoPorCompras ? 'VALIDADO COMPRAS' : 'PENDIENTE COMPRAS',
      );

      sheet.getRangeByName('A$currentRow').cellStyle.hAlign = xlsio.HAlignType.center;
      sheet.getRangeByName('B$currentRow').cellStyle.hAlign = xlsio.HAlignType.center;
      sheet.getRangeByName('D$currentRow').cellStyle.hAlign = xlsio.HAlignType.center;
      sheet.getRangeByName('E$currentRow:G$currentRow').cellStyle.hAlign = xlsio.HAlignType.right;
      sheet.getRangeByName('H$currentRow').cellStyle.hAlign = xlsio.HAlignType.center;

      currentRow++;
      indexNum++;
    }

    // Auto-fit columnas
    for (int c = 1; c <= 8; c++) {
      sheet.autoFitColumn(c);
    }

    final List<int> bytes = workbook.saveAsStream();
    workbook.dispose();
    return Uint8List.fromList(bytes);
  }
}
