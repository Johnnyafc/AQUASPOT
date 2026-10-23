// test/borrador_evaluacion_codec_test.dart
//
// Borrador de la Evaluación Técnica (Caracol): las actividades se guardan y
// restauran completas (horas, hallazgo, repuestos editados y referencias
// de fotos), aunque el catálogo cambie después.

import 'dart:convert';

import 'package:aquaspot_postventa/features/catalogo/data/models/actividad_catalogo_model.dart';
import 'package:aquaspot_postventa/features/catalogo/domain/entities/actividad_catalogo_entity.dart';
import 'package:aquaspot_postventa/features/catalogo/domain/entities/item_catalogo_entity.dart';
import 'package:aquaspot_postventa/features/tickets/domain/entities/actividad_evaluacion_seleccionada.dart';
import 'package:aquaspot_postventa/features/tickets/domain/services/borrador_evaluacion_codec.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const actividad = ActividadCatalogoEntity(
    id: 'caracol_mo012',
    codigo: 'MO012',
    nombre: 'CAMBIO DE RODAMIENTOS',
    equipo: 'caracol',
    horasHombre: 4,
    esVariable: false,
    incluye: 'Incluye rodamientos',
    itemsInternos: [
      ItemCatalogoEntity(codigo: 'MEC000003', descripcion: 'ABRAZADERA', cantidad: 2),
      ItemCatalogoEntity(codigo: 'INS000065', descripcion: 'DISCO DE CORTE'),
    ],
    itemsComerciales: [ItemCatalogoEntity(codigo: 'MEC000003', descripcion: 'ABRAZADERA', cantidad: 2)],
  );

  test('ida y vuelta: horas, hallazgo, repuestos editados y fotos', () {
    final sel = ActividadEvaluacionSeleccionada(actividad: actividad, horasHombre: 6.5, observacion: 'Eje desgastado')
      ..itemsInternos = [const ItemCatalogoEntity(codigo: 'MEC000003', descripcion: 'ABRAZADERA', cantidad: 5)]
      ..itemsComerciales = [const ItemCatalogoEntity(codigo: 'MEC000003', descripcion: 'ABRAZADERA', cantidad: 5)];
    final fotos = [
      {'name': 'f1.jpg', 'size': 10, 'idb': 'evaluacion_REQ-1/1'},
      {'name': 'f2.jpg', 'path': '/tmp/f2.jpg', 'base64': 'AAAA'},
    ];

    // Pasa por JSON real, como en el almacenamiento local.
    final json = jsonDecode(jsonEncode(BorradorEvaluacionCodec.actividadToJson(sel, fotos: fotos)));
    final restaurada = BorradorEvaluacionCodec.actividadFromJson(json)!;

    // Actividad completa, no solo el código (se compara por datos: vuelve
    // como Model, que es otro tipo de objeto).
    expect(
      ActividadCatalogoModel.fromEntity(restaurada.actividad).toJson(),
      ActividadCatalogoModel.fromEntity(actividad).toJson(),
    );
    expect(restaurada.horasHombre, 6.5);
    expect(restaurada.observacion, 'Eje desgastado');
    expect(restaurada.itemsInternos.single.props, ['MEC000003', 'ABRAZADERA', 'UNIDAD', 5.0]);
    expect(restaurada.itemsComerciales.single.cantidad, 5);
    expect(restaurada.fotos, isEmpty); // las fotos las agrega la página
    expect(BorradorEvaluacionCodec.fotosDeJson(json), fotos);
  });

  test('repuestos quitados quedan quitados', () {
    final sel = ActividadEvaluacionSeleccionada(actividad: actividad, horasHombre: 4, observacion: '')
      ..itemsInternos = []
      ..itemsComerciales = [];
    final restaurada = BorradorEvaluacionCodec.actividadFromJson(
      jsonDecode(jsonEncode(BorradorEvaluacionCodec.actividadToJson(sel))),
    )!;
    expect(restaurada.itemsInternos, isEmpty);
    expect(restaurada.itemsComerciales, isEmpty);
  });

  test('JSON dañado no rompe la restauración', () {
    expect(BorradorEvaluacionCodec.actividadFromJson(null), isNull);
    expect(BorradorEvaluacionCodec.actividadFromJson({'actividad': 'x'}), isNull);
    expect(BorradorEvaluacionCodec.fotosDeJson({'fotos': 'x'}), isEmpty);
  });
}
