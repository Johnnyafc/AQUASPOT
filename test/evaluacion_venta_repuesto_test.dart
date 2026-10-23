// test/evaluacion_venta_repuesto_test.dart
//
// Venta de Repuesto (arquitectura limpia): reglas del servicio de dominio
// EvaluacionVentaRepuestoService. Los use cases (con Compras en paralelo)
// están en venta_compras_en_paralelo_test.dart.

import 'package:aquaspot_postventa/features/tickets/domain/entities/ficha_creacion_repuesto_entity.dart';
import 'package:aquaspot_postventa/features/tickets/domain/entities/linea_repuesto_venta_entity.dart';
import 'package:aquaspot_postventa/features/tickets/domain/services/evaluacion_venta_repuesto_service.dart';
import 'package:flutter_test/flutter_test.dart';

const _conocida = LineaRepuestoVentaEntity(
  codigo: 'hid00059 ',
  descripcion: 'BOMBA',
  unidad: 'UND',
  cantidad: 2,
  stockDisponibleAlEvaluar: 0,
);

const _porDeterminar = LineaRepuestoVentaEntity(
  codigo: '',
  descripcion: '',
  unidad: '',
  cantidad: 1,
  porDeterminar: true,
  descripcionCliente: 'Polea motor Deutz',
);

void main() {
  final fecha = DateTime(2026, 10, 14, 9);

  group('EvaluacionVentaRepuestoService', () {
    test('conStockActual: toma el stock neto por código y no toca por determinar ni fuera del sistema', () {
      final fuera = _conocida.copyWith(existeEnSistema: false, stockDisponibleAlEvaluar: 0);
      final r = EvaluacionVentaRepuestoService.conStockActual(
        [_conocida, _porDeterminar, fuera],
        {'HID00059': 5},
      );
      expect(r[0].stockDisponibleAlEvaluar, 5); // clave normalizada (mayúsculas, sin espacios)
      expect(r[1], _porDeterminar);
      expect(r[2], fuera);
    });

    test('conStockActual: código que no está en el inventario → stock 0', () {
      final r = EvaluacionVentaRepuestoService.conStockActual([_conocida.copyWith(stockDisponibleAlEvaluar: 9)], {});
      expect(r.single.stockDisponibleAlEvaluar, 0);
    });

    test('definirDesdeInventario: queda como repuesto del sistema', () {
      final l = EvaluacionVentaRepuestoService.definirDesdeInventario(
        _porDeterminar,
        codigo: 'POL-01',
        descripcion: 'POLEA',
        unidad: 'UND',
        cantidad: 2,
        stockNeto: 3,
        definidoPor: 'SUP',
        definidoEn: fecha,
      );
      expect(l.porDeterminar, isFalse);
      expect(l.existeEnSistema, isTrue);
      expect(l.codigo, 'POL-01');
      expect(l.cantidad, 2);
      expect(l.stockDisponibleAlEvaluar, 3);
      expect(l.descripcionCliente, 'Polea motor Deutz'); // se conserva lo que dijo el cliente
      expect(l.definidoPor, 'SUP');
      expect(l.definidoEn, fecha);
    });

    test('definirConCotizacionProveedor: queda fuera del sistema y sin stock', () {
      final l = EvaluacionVentaRepuestoService.definirConCotizacionProveedor(
        _porDeterminar,
        codigoProveedor: ' PROV-9 ',
        ficha: const FichaCreacionRepuestoEntity(nombre: ' POLEA DEUTZ ', familiaPieza: 'POLEA', categoria: 'MOTOR'),
        cantidad: 1,
        definidoPor: 'SUP',
        definidoEn: fecha,
      );
      expect(l.porDeterminar, isFalse);
      expect(l.existeEnSistema, isFalse);
      expect(l.codigo, 'PROV-9');
      expect(l.descripcion, 'POLEA DEUTZ');
      expect(l.stockDisponibleAlEvaluar, 0);
      expect(l.fichaCreacion?.familiaPieza, 'POLEA');
      expect(l.unidad, 'UNIDAD'); // UDM por defecto de la ficha
    });
  });

}
