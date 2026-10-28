// test/incluye_actividad_test.dart
//
// "Incluye: …" de una actividad de la Evaluación Técnica: con la propuesta
// comercial (Caracol) o con los repuestos Taller / Bodega (Cosechadora y
// Contador, que no tienen propuesta comercial).

import 'package:aquaspot_postventa/features/catalogo/domain/entities/actividad_catalogo_entity.dart';
import 'package:aquaspot_postventa/features/catalogo/domain/entities/item_catalogo_entity.dart';
import 'package:aquaspot_postventa/features/tickets/domain/entities/actividad_evaluacion_seleccionada.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final act = ActividadEvaluacionSeleccionada(
    actividad: const ActividadCatalogoEntity(
      id: 'a',
      codigo: 'MO010',
      nombre: 'Cambio de rodamientos',
      equipo: 'cosechadora',
      esVariable: false,
      incluye: 'Incluye: texto del plan.',
    ),
    horasHombre: 2,
    observacion: '',
    itemsInternos: const [
      ItemCatalogoEntity(codigo: 'R-1', descripcion: 'RODAMIENTO 6205', cantidad: 2),
      ItemCatalogoEntity(codigo: 'G-1', descripcion: 'GRASA', unidad: 'GRAMOS', cantidad: 50),
    ],
    itemsComerciales: const [ItemCatalogoEntity(codigo: 'K-1', descripcion: 'KIT COMERCIAL', cantidad: 1)],
  );

  test('Con propuesta comercial: Incluye sale de los repuestos comerciales', () {
    expect(act.textoIncluye(sinPropuestaComercial: false), 'Incluye: 1 KIT COMERCIAL.');
  });

  test('Sin propuesta comercial: Incluye sale de los repuestos Taller / Bodega', () {
    expect(act.textoIncluye(sinPropuestaComercial: true), 'Incluye: 2 RODAMIENTO 6205, 50 GRAMOS DE GRASA.');
  });

  test('Sin repuestos: el texto del Plan Maestro', () {
    final sin = act.copyWith(itemsInternos: const [], itemsComerciales: const []);
    expect(sin.textoIncluye(sinPropuestaComercial: true), 'Incluye: texto del plan.');
  });
}
