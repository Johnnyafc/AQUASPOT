import 'dart:typed_data';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xlsio;
import '../../domain/entities/ticket_entity.dart';
import '../../domain/entities/item_despacho_bodega_entity.dart';
import '../../domain/entities/registro_despacho_entity.dart';

enum ModoExcelDespacho {
  seleccionActual,  // Solo los repuestos validados y cantidades seleccionadas para descontar ahora
  faltantes,        // Solo los repuestos pendientes por despachar
  consolidadoTodos, // Todos los repuestos con estado general
}

class GeneradorExcelDespachoBodega {
  /// 1. EXCEL PARA BAJA EN SISTEMA ERP
  /// Basado en assets/documents/ARCHIVO PARA DAR DE BAJA EN SISTEMA.xlsx
  /// Estructura tabular de 5 columnas: CODIGO, DESCRIPCION, CANTIDAD, COSTO U, UNIDAD DE MEDIDA.
  /// Contiene ÚNICAMENTE los ítems y cantidades despachadas en esta salida parcial.
  static Uint8List generarExcelBajaERP({
    required TicketEntity ticket,
    List<DetalleItemDespachadoEntity>? itemsDespachados,
    List<ItemDespachoBodegaEntity>? items,
    Map<String, double>? cantidadesSeleccionadas,
  }) {
    final xlsio.Workbook workbook = xlsio.Workbook(1);
    final xlsio.Worksheet sheet = workbook.worksheets[0];
    sheet.name = 'BAJA_ERP';

    // Cabeceras exactas del formato ERP
    const headers = [
      'CODIGO',
      'DESCRIPCION',
      'CANTIDAD',
      ' COSTO U ',
      'UNIDAD DE MEDIDA',
    ];

    for (int col = 0; col < headers.length; col++) {
      final cell = sheet.getRangeByIndex(1, col + 1);
      cell.setText(headers[col]);
      cell.cellStyle.bold = true;
      cell.cellStyle.fontSize = 11;
      cell.cellStyle.backColor = '#D9E1F2'; // Azul claro profesional de oficina
      cell.cellStyle.hAlign = col == 1 ? xlsio.HAlignType.left : xlsio.HAlignType.center;
      cell.cellStyle.vAlign = xlsio.VAlignType.center;
    }

    int currentRow = 2;

    if (itemsDespachados != null && itemsDespachados.isNotEmpty) {
      for (final item in itemsDespachados) {
        if (item.cantidad <= 0) continue;
        sheet.getRangeByIndex(currentRow, 1).setText(item.codigo);
        sheet.getRangeByIndex(currentRow, 1).cellStyle.hAlign = xlsio.HAlignType.center;

        sheet.getRangeByIndex(currentRow, 2).setText(item.descripcion);
        sheet.getRangeByIndex(currentRow, 2).cellStyle.hAlign = xlsio.HAlignType.left;

        sheet.getRangeByIndex(currentRow, 3).setNumber(item.cantidad);
        sheet.getRangeByIndex(currentRow, 3).cellStyle.hAlign = xlsio.HAlignType.right;

        sheet.getRangeByIndex(currentRow, 4).setText(''); // COSTO U vacío para que el ERP lo asigne

        sheet.getRangeByIndex(currentRow, 5).setText(item.unidad.toUpperCase());
        sheet.getRangeByIndex(currentRow, 5).cellStyle.hAlign = xlsio.HAlignType.center;

        currentRow++;
      }
    } else if (items != null) {
      for (final item in items) {
        final double cant = cantidadesSeleccionadas?[item.codigo] ?? item.cantidadFaltante;
        if (cant <= 0) continue;

        sheet.getRangeByIndex(currentRow, 1).setText(item.codigo);
        sheet.getRangeByIndex(currentRow, 1).cellStyle.hAlign = xlsio.HAlignType.center;

        sheet.getRangeByIndex(currentRow, 2).setText(item.descripcion);
        sheet.getRangeByIndex(currentRow, 2).cellStyle.hAlign = xlsio.HAlignType.left;

        sheet.getRangeByIndex(currentRow, 3).setNumber(cant);
        sheet.getRangeByIndex(currentRow, 3).cellStyle.hAlign = xlsio.HAlignType.right;

        sheet.getRangeByIndex(currentRow, 4).setText('');

        sheet.getRangeByIndex(currentRow, 5).setText(item.unidad.toUpperCase());
        sheet.getRangeByIndex(currentRow, 5).cellStyle.hAlign = xlsio.HAlignType.center;

        currentRow++;
      }
    }

    // Autoajustar columnas
    for (int c = 1; c <= 5; c++) {
      sheet.autoFitColumn(c);
    }

    final List<int> bytes = workbook.saveAsStream();
    workbook.dispose();
    return Uint8List.fromList(bytes);
  }

  /// 2. FORMATO OFICIAL DE SOLICITUD DE MATERIALES
  /// Basado en assets/documents/FORMATO DE SOLICITUD DE MATERIALES.xls
  /// Incluye cabecera formal, centro de costos, proyecto, cargo, serie,
  /// listado de todos los repuestos diferenciando requeridos y faltantes, y firmas de responsabilidad.
  static Uint8List generarExcelSolicitudMateriales({
    required TicketEntity ticket,
    required List<ItemDespachoBodegaEntity> items,
    required Map<String, double> cantidadesDespachadasLote,
    required String nombreBodeguero,
    String? nombreTecnico,
  }) {
    final xlsio.Workbook workbook = xlsio.Workbook(1);
    final xlsio.Worksheet sheet = workbook.worksheets[0];
    sheet.name = 'SOLICITUD';

    // R0: Título principal
    sheet.getRangeByName('C1:H1').merge();
    final titleCell = sheet.getRangeByName('C1');
    titleCell.setText('SOLICITUD DE MATERIALES');
    titleCell.cellStyle.bold = true;
    titleCell.cellStyle.fontSize = 14;
    titleCell.cellStyle.hAlign = xlsio.HAlignType.center;
    titleCell.cellStyle.vAlign = xlsio.VAlignType.center;
    titleCell.cellStyle.backColor = '#005A9C';
    titleCell.cellStyle.fontColor = '#FFFFFF';

    // Formateo de fecha
    final fecha = DateTime.now();
    final fechaStr = '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year}';

    // R1: REVISIÓN TÉCNICA Y FECHA
    sheet.getRangeByName('A2').setText('REVISIÓN TÉCNICA:');
    sheet.getRangeByName('A2').cellStyle.bold = true;
    sheet.getRangeByName('B2:C2').merge();
    sheet.getRangeByName('B2').setText(ticket.id);

    sheet.getRangeByName('D2').setText('FECHA:');
    sheet.getRangeByName('D2').cellStyle.bold = true;
    sheet.getRangeByName('E2:H2').merge();
    sheet.getRangeByName('E2').setText(fechaStr);

    // R2: CENTRO DE COSTO Y EQUIPO
    sheet.getRangeByName('A3').setText('CENTRO DE COSTO:');
    sheet.getRangeByName('A3').cellStyle.bold = true;
    sheet.getRangeByName('B3:C3').merge();
    final centroCosto = (ticket.esGarantia == true)
        ? (ticket.numeroSerie ?? 'GARANTÍA')
        : 'Reparacion Cliente';
    sheet.getRangeByName('B3').setText(centroCosto);

    sheet.getRangeByName('D3').setText('EQUIPO:');
    sheet.getRangeByName('D3').cellStyle.bold = true;
    sheet.getRangeByName('E3:H3').merge();
    final String detalleStr = (ticket.equipoDetalle != null && ticket.equipoDetalle!.isNotEmpty)
        ? ' - ${ticket.equipoDetalle}'
        : '';
    final descEquipo = '${ticket.equipo.name.toUpperCase()}$detalleStr';
    sheet.getRangeByName('E3').setText(descEquipo);

    // R3: PROYECTO Y CARGO
    sheet.getRangeByName('A4').setText('PROYECTO:');
    sheet.getRangeByName('A4').cellStyle.bold = true;
    sheet.getRangeByName('B4:C4').merge();
    final proyecto = ticket.codigoProyecto != null && ticket.codigoProyecto!.isNotEmpty
        ? ticket.codigoProyecto!
        : (ticket.campamento.isNotEmpty ? ticket.campamento : 'SIN PROYECTO');
    sheet.getRangeByName('B4').setText(proyecto);

    sheet.getRangeByName('D4').setText('CARGO:');
    sheet.getRangeByName('D4').cellStyle.bold = true;
    sheet.getRangeByName('E4:H4').merge();
    sheet.getRangeByName('E4').setText('CONSUMO SERVICIOS');

    // R4: SERIE Y CONSUMO / TRANSFERENCIA
    sheet.getRangeByName('A5').setText('SERIE:');
    sheet.getRangeByName('A5').cellStyle.bold = true;
    sheet.getRangeByName('B5:C5').merge();
    sheet.getRangeByName('B5').setText(ticket.numeroSerie ?? 'S/N');

    sheet.getRangeByName('D5').setText('CONSUMO/TRANSFERENCIA:');
    sheet.getRangeByName('D5').cellStyle.bold = true;
    sheet.getRangeByName('E5:H5').merge();
    sheet.getRangeByName('E5').setText('CONSUMO INTERNO');

    // R5: Título de sección de repuestos
    sheet.getRangeByName('A6:H6').merge();
    final secCell = sheet.getRangeByName('A6');
    secCell.setText('PARTES Y REPUESTOS REQUERIDOS');
    secCell.cellStyle.bold = true;
    secCell.cellStyle.fontSize = 11;
    secCell.cellStyle.hAlign = xlsio.HAlignType.center;
    secCell.cellStyle.backColor = '#E0E0E0';

    // R6 & R7: Cabeceras de tabla combinadas
    // ITEM
    sheet.getRangeByName('A7:A8').merge();
    sheet.getRangeByName('A7').setText('ITEM');

    // CODIGO SISTEMA
    sheet.getRangeByName('B7:B8').merge();
    sheet.getRangeByName('B7').setText('CODIGO SISTEMA');

    // DESCRIPCION ITEM
    sheet.getRangeByName('C7:E8').merge();
    sheet.getRangeByName('C7').setText('DESCRIPCION ITEM');

    // UN/MED.
    sheet.getRangeByName('F7:F8').merge();
    sheet.getRangeByName('F7').setText('UN/MED.');

    // CANTIDAD (agrupa Requerido y Entregado)
    sheet.getRangeByName('G7:H7').merge();
    sheet.getRangeByName('G7').setText('CANTIDAD');

    sheet.getRangeByName('G8').setText('Requerido');
    sheet.getRangeByName('H8').setText('Entregado');

    final tableHeaderRange = sheet.getRangeByName('A7:H8');
    tableHeaderRange.cellStyle.bold = true;
    tableHeaderRange.cellStyle.backColor = '#CFD8DC';
    tableHeaderRange.cellStyle.hAlign = xlsio.HAlignType.center;
    tableHeaderRange.cellStyle.vAlign = xlsio.VAlignType.center;

    int currentRow = 9;
    int indexItem = 1;

    for (final item in items) {
      final double cantLote = cantidadesDespachadasLote[item.codigo] ?? 0.0;
      final bool esEntregado = cantLote > 0;

      // Col A: Nro
      sheet.getRangeByIndex(currentRow, 1).setNumber(indexItem.toDouble());
      sheet.getRangeByIndex(currentRow, 1).cellStyle.hAlign = xlsio.HAlignType.center;

      // Col B: Código
      sheet.getRangeByIndex(currentRow, 2).setText(item.codigo);
      sheet.getRangeByIndex(currentRow, 2).cellStyle.hAlign = xlsio.HAlignType.center;

      // Col C:E: Descripción con diferenciador claro de estado
      sheet.getRangeByName('C$currentRow:E$currentRow').merge();
      final tagEstado = esEntregado ? '[ENTREGADO EN ESTE LOTE]' : '[FALTANTE EN BODEGA]';
      sheet.getRangeByIndex(currentRow, 3).setText('${item.descripcion} $tagEstado');
      sheet.getRangeByIndex(currentRow, 3).cellStyle.hAlign = xlsio.HAlignType.left;

      // Col F: Unidad
      sheet.getRangeByIndex(currentRow, 6).setText(item.unidad.toUpperCase());
      sheet.getRangeByIndex(currentRow, 6).cellStyle.hAlign = xlsio.HAlignType.center;

      // Col G: Cantidad Requerida
      sheet.getRangeByIndex(currentRow, 7).setNumber(item.cantidadSolicitada);
      sheet.getRangeByIndex(currentRow, 7).cellStyle.hAlign = xlsio.HAlignType.right;

      // Col H: Cantidad Entregada en este lote
      sheet.getRangeByIndex(currentRow, 8).setNumber(cantLote);
      sheet.getRangeByIndex(currentRow, 8).cellStyle.hAlign = xlsio.HAlignType.right;
      sheet.getRangeByIndex(currentRow, 8).cellStyle.bold = true;

      // Diferenciación visual de color
      if (esEntregado) {
        sheet.getRangeByIndex(currentRow, 8).cellStyle.backColor = '#E8F5E9';
        sheet.getRangeByIndex(currentRow, 8).cellStyle.fontColor = '#2E7D32';
      } else {
        sheet.getRangeByIndex(currentRow, 8).cellStyle.backColor = '#FFF3E0';
        sheet.getRangeByIndex(currentRow, 8).cellStyle.fontColor = '#E65100';
      }

      currentRow++;
      indexItem++;
    }

    // Fila en blanco
    currentRow++;

    // Bloque de Firmas de Responsabilidad
    final int rowFirmas = currentRow;
    sheet.getRangeByName('B$rowFirmas:D$rowFirmas').merge();
    final celdaFirmaBodega = sheet.getRangeByName('B$rowFirmas');
    celdaFirmaBodega.setText('ENTREGUÉ CONFORME\nBODEGA');
    celdaFirmaBodega.cellStyle.bold = true;
    celdaFirmaBodega.cellStyle.hAlign = xlsio.HAlignType.center;

    sheet.getRangeByName('F$rowFirmas:H$rowFirmas').merge();
    final celdaFirmaRecibe = sheet.getRangeByName('F$rowFirmas');
    celdaFirmaRecibe.setText('RECIBÍ CONFORME\nTÉCNICO / RESPONSABLE');
    celdaFirmaRecibe.cellStyle.bold = true;
    celdaFirmaRecibe.cellStyle.hAlign = xlsio.HAlignType.center;

    currentRow++;
    final int rowNombres = currentRow;
    sheet.getRangeByName('B$rowNombres:D$rowNombres').merge();
    sheet.getRangeByName('B$rowNombres').setText('NOMBRE: $nombreBodeguero');

    sheet.getRangeByName('F$rowNombres:H$rowNombres').merge();
    sheet.getRangeByName('F$rowNombres').setText('NOMBRE: ${nombreTecnico ?? "___________________________"}');

    currentRow++;
    final int rowRaya = currentRow;
    sheet.getRangeByName('B$rowRaya:D$rowRaya').merge();
    sheet.getRangeByName('B$rowRaya').setText('FIRMA: ___________________________');

    sheet.getRangeByName('F$rowRaya:H$rowRaya').merge();
    sheet.getRangeByName('F$rowRaya').setText('FIRMA: ___________________________');

    // Autoajustar columnas
    for (int c = 1; c <= 8; c++) {
      sheet.autoFitColumn(c);
    }

    final List<int> bytes = workbook.saveAsStream();
    workbook.dispose();
    return Uint8List.fromList(bytes);
  }

  /// Método retrocompatible
  static Uint8List generarExcel({
    required TicketEntity ticket,
    required ModoExcelDespacho modo,
    required List<ItemDespachoBodegaEntity> items,
    Map<String, double>? cantidadesSeleccionadas,
    String? operadorBodega,
  }) {
    if (modo == ModoExcelDespacho.seleccionActual) {
      return generarExcelBajaERP(
        ticket: ticket,
        items: items,
        cantidadesSeleccionadas: cantidadesSeleccionadas,
      );
    }
    return generarExcelSolicitudMateriales(
      ticket: ticket,
      items: items,
      cantidadesDespachadasLote: cantidadesSeleccionadas ?? {},
      nombreBodeguero: operadorBodega ?? 'BODEGA CENTRAL',
    );
  }
}
