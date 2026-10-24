// test/tendencia_creacion_test.dart
//
// Dashboard → "Tickets creados por mes": desglose mes → semanas (lunes a
// domingo, recortadas al mes) → días.

import 'package:aquaspot_postventa/features/tickets/domain/services/tendencia_creacion_service.dart';
import 'package:flutter_test/flutter_test.dart';

typedef T = TendenciaCreacionService;

void main() {
  final fechas = [
    DateTime(2026, 9, 30, 18),
    DateTime(2026, 10, 1, 9),
    DateTime(2026, 10, 5, 23, 59),
    DateTime(2026, 10, 13, 8),
    DateTime(2026, 10, 13, 17),
    DateTime(2026, 10, 31, 12),
  ];

  test('1. Por mes: solo meses con tickets, ordenados', () {
    final r = T.porMes(fechas);
    expect(r.map((b) => b.inicio), [DateTime(2026, 9), DateTime(2026, 10)]);
    expect(r.map((b) => b.tickets), [1, 5]);
    expect(r.last.fin, DateTime(2026, 10, 31));
  });

  test('2. Semanas de octubre 2026 (el 1 es jueves): lunes a domingo, recortadas al mes', () {
    final r = T.semanasDelMes(fechas, DateTime(2026, 10));
    expect(r.map((b) => '${b.inicio.day}-${b.fin.day}'), ['1-4', '5-11', '12-18', '19-25', '26-31']);
    expect(r.map((b) => b.tickets), [1, 1, 2, 0, 1]);
    expect(r.every((b) => b.inicio.weekday == DateTime.monday || b.inicio.day == 1), isTrue);
  });

  test('3. Meses de 28 y 30 días y semanas que empiezan en lunes', () {
    // Febrero 2027: el 1 es lunes, 28 días → 4 semanas completas.
    expect(T.semanasDelMes(const [], DateTime(2027, 2)).map((b) => '${b.inicio.day}-${b.fin.day}'),
        ['1-7', '8-14', '15-21', '22-28']);
    // Noviembre 2026: el 1 es domingo → primera semana de un solo día.
    final nov = T.semanasDelMes(const [], DateTime(2026, 11));
    expect(nov.first.inicio, DateTime(2026, 11, 1));
    expect(nov.first.fin, DateTime(2026, 11, 1));
    expect(nov.last.fin, DateTime(2026, 11, 30));
  });

  test('4. Días de una semana, incluidos los que tienen 0', () {
    final r = T.dias(fechas, DateTime(2026, 10, 12), DateTime(2026, 10, 18));
    expect(r.length, 7);
    expect(r.map((b) => b.tickets), [0, 2, 0, 0, 0, 0, 0]);
    expect(r[1].inicio, DateTime(2026, 10, 13));
  });
}
