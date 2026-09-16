import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:xml/xml.dart';
import '../models/item_inventario_model.dart';

class ParserExcelStockService {
  static List<ItemInventarioModel> parsearExcelOBytes(Uint8List bytes) {
    if (bytes.length > 4 &&
        bytes[0] == 0x50 &&
        bytes[1] == 0x4B &&
        bytes[2] == 0x03 &&
        bytes[3] == 0x04) {
      return _parsearXlsx(bytes);
    } else {
      return _parsearCsv(bytes);
    }
  }

  static List<ItemInventarioModel> _parsearXlsx(Uint8List bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);

    // 1. Cargar Shared Strings
    final sharedStrings = <String>[];
    final sharedStringsFile = archive.findFile('xl/sharedStrings.xml');
    if (sharedStringsFile != null) {
      final xmlDoc = XmlDocument.parse(
        utf8.decode(sharedStringsFile.content as List<int>, allowMalformed: true),
      );
      for (final si in xmlDoc.findAllElements('si')) {
        final textElements = si.findAllElements('t');
        final buffer = StringBuffer();
        for (final t in textElements) {
          buffer.write(t.innerText);
        }
        sharedStrings.add(buffer.toString().trim());
      }
    }

    // 2. Encontrar la hoja con mayor cantidad de celdas (compatible con reportes multicapa como JasperReports)
    XmlDocument? bestSheetXml;
    int maxCells = 0;

    for (final f in archive.files) {
      if (f.name.startsWith('xl/worksheets/sheet') && f.name.endsWith('.xml')) {
        try {
          final doc = XmlDocument.parse(
            utf8.decode(f.content as List<int>, allowMalformed: true),
          );
          final cellCount = doc.findAllElements('c').length;
          if (cellCount > maxCells) {
            maxCells = cellCount;
            bestSheetXml = doc;
          }
        } catch (_) {}
      }
    }

    if (bestSheetXml == null) return [];

    final rows = bestSheetXml.findAllElements('row');
    if (rows.isEmpty) return [];

    int colCodigo = -1;
    int colDesc = -1;
    int colUnd = -1;
    int colStock = -1;
    int colUbic = -1;
    bool cabeceraDetectada = false;

    String? almacenGeneral;
    String categoriaActual = '';
    final items = <ItemInventarioModel>[];

    for (final row in rows) {
      final cellMap = <int, String>{};
      for (final c in row.findElements('c')) {
        final rAttr = c.getAttribute('r') ?? '';
        final colIndex = _extraerIndiceColumna(rAttr);
        final type = c.getAttribute('t');

        String valor = '';
        if (type == 's') {
          final vElement = c.findElements('v').firstOrNull;
          if (vElement != null) {
            final idx = int.tryParse(vElement.innerText) ?? -1;
            if (idx >= 0 && idx < sharedStrings.length) {
              valor = sharedStrings[idx];
            }
          }
        } else if (type == 'inlineStr') {
          valor = c.findAllElements('t').map((e) => e.innerText).join('');
        } else {
          final vElement = c.findElements('v').firstOrNull;
          if (vElement != null) {
            valor = vElement.innerText;
          }
        }
        cellMap[colIndex] = valor.trim();
      }

      if (cellMap.isEmpty) continue;

      // Detección de almacén en las primeras filas (ej: Almacén: BODEGA MATRIZ SJTCORP)
      for (final entry in cellMap.entries) {
        final txt = entry.value.toLowerCase();
        if (txt.contains('almac')) {
          if (cellMap.containsKey(entry.key + 1)) {
            almacenGeneral = cellMap[entry.key + 1];
          }
        }
      }

      // Detección robusta de cabecera: Requiere código Y descripción en la misma fila
      if (!cabeceraDetectada) {
        bool tieneCod = false;
        bool tieneDesc = false;
        int tempCod = -1;
        int tempDesc = -1;
        int tempUnd = -1;
        int tempStock = -1;
        int tempUbic = -1;

        for (final entry in cellMap.entries) {
          final txt = entry.value.toLowerCase();
          if (txt.contains('cód') ||
              txt.contains('cod') ||
              txt.contains('item') ||
              txt.contains('ref')) {
            tempCod = entry.key;
            tieneCod = true;
          } else if (txt.contains('producto') ||
              txt.contains('descrip') ||
              txt.contains('nombre') ||
              txt.contains('repuesto') ||
              txt.contains('material') ||
              txt.contains('articulo')) {
            tempDesc = entry.key;
            tieneDesc = true;
          } else if (txt.contains('um') ||
              txt.contains('und') ||
              txt.contains('unidad') ||
              txt.contains('medida')) {
            tempUnd = entry.key;
          } else if (txt.contains('existente') ||
              txt.contains('existencia') ||
              txt.contains('stock') ||
              txt.contains('cant') ||
              txt.contains('saldo') ||
              txt.contains('dispon')) {
            tempStock = entry.key;
          } else if (txt.contains('ubic') ||
              txt.contains('bodega') ||
              txt.contains('estante') ||
              txt.contains('percha')) {
            tempUbic = entry.key;
          }
        }

        if (tieneCod && tieneDesc) {
          colCodigo = tempCod;
          colDesc = tempDesc;
          colUnd = tempUnd;
          colStock = tempStock;
          colUbic = tempUbic;
          cabeceraDetectada = true;
          continue;
        }
      }

      if (!cabeceraDetectada) continue;

      final codigo = cellMap[colCodigo] ?? '';
      final desc = cellMap[colDesc] ?? '';

      // Fila vacía o sin datos
      if (codigo.isEmpty && desc.isEmpty) continue;

      // Fila de encabezado de categoría/sección (ej: 'ELECTRICOS', 'BOMBA DE TRANSFERENCIA')
      // donde solo la columna código tiene texto pero descripción y stock están vacíos
      if (codigo.isNotEmpty && desc.isEmpty) {
        categoriaActual = codigo;
        continue;
      }

      final und = (colUnd != -1 && cellMap[colUnd]?.isNotEmpty == true)
          ? cellMap[colUnd]!
          : 'UNIDAD';

      final stockStr = (colStock != -1 && cellMap[colStock] != null)
          ? cellMap[colStock]!.replaceAll(',', '.')
          : '0';
      final stock = double.tryParse(stockStr) ?? 0.0;

      // Construcción de ubicación enriquecida
      String? ubicacionFinal = (colUbic != -1 && cellMap[colUbic]?.isNotEmpty == true)
          ? cellMap[colUbic]
          : almacenGeneral;

      if (categoriaActual.isNotEmpty) {
        if (ubicacionFinal != null && ubicacionFinal.isNotEmpty) {
          ubicacionFinal = '$ubicacionFinal - $categoriaActual';
        } else {
          ubicacionFinal = categoriaActual;
        }
      }

      items.add(ItemInventarioModel(
        codigo: codigo,
        descripcion: desc,
        unidad: und.isEmpty ? 'UNIDAD' : und,
        stockDisponible: stock,
        ubicacion: ubicacionFinal,
        fechaActualizacion: DateTime.now(),
      ));
    }

    return items;
  }

  static List<ItemInventarioModel> _parsearCsv(Uint8List bytes) {
    String content;
    try {
      content = utf8.decode(bytes);
    } catch (_) {
      content = latin1.decode(bytes);
    }

    final lines = content.split(RegExp(r'\r?\n'));
    if (lines.isEmpty) return [];

    final firstLine = lines.first;
    String sep = ',';
    if (firstLine.contains(';') && !firstLine.contains(',')) {
      sep = ';';
    } else if (firstLine.contains('\t')) {
      sep = '\t';
    }

    int colCodigo = -1;
    int colDesc = -1;
    int colUnd = -1;
    int colStock = -1;
    int colUbic = -1;
    bool cabeceraDetectada = false;

    String? almacenGeneral;
    String categoriaActual = '';
    final items = <ItemInventarioModel>[];

    for (final line in lines) {
      if (line.trim().isEmpty) continue;
      final parts =
          line.split(sep).map((p) => p.replaceAll('"', '').trim()).toList();
      if (parts.isEmpty) continue;

      for (int i = 0; i < parts.length; i++) {
        final txt = parts[i].toLowerCase();
        if (txt.contains('almac') && i + 1 < parts.length) {
          almacenGeneral = parts[i + 1];
        }
      }

      if (!cabeceraDetectada) {
        bool tieneCod = false;
        bool tieneDesc = false;
        int tempCod = -1;
        int tempDesc = -1;
        int tempUnd = -1;
        int tempStock = -1;
        int tempUbic = -1;

        for (int i = 0; i < parts.length; i++) {
          final txt = parts[i].toLowerCase();
          if (txt.contains('cód') ||
              txt.contains('cod') ||
              txt.contains('item') ||
              txt.contains('ref')) {
            tempCod = i;
            tieneCod = true;
          } else if (txt.contains('producto') ||
              txt.contains('descrip') ||
              txt.contains('nombre') ||
              txt.contains('repuesto') ||
              txt.contains('material')) {
            tempDesc = i;
            tieneDesc = true;
          } else if (txt.contains('um') ||
              txt.contains('und') ||
              txt.contains('unidad') ||
              txt.contains('medida')) {
            tempUnd = i;
          } else if (txt.contains('existente') ||
              txt.contains('existencia') ||
              txt.contains('stock') ||
              txt.contains('cant') ||
              txt.contains('saldo')) {
            tempStock = i;
          } else if (txt.contains('ubic') ||
              txt.contains('bodega') ||
              txt.contains('estante')) {
            tempUbic = i;
          }
        }

        if (tieneCod && tieneDesc) {
          colCodigo = tempCod;
          colDesc = tempDesc;
          colUnd = tempUnd;
          colStock = tempStock;
          colUbic = tempUbic;
          cabeceraDetectada = true;
          continue;
        }
      }

      if (!cabeceraDetectada) continue;

      final codigo = (colCodigo != -1 && colCodigo < parts.length)
          ? parts[colCodigo]
          : '';
      final desc = (colDesc != -1 && colDesc < parts.length)
          ? parts[colDesc]
          : '';

      if (codigo.isEmpty && desc.isEmpty) continue;

      if (codigo.isNotEmpty && desc.isEmpty) {
        categoriaActual = codigo;
        continue;
      }

      final und = (colUnd != -1 && colUnd < parts.length && parts[colUnd].isNotEmpty)
          ? parts[colUnd]
          : 'UNIDAD';
      final stockStr = (colStock != -1 && colStock < parts.length)
          ? parts[colStock].replaceAll(',', '.')
          : '0';
      final stock = double.tryParse(stockStr) ?? 0.0;

      String? ubicacionFinal = (colUbic != -1 && colUbic < parts.length && parts[colUbic].isNotEmpty)
          ? parts[colUbic]
          : almacenGeneral;

      if (categoriaActual.isNotEmpty) {
        if (ubicacionFinal != null && ubicacionFinal.isNotEmpty) {
          ubicacionFinal = '$ubicacionFinal - $categoriaActual';
        } else {
          ubicacionFinal = categoriaActual;
        }
      }

      items.add(ItemInventarioModel(
        codigo: codigo,
        descripcion: desc,
        unidad: und.isEmpty ? 'UNIDAD' : und,
        stockDisponible: stock,
        ubicacion: ubicacionFinal,
        fechaActualizacion: DateTime.now(),
      ));
    }

    return items;
  }

  static int _extraerIndiceColumna(String cellRef) {
    int col = 0;
    for (int i = 0; i < cellRef.length; i++) {
      final code = cellRef.codeUnitAt(i);
      if (code >= 65 && code <= 90) {
        col = col * 26 + (code - 64);
      } else {
        break;
      }
    }
    return col > 0 ? col - 1 : 0;
  }
}
