// test/fallas_por_parte_test.dart
//
// Dashboard → "Fallas por parte": agrupación de las fallas diagnosticadas
// por parte (Categoría → Parte → Falla), filtro por categoría y "Sin parte";
// categorías, razones del problema y filtro por equipo (un pastel por equipo);
// "Fallas más frecuentes" con la categoría y la parte de cada falla;
// filtro de Garantías y Detalle por la categoría / parte elegidas.

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

  test('9. Razones: estándar y escritas a mano, cada una con su nombre; sin contar dos veces por falla', () {
    final r = S.agruparRazones([
      f('Mecánico', 'Motor', 'A', ticket: 'T1', razones: ['deficiencias de mantenimiento ', 'Operación incorrecta']),
      f('Mecánico', 'Motor', 'B', ticket: 'T2', razones: ['Deficiencias de mantenimiento']),
      f('Hidráulico', 'Sistema', 'C', ticket: 'T3', razones: ['se cayó', 'Lo golpearon']),
      f('Hidráulico', 'Sistema', 'E', ticket: 'T5', razones: ['  Se   Cayó ', 'se cayó']),
      f('Hidráulico', 'Sistema', 'D', ticket: 'T4'),
    ]);
    // De la más marcada a la menos (empates por nombre).
    expect(r.map((x) => x.etiqueta), ['Deficiencias de mantenimiento', 'Se cayó', 'Lo golpearon', 'Operación incorrecta']);
    final seCayo = r[1];
    expect(seCayo.valor, 2); // escrita distinto en C y E; repetida en E cuenta una vez
    expect(seCayo.fallas, 2);
    expect(r.first.conteoDetalle, {'Mecánico': 2});
  });

  test('9b. Muchas razones escritas a mano: las de una sola marca se juntan en "Otras razones"', () {
    final r = S.agruparRazones([
      f('Mecánico', 'Motor', 'A', razones: ['Golpe', 'Óxido', 'Arena', 'Sal', 'Calor', 'Lluvia']),
      f('Mecánico', 'Motor', 'B', razones: ['Golpe']),
    ]);
    expect(r.map((x) => x.etiqueta), ['Golpe', 'Otras razones'], reason: '"Otras razones" siempre al final');
    expect(r.last.valor, 5);
    expect(S.etiquetaRazon('  OPERACIÓN   incorrecta '), 'Operación incorrecta');
    expect(S.etiquetaRazon('   '), '');
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

  test('12. Fallas más frecuentes: cuenta por categoría › parte › falla y ordena', () {
    final r = S.agruparFallas([
      f('Mecánico', 'Motor diésel', 'Fuga de aceite', ticket: 'T1'),
      f('Mecánico', 'motor diésel ', 'fuga de aceite', ticket: 'T2'),
      f('Mecánico', 'Bomba hidráulica', 'Fuga de aceite', ticket: 'T3'),
      f('Hidráulico', '', 'Motor hidráulico dañado', ticket: 'T4'),
      f('', 'Motor', 'Sin categoría'),
    ]);
    expect(r.length, 3);
    expect(r.first.falla, 'Fuga de aceite');
    expect(r.first.parte, 'Motor diésel');
    expect(r.first.veces, 2);
    // Misma falla en otra parte = otra fila; empates por nombre de la falla.
    expect(r.map((x) => '${x.categoria} › ${x.parte} › ${x.falla}').skip(1), [
      'Mecánico › Bomba hidráulica › Fuga de aceite',
      'Hidráulico › ${S.sinParte} › Motor hidráulico dañado',
    ]);
    expect(r.last.esSinParte, isTrue);
  });

  group('13. Filtro por falla para Garantías y Detalle', () {
    final fallas = [
      f('Mecánico', 'Motor diésel', 'Fuga de aceite', ticket: 'T1'),
      f('Mecánico', 'Bomba', 'Pérdida de presión', ticket: 'T2'),
      f('Mecánico', 'Motor diésel', 'Sobrecalentamiento', ticket: 'T2'),
      f('Hidráulico', '', 'Fuga por retenedor', ticket: 'T3'),
    ];

    test('ticketsCon: tickets con al menos una falla de la categoría / parte', () {
      expect(S.ticketsCon(fallas, claveCategoria: 'mecánico'), {'T1', 'T2'});
      expect(S.ticketsCon(fallas, claveCategoria: 'mecánico', claveParte: S.clave('Mecánico', 'Bomba')), {'T2'});
      expect(S.ticketsCon(fallas, claveCategoria: 'hidráulico', claveParte: S.clave('Hidráulico', '')), {'T3'});
    });

    test('seleccionVigente: etiqueta y descarta lo que ya no existe', () {
      final soloCat = S.seleccionVigente(fallas, claveCategoria: 'mecánico');
      expect(soloCat.etiqueta, 'Mecánico');
      expect(soloCat.claveParte, isNull);

      final conParte = S.seleccionVigente(fallas,
          claveCategoria: 'mecánico', claveParte: S.clave('Mecánico', 'Motor diésel'));
      expect(conParte.etiqueta, 'Mecánico › Motor diésel');

      // Parte que no existe: queda solo la categoría.
      final parteVieja = S.seleccionVigente(fallas, claveCategoria: 'mecánico', claveParte: 'mecánico|turbo');
      expect(parteVieja.claveParte, isNull);
      expect(parteVieja.etiqueta, 'Mecánico');

      // Categoría que no existe (o nada elegido): sin filtro.
      expect(S.seleccionVigente(fallas, claveCategoria: 'software').etiqueta, isNull);
      expect(S.seleccionVigente(fallas).claveCategoria, isNull);
    });
  });
}
