// test/prefijo_taller_y_mayusculas_test.dart
//
// "TALLER: INICIO DE TRABAJO…" (texto nuevo) se reconoce igual que el texto
// anterior en Tiempos por proceso, y la marca se guarda en MAYÚSCULAS.

import 'package:aquaspot_postventa/core/enum/marca_equipo.dart';
import 'package:aquaspot_postventa/features/tickets/domain/services/tiempos_por_proceso_service.dart';
import 'package:flutter_test/flutter_test.dart';

typedef T = TiemposPorProcesoService;

void main() {
  test('inicio de trabajo con y sin prefijo TALLER = "Antes de iniciar"', () {
    expect(T.subprocesoPorTexto(T.taller, 'INICIO DE TRABAJO EN CAMPO / TALLER'), T.subAntesDeIniciar);
    expect(T.subprocesoPorTexto(T.taller, 'TALLER: INICIO DE TRABAJO EN CAMPO / TALLER'), T.subAntesDeIniciar);
    expect(T.procesoPorTexto('TALLER: INICIO DE TRABAJO EN CAMPO / TALLER'), T.taller);
  });

  test('la marca se guarda en mayúsculas', () {
    expect(MarcaEquipo.aquaspot.valor, 'AQUASPOT');
    expect(MarcaEquipo.seinmex.valor, 'SEINMEX');
  });
}
