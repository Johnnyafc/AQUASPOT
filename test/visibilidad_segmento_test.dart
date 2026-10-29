// test/visibilidad_segmento_test.dart
import 'package:aquaspot_postventa/core/enum/rol_usuario.dart';
import 'package:aquaspot_postventa/core/enum/segmento_operativo.dart';
import 'package:aquaspot_postventa/core/enum/ticket_enums.dart';
import 'package:aquaspot_postventa/features/tickets/domain/entities/mantenimiento_interno_entity.dart';
import 'package:aquaspot_postventa/features/tickets/domain/entities/ticket_entity.dart';
import 'package:aquaspot_postventa/features/tickets/domain/services/formulario_mantenimiento_service.dart';
import 'package:aquaspot_postventa/features/tickets/domain/services/visibilidad_segmento_service.dart';
import 'package:flutter_test/flutter_test.dart';

typedef V = VisibilidadSegmentoService;
typedef S = SegmentoOperativo;

TicketEntity ot(TipoActivoMantenimiento tipo) => FormularioMantenimientoService.construirTicket(
      DatosMantenimientoInterno(tipoActivo: tipo, serieOPlaca: 'X', detalle: 'Ruido en el motor', cantidadFotos: 1),
      usuarioNombre: 'Ana',
      rol: RolUsuario.requerimiento,
      ahora: DateTime(2026, 10, 29),
    ).copyWith(id: 'OT-00001');

TicketEntity requerimiento(TipoEquipo equipo) => ot(TipoActivoMantenimiento.caracol)
    .copyWith(id: 'REQ-00083', tipoRequerimiento: TipoRequerimiento.reparacion, mantenimientoInterno: null, equipo: equipo);

void main() {
  test('Requerimientos: cada supervisor solo los de su equipo (sin cambios)', () {
    expect(V.ve(S.caracol, requerimiento(TipoEquipo.Caracol)), isTrue);
    expect(V.ve(S.caracol, requerimiento(TipoEquipo.Cosechadora)), isFalse);
    expect(V.ve(S.cosechadora, requerimiento(TipoEquipo.Cosechadora)), isTrue);
    expect(V.ve(S.contador, requerimiento(TipoEquipo.Contador)), isTrue);
    expect(V.ve(S.contador, requerimiento(TipoEquipo.Caracol)), isFalse);
  });

  test('OT de cosechadora: al supervisor de Cosechadora y también al de Caracol', () {
    final t = ot(TipoActivoMantenimiento.cosechadora);
    expect(V.ve(S.cosechadora, t), isTrue);
    expect(V.ve(S.caracol, t), isTrue);
    expect(V.ve(S.contador, t), isFalse);
  });

  test('OT de contador: solo al supervisor de Contador', () {
    final t = ot(TipoActivoMantenimiento.contador);
    expect(V.ve(S.contador, t), isTrue);
    expect(V.ve(S.caracol, t), isFalse);
    expect(V.ve(S.cosechadora, t), isFalse);
  });

  test('OT de caracol, bomba, vehículo, aire acondicionado y herramientas: al supervisor de Caracol', () {
    for (final tipo in [
      TipoActivoMantenimiento.caracol,
      TipoActivoMantenimiento.bombaTransferencia,
      TipoActivoMantenimiento.vehiculo,
      TipoActivoMantenimiento.aireAcondicionado,
      TipoActivoMantenimiento.herramientas,
    ]) {
      final t = ot(tipo);
      expect(V.ve(S.caracol, t), isTrue, reason: tipo.name);
      expect(V.ve(S.cosechadora, t), isFalse, reason: tipo.name);
      expect(V.ve(S.contador, t), isFalse, reason: tipo.name);
    }
  });

  test('General y sin segmento ven todo', () {
    for (final t in [ot(TipoActivoMantenimiento.vehiculo), requerimiento(TipoEquipo.Contador)]) {
      expect(V.ve(S.general, t), isTrue);
      expect(V.ve(S.ninguno, t), isTrue);
    }
  });

  test('Consulta: solo Caracol trae además los mantenimientos internos', () {
    expect(V.consultaMantenimientos(S.caracol), isTrue);
    expect(V.consultaMantenimientos(S.cosechadora), isFalse);
    expect(V.consultaMantenimientos(S.contador), isFalse);
    expect(V.equiposDe(S.caracol), [TipoEquipo.Caracol]);
    expect(V.equiposDe(S.cosechadora), [TipoEquipo.Cosechadora]);
    expect(V.equiposDe(S.contador), [TipoEquipo.Contador]);
  });

  test('OT sin máquina legible: a Caracol (igual que las notificaciones)', () {
    final t = ot(TipoActivoMantenimiento.vehiculo).copyWith(mantenimientoInterno: null);
    expect(t.esMantenimientoInterno, isTrue);
    expect(V.ve(S.caracol, t), isTrue);
    expect(V.ve(S.cosechadora, t), isFalse);
  });
}
