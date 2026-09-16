// lib/features/tickets/presentation/services/generador_excel_evaluacion.dart
import 'dart:typed_data';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xlsio;
import '../../domain/entities/ticket_entity.dart';
import '../../domain/entities/actividad_evaluacion_seleccionada.dart';
import '../../../../features/catalogo/domain/entities/item_catalogo_entity.dart';

class GeneradorExcelEvaluacion {
  static Uint8List generarExcel({
    required TicketEntity ticket,
    required List<ActividadEvaluacionSeleccionada> actividadesSeleccionadas,
  }) {
    final xlsio.Workbook workbook = xlsio.Workbook(2);

    // =========================================================================
    // 📄 HOJA 1: MATERIAL
    // =========================================================================
    final xlsio.Worksheet sheetMaterial = workbook.worksheets[0];
    sheetMaterial.name = 'MATERIAL';

    // Estilos Base
    sheetMaterial.getRangeByName('A1:M1').cellStyle.bold = true;
    sheetMaterial.getRangeByName('A1:M1').cellStyle.fontSize = 14;

    // Encabezado principal
    sheetMaterial.getRangeByName('C1').setText('SOLICITUD DE MATERIALES');
    sheetMaterial.getRangeByName('C1').cellStyle.bold = true;

    // Metadatos del ticket
    sheetMaterial.getRangeByName('A2').setText('REVISIÓN TÉCNICA:');
    sheetMaterial.getRangeByName('B2').setText(ticket.id);
    sheetMaterial.getRangeByName('D2').setText('FECHA:');
    final fecha = DateTime.now();
    sheetMaterial.getRangeByName('E2').setText('${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year}');

    sheetMaterial.getRangeByName('A3').setText('SERIE:');
    sheetMaterial.getRangeByName('B3').setText(ticket.numeroSerie ?? 'S/N');
    sheetMaterial.getRangeByName('D3').setText('EQUIPO:');
    sheetMaterial.getRangeByName('E3').setText(ticket.equipo.name.toUpperCase());

    sheetMaterial.getRangeByName('A4').setText('PROYECTO:');
    sheetMaterial.getRangeByName('B4').setText(ticket.campamento.isNotEmpty ? ticket.campamento : ticket.clienteId);
    sheetMaterial.getRangeByName('D4').setText('CARGO:');
    sheetMaterial.getRangeByName('E4').setText('CONSUMO SERVICIOS DE MANTENIMIENTO TALLER');

    sheetMaterial.getRangeByName('A5').setText('CENTRO DE COSTO:');
    sheetMaterial.getRangeByName('B5').setText('REPARACIÓN CLIENTE');
    sheetMaterial.getRangeByName('D5').setText('CONSUMO/TRANSFERENCIA:');
    sheetMaterial.getRangeByName('E5').setText('CONSUMO');

    sheetMaterial.getRangeByName('A6').setText('PARTES Y REPUESTOS REQUERIDOS');
    sheetMaterial.getRangeByName('A6').cellStyle.bold = true;

    // Encabezados de Tabla de Materiales Internos (Taller/Bodega)
    sheetMaterial.getRangeByName('A7').setText('ITEM');
    sheetMaterial.getRangeByName('B7').setText('CODIGO SISTEMA');
    sheetMaterial.getRangeByName('C7').setText('DESCRIPCION ITEM');
    sheetMaterial.getRangeByName('F7').setText('UN/MED.');
    sheetMaterial.getRangeByName('G7').setText('CANTIDAD');
    sheetMaterial.getRangeByName('A7:G7').cellStyle.bold = true;
    sheetMaterial.getRangeByName('G8').setText('Requerido');
    sheetMaterial.getRangeByName('H8').setText('Entregado');
    sheetMaterial.getRangeByName('G8:H8').cellStyle.bold = true;

    // Encabezados de Tabla Comercial (Cols J-M)
    sheetMaterial.getRangeByName('J8').setText('PROPUESTA COMERCIAL');
    sheetMaterial.getRangeByName('J8:M8').cellStyle.bold = true;
    sheetMaterial.getRangeByName('J7').setText('CODIGO');
    sheetMaterial.getRangeByName('K7').setText('DESCRIPCION');
    sheetMaterial.getRangeByName('L7').setText('UNIDAD');
    sheetMaterial.getRangeByName('M7').setText('CANTIDAD');
    sheetMaterial.getRangeByName('J7:M7').cellStyle.bold = true;

    // 🔄 1. CONSOLIDACIÓN DE REPUESTOS INTERNOS (Sumar cantidades para códigos repetidos)
    final Map<String, ItemCatalogoEntity> mapaInternos = {};
    for (final actSel in actividadesSeleccionadas) {
      for (final it in actSel.itemsInternos) {
        if (it.cantidad <= 0) continue;
        final cod = it.codigo.trim().toUpperCase();
        final key = cod.isNotEmpty ? cod : it.descripcion.trim().toUpperCase();
        if (mapaInternos.containsKey(key)) {
          final anterior = mapaInternos[key]!;
          mapaInternos[key] = anterior.copyWith(cantidad: anterior.cantidad + it.cantidad);
        } else {
          mapaInternos[key] = it;
        }
      }
    }

    // 🔄 2. CONSOLIDACIÓN DE ÍTEMS COMERCIALES
    final Map<String, ItemCatalogoEntity> mapaComerciales = {};
    double totalHorasHombre = 0.0;

    for (final actSel in actividadesSeleccionadas) {
      totalHorasHombre += actSel.horasHombre;
      for (final it in actSel.itemsComerciales) {
        if (it.cantidad <= 0) continue;
        final cod = it.codigo.trim().toUpperCase();
        final key = cod.isNotEmpty ? cod : it.descripcion.trim().toUpperCase();
        if (mapaComerciales.containsKey(key)) {
          final anterior = mapaComerciales[key]!;
          mapaComerciales[key] = anterior.copyWith(cantidad: anterior.cantidad + it.cantidad);
        } else {
          mapaComerciales[key] = it;
        }
      }
    }

    // Llenar tabla de Materiales Internos
    int rowInternos = 9;
    int itemNum = 1;
    for (final it in mapaInternos.values) {
      sheetMaterial.getRangeByName('A$rowInternos').setNumber(itemNum.toDouble());
      sheetMaterial.getRangeByName('B$rowInternos').setText(it.codigo);
      sheetMaterial.getRangeByName('C$rowInternos').setText(it.descripcion);
      sheetMaterial.getRangeByName('F$rowInternos').setText(it.unidad);
      sheetMaterial.getRangeByName('G$rowInternos').setNumber(it.cantidad);
      itemNum++;
      rowInternos++;
    }

    // Llenar tabla Comercial
    int rowComercial = 9;
    for (final it in mapaComerciales.values) {
      sheetMaterial.getRangeByName('J$rowComercial').setText(it.codigo);
      sheetMaterial.getRangeByName('K$rowComercial').setText(it.descripcion);
      sheetMaterial.getRangeByName('L$rowComercial').setText(it.unidad);
      sheetMaterial.getRangeByName('M$rowComercial').setNumber(it.cantidad);
      rowComercial++;
    }

    // Fila final de Mano de Obra en la propuesta comercial
    sheetMaterial.getRangeByName('K$rowComercial').setText('MANO DE OBRA');
    sheetMaterial.getRangeByName('K$rowComercial').cellStyle.bold = true;
    sheetMaterial.getRangeByName('L$rowComercial').setText('HH');
    sheetMaterial.getRangeByName('M$rowComercial').setNumber(totalHorasHombre);
    sheetMaterial.getRangeByName('M$rowComercial').cellStyle.bold = true;

    // Firmas al pie
    final int rowFirmas = (rowInternos > rowComercial ? rowInternos : rowComercial) + 3;
    sheetMaterial.getRangeByName('B$rowFirmas').setText('ENTREGUE CONFORME\nBODEGA');
    sheetMaterial.getRangeByName('F$rowFirmas').setText('RECIBI CONFORME');
    sheetMaterial.getRangeByName('B${rowFirmas + 1}').setText('NOMBRE:');
    sheetMaterial.getRangeByName('F${rowFirmas + 1}').setText('NOMBRE:');

    // Auto-ajuste de columnas principales
    sheetMaterial.autoFitColumn(1);
    sheetMaterial.autoFitColumn(2);
    sheetMaterial.autoFitColumn(3);
    sheetMaterial.autoFitColumn(6);
    sheetMaterial.autoFitColumn(7);
    sheetMaterial.autoFitColumn(10);
    sheetMaterial.autoFitColumn(11);

    // =========================================================================
    // 📄 HOJA 2: ACTIVIDADES
    // =========================================================================
    final xlsio.Worksheet sheetActividades = workbook.worksheets[1];
    sheetActividades.name = 'ACTIVIDADES';

    sheetActividades.getRangeByName('A1').setText('ITEM');
    sheetActividades.getRangeByName('B1').setText('DESCRIPCIÓN');
    sheetActividades.getRangeByName('A1:B1').cellStyle.bold = true;

    int rowAct = 2;
    int numAct = 1;
    for (final actSel in actividadesSeleccionadas) {
      sheetActividades.getRangeByName('A$rowAct').setNumber(numAct.toDouble());
      sheetActividades.getRangeByName('B$rowAct').setText(actSel.actividad.nombre);
      sheetActividades.getRangeByName('A$rowAct:B$rowAct').cellStyle.bold = true;
      rowAct++;

      final textoIncluye = actSel.textoIncluyeDinamico;
      if (textoIncluye.isNotEmpty) {
        sheetActividades.getRangeByName('B$rowAct').setText(textoIncluye);
        sheetActividades.getRangeByName('B$rowAct').cellStyle.italic = true;
        rowAct++;
      }
      numAct++;
    }

    sheetActividades.autoFitColumn(1);
    sheetActividades.autoFitColumn(2);

    // Guardar en memoria y retornar bytes
    final List<int> bytes = workbook.saveAsStream();
    workbook.dispose();
    return Uint8List.fromList(bytes);
  }
}
