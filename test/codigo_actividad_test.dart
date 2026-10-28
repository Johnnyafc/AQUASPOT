// test/codigo_actividad_test.dart
//
// Código sugerido para una actividad nueva del Plan Maestro (botón "Agregar
// actividad al Plan Maestro" de la Evaluación Técnica).

import 'package:aquaspot_postventa/features/catalogo/domain/entities/actividad_catalogo_entity.dart';
import 'package:aquaspot_postventa/features/catalogo/domain/services/codigo_actividad_service.dart';
import 'package:flutter_test/flutter_test.dart';

ActividadCatalogoEntity act(String codigo) =>
    ActividadCatalogoEntity(id: codigo, codigo: codigo, nombre: 'X', equipo: 'cosechadora', esVariable: false);

void main() {
  test('Sin actividades: MO001', () {
    expect(CodigoActividadService.siguiente(const []), 'MO001');
  });

  test('Sigue el prefijo más usado y su ancho', () {
    expect(CodigoActividadService.siguiente([act('MO009'), act('mo010'), act('MO002')]), 'MO011');
    expect(CodigoActividadService.siguiente([act('MOC-1'), act('MO-07'), act('MO-12')]), 'MO-13');
  });

  test('Nunca repite un código existente y los ocupados van en MAYÚSCULAS', () {
    final lista = [act('MO1'), act('MO2'), act('mo3 ')];
    expect(CodigoActividadService.siguiente(lista), 'MO4');
    expect(CodigoActividadService.ocupados(lista), {'MO1', 'MO2', 'MO3'});
  });
}
