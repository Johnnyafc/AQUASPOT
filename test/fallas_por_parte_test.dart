// test/fallas_por_parte_test.dart
//
// Dashboard → "Fallas por parte": agrupación de las fallas diagnosticadas
// por parte (Categoría → Parte → Falla), filtro por categoría y "Sin parte";
// categorías, razones del problema y filtro por equipo (un pastel por equipo).

import 'package:aquaspot_postventa/features/tickets/domain/services/fallas_por_parte_service.dart';
import 'package:flutter_test/flutter_test.dart';

typedef S = FallasPorParteService;

FallaParaParte f(
  String categoria,
  String parte,
  String falla, {
  String ticket = 'T1',
  String equipo = 'Cosechadora',
  List<String> razones = const [],
}) =>
    FallaParaParte(
      categoria: categoria,
      parte: parte,
      falla: falla,
      razones: razones,
      ticketId: ticket,
      equipo: equipo,
    );

void main() {
  test('1. Agrupa por parte y ordena de más a menos fallas', () {
    final r = S.agrupar([
      f('Mecánico', 'Motor diésel', 'Fuga de aceite', ticket: 'T1'),
      f('Mecánico', 'Motor diésel', 'Sobrecalentamiento', ticket: 'T2'),
      f('Mecánico', 'Bomba hidráulica', 'Pérdida de presión', ticket: 'T3'),
    ]);
    expect(r.map((p) => p.parte), ['Motor diésel', 'Bomba hidráulica']);
    expect(r.first.fallas, 2);
    expect(r.first.categoria, 'Mecánico');
  });

  test('2. La misma parte en dos categorías son partes distintas', () {
    final r = S.agrupar([
      f('Mecánico', 'Motor', 'A'),
      f('Eléctrico', 'Motor', 'B'),
    ]);
    expect(r.length, 2);
    expect(r.map((p) => p.clave).toSet(), {'mecánico|motor', 'eléctrico|motor'});
  });

  test('3. No distingue mayúsculas ni espacios y conserva el primer nombre', () {
    final r = S.agrupar([
      f('Mecánico', 'Motor diésel', 'A'),
      f(' mecánico ', 'MOTOR DIÉSEL ', 'B'),
    ]);
    expect(r.length, 1);
    expect(r.first.fallas, 2);
    expect(r.first.parte, 'Motor diésel');
  });

  test('4. Fallas sin parte se agrupan como "Sin parte" y van al final si empatan', () {
    final r = S.agrupar([
      f('Hidráulico', '', 'Fuga de aceite por retenedor'),
      f('Hidráulico', 'Sistema hidráulico', 'Motor hidráulico dañado'),
    ]);
    expect(r.map((p) => p.parte), ['Sistema hidráulico', S.sinParte]);
    expect(r.last.esSinParte, isTrue);
    expect(r.last.clave, S.clave('Hidráulico', ''));
  });

  test('5. Con claveCategoria solo cuenta las partes de esa categoría', () {
    final fallas = [
      f('Mecánico', 'Motor diésel', 'A'),
      f('Hidráulico', 'Sistema hidráulico', 'B'),
    ];
    final r = S.agrupar(fallas, claveCategoria: S.normalizar('Hidráulico'));
    expect(r.map((p) => p.parte), ['Sistema hidráulico']);
    expect(r.first.claveCategoria, 'hidráulico');
  });

  test('6. Ignora fallas sin categoría', () {
    final r = S.agrupar([f('', 'Motor', 'A'), f('Mecánico', 'Motor', 'B')]);
    expect(r.length, 1);
    expect(r.first.fallas, 1);
  });

  test('7. Tickets afectados por equipo sin repetir y fallas más comunes', () {
    final r = S.agrupar([
      f('Mecánico', 'Motor', 'Fuga', ticket: 'T1', equipo: 'Cosechadora'),
      f('Mecánico', 'Motor', 'Fuga', ticket: 'T1', equipo: 'Cosechadora'),
      f('Mecánico', 'Motor', 'Ruido', ticket: 'T2', equipo: 'Caracol'),
      f('Mecánico', 'Motor', 'Fuga', ticket: 'T3', equipo: 'Caracol'),
    ]).single;
    expect(r.fallas, 4);
    expect(r.ticketsPorEquipo['Cosechadora'], {'T1'});
    expect(r.ticketsPorEquipo['Caracol'], {'T2', 'T3'});
    expect(r.masComunes().first.key, 'Fuga');
    expect(r.masComunes().first.value, 3);
  });

  test('8. Categorías: cuenta fallas, ordena y conserva el primer nombre', () {
    final r = S.agruparCategorias([
      f('Mecánico', 'Motor', 'A'),
      f(' mecánico', 'Bomba', 'B'),
      f('Hidráulico', 'Sistema hidráulico', 'C'),
      f('', 'Motor', 'D'),
    ]);
    expect(r.map((c) => c.etiqueta), ['Mecánico', 'Hidráulico']);
    expect(r.first.valor, 2);
    expect(r.first.clave, 'mecánico');
  });

  test('9. Razones: estándar con su nombre, el resto como "Otras" y sin contar dos veces por falla', () {
    final r = S.agruparRazones([
      f('Mecánico', 'Motor', 'A', ticket: 'T1', razones: ['deficiencias de mantenimiento ', 'Operación incorrecta']),
      f('Mecánico', 'Motor', 'B', ticket: 'T2', razones: ['Deficiencias de mantenimiento']),
      f('Hidráulico', 'Sistema', 'C', ticket: 'T3', razones: ['Se cayó', 'Lo golpearon']),
      f('Hidráulico', 'Sistema', 'D', ticket: 'T4'),
    ]);
    expect(r.map((x) => x.etiqueta), ['Deficiencias de mantenimiento', S.otrasRazones, 'Operación incorrecta']);
    final otras = r[1];
    expect(otras.valor, 2); // dos marcas…
    expect(otras.fallas, 1); // …en una sola falla
    expect(r.first.conteoDetalle, {'Mecánico': 2});
  });

  test('10. Filtrar por equipo, categoría y parte', () {
    final fallas = [
      f('Mecánico', 'Motor diésel', 'A', equipo: 'Cosechadora'),
      f('Mecánico', 'Bomba', 'B', equipo: 'Cosechadora'),
      f('Mecánico', 'Motor diésel', 'C', equipo: 'Caracol'),
      f('Hidráulico', 'Sistema', 'D', equipo: 'Cosechadora'),
    ];
    expect(S.filtrar(fallas, equipo: 'Cosechadora').length, 3);
    expect(S.filtrar(fallas, claveCategoria: 'mecánico').length, 3);
    expect(S.filtrar(fallas, equipo: 'Cosechadora', claveParte: S.clave('Mecánico', 'Motor diésel')).map((x) => x.falla), ['A']);
    expect(S.filtrar(fallas).length, 4);
  });

  test('11. Equipos de los pasteles: los 3 base siempre y otros con datos al final', () {
    expect(S.equiposDe([]), ['Cosechadora', 'Contador', 'Caracol']);
    expect(S.equiposDe([f('Mecánico', 'Motor', 'A', equipo: 'Otros')]), ['Cosechadora', 'Contador', 'Caracol', 'Otros']);
  });
}
