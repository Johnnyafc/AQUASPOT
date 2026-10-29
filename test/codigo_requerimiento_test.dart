// test/codigo_requerimiento_test.dart
import 'package:aquaspot_postventa/core/enum/ticket_enums.dart';
import 'package:aquaspot_postventa/features/tickets/domain/services/codigo_requerimiento_service.dart';
import 'package:flutter_test/flutter_test.dart';

typedef C = CodigoRequerimientoService;

void main() {
  test('Mantenimiento interno: OT-00001 con su propio contador', () {
    expect(C.codigo(TipoRequerimiento.mantenimientoInterno, 1), 'OT-00001');
    expect(C.codigo(TipoRequerimiento.mantenimientoInterno, 123), 'OT-00123');
    expect(C.campoContador(TipoRequerimiento.mantenimientoInterno), 'ot_count');
  });

  test('El resto de requerimientos sigue con REQ y ticket_count', () {
    for (final t in TipoRequerimiento.values.where((t) => t != TipoRequerimiento.mantenimientoInterno)) {
      expect(C.codigo(t, 83), 'REQ-00083', reason: t.name);
      expect(C.campoContador(t), 'ticket_count', reason: t.name);
    }
  });
}
