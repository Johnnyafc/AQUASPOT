// test/grupo_requerimiento_test.dart
import 'package:aquaspot_postventa/core/enum/rol_usuario.dart';
import 'package:aquaspot_postventa/core/enum/ticket_enums.dart';
import 'package:aquaspot_postventa/features/tickets/domain/entities/mantenimiento_interno_entity.dart';
import 'package:aquaspot_postventa/features/tickets/domain/services/formulario_mantenimiento_service.dart';
import 'package:aquaspot_postventa/features/tickets/domain/services/grupo_requerimiento_service.dart';
import 'package:flutter_test/flutter_test.dart';

typedef G = GrupoRequerimientoService;

void main() {
  final mantenimiento = FormularioMantenimientoService.construirTicket(
    const DatosMantenimientoInterno(
        tipoActivo: TipoActivoMantenimiento.cosechadora, serieOPlaca: 'AQ2', horometro: 10, detalle: 'Ruido en el motor',
        cantidadFotos: 1, tieneFotoLectura: true),
    usuarioNombre: 'Ana',
    rol: RolUsuario.requerimiento,
    ahora: DateTime(2026, 10, 29),
  );

  test('Mantenimiento interno va a OT, aunque se haya creado antes con código REQ', () {
    for (final id in ['OT-00001', 'REQ-00040']) {
      final t = mantenimiento.copyWith(id: id);
      expect(G.de(t), GrupoRequerimiento.ordenesTrabajo, reason: id);
      expect(G.pertenece(GrupoRequerimiento.requerimientos, t), isFalse, reason: id);
    }
  });

  test('El resto de tipos va a Requerimientos, nunca a OT', () {
    for (final tipo in TipoRequerimiento.values.where((t) => t != TipoRequerimiento.mantenimientoInterno)) {
      final t = mantenimiento.copyWith(id: 'REQ-00083', tipoRequerimiento: tipo, mantenimientoInterno: null);
      expect(G.pertenece(GrupoRequerimiento.requerimientos, t), isTrue, reason: tipo.name);
      expect(G.pertenece(GrupoRequerimiento.ordenesTrabajo, t), isFalse, reason: tipo.name);
    }
  });
}
