// test/taller_secuencial_test.dart
//
// Taller secuencial: solo se envía a recoger un picking con la evidencia de
// Bodega, y el siguiente solo cuando el anterior está retirado y con el
// consumo validado. Bodega puede seguir haciendo pickings en paralelo.

import 'package:aquaspot_postventa/core/enum/ticket_enums.dart';
import 'package:aquaspot_postventa/features/tickets/domain/entities/orden_recepcion_repuestos_entity.dart';
import 'package:aquaspot_postventa/features/tickets/domain/entities/registro_despacho_entity.dart';
import 'package:aquaspot_postventa/features/tickets/domain/entities/ticket_entity.dart';
import 'package:aquaspot_postventa/features/tickets/domain/services/retiro_picking_service.dart';
import 'package:flutter_test/flutter_test.dart';

typedef R = RetiroPickingService;

RegistroDespachoEntity picking(String id, {bool conEvidencia = true}) => RegistroDespachoEntity(
      id: 'REQ-1-$id',
      fecha: DateTime(2026, 10, 13),
      usuarioNombre: 'Bodeguero',
      usuarioId: 'u1',
      items: const [DetalleItemDespachadoEntity(codigo: 'A', descripcion: 'Rep A', unidad: 'UNIDAD', cantidad: 1)],
      fotosEvidenciasUrls: conEvidencia ? const ['foto'] : const [],
    );

OrdenRecepcionRepuestosEntity orden(String id, String pickingId,
        {EstadoOrdenRecepcion estado = EstadoOrdenRecepcion.pendienteRecoger, bool validado = false}) =>
    OrdenRecepcionRepuestosEntity(
      id: id,
      ticketId: 'REQ-1',
      tecnicoId: 't',
      tecnicoNombre: 'Técnico',
      supervisorAsigna: 'Sup',
      fechaAsignacion: DateTime(2026, 10, 13),
      estado: estado,
      pickingId: 'REQ-1-$pickingId',
      validadoSupervisor: validado,
      items: [
        ItemRecepcionRepuestoEntity(
          codigo: 'A',
          descripcion: 'Rep A',
          unidad: 'UNIDAD',
          cantidadDespachadaBodega: 1,
          cantidadRecibidaTecnico: estado == EstadoOrdenRecepcion.pendienteRecoger ? 0 : 1,
        ),
      ],
    );

TicketEntity ticket(List<RegistroDespachoEntity> pickings, [List<OrdenRecepcionRepuestosEntity> ordenes = const []]) =>
    TicketEntity(
      id: 'REQ-1',
      estadoActual: EstadoTicket.procesoTrabajo,
      sede: Sede.DURAN,
      clienteId: 'CLI',
      campamento: '',
      nombreContacto: '',
      emailContacto: '',
      telefonoContacto: '',
      equipoDetalle: null,
      accesoriosRecibidos: null,
      equipo: TipoEquipo.Caracol,
      fallaReportada: '',
      numeroSerie: null,
      historialEventos: const [],
      tipoRequerimiento: TipoRequerimiento.reparacion,
      lugarAtencion: LugarAtencion.taller,
      esRegistroCompleto: true,
      historialDespachos: pickings,
      ordenesRecepcion: ordenes,
    );

void main() {
  test('solo se puede enviar un picking con la evidencia de Bodega', () {
    final t = ticket([picking('PICK-01', conEvidencia: false)]);
    expect(R.pickingsAsignables(t), isEmpty);
    expect(R.motivoBloqueoAsignacion(t), contains('evidencia'));
    expect(R.motivoBloqueoAsignacion(t, pickingId: 'REQ-1-PICK-01'), contains('evidencia del PICK-01'));

    final conEvidencia = ticket([picking('PICK-01')]);
    expect(R.motivoBloqueoAsignacion(conEvidencia, pickingId: 'REQ-1-PICK-01'), isNull);
  });

  test('con una orden pendiente de retiro no se envía el siguiente', () {
    final t = ticket([picking('PICK-01'), picking('PICK-02')], [orden('REC-1', 'PICK-01')]);
    expect(R.motivoBloqueoAsignacion(t, pickingId: 'REQ-1-PICK-02'), contains('pendiente de retiro'));
  });

  test('retirada pero sin validar el consumo: tampoco se envía el siguiente', () {
    final t = ticket(
      [picking('PICK-01'), picking('PICK-02')],
      [orden('REC-1', 'PICK-01', estado: EstadoOrdenRecepcion.recibidoTotal)],
    );
    expect(R.motivoBloqueoAsignacion(t, pickingId: 'REQ-1-PICK-02'), contains('Valide el consumo de REC-1 (PICK-01)'));
  });

  test('retirada y validada: se puede enviar el siguiente; las anuladas no bloquean', () {
    final t = ticket(
      [picking('PICK-01'), picking('PICK-02')],
      [
        orden('REC-1', 'PICK-01', estado: EstadoOrdenRecepcion.recibidoTotal, validado: true),
        orden('REC-X', 'PICK-02', estado: EstadoOrdenRecepcion.anulada),
      ],
    );
    expect(R.motivoBloqueoAsignacion(t, pickingId: 'REQ-1-PICK-02'), isNull);
    expect(R.pickingsAsignables(t).map((p) => p.id), ['REQ-1-PICK-02']);
  });

  test('Bodega puede tener varios pickings listos en paralelo', () {
    final t = ticket([picking('PICK-01'), picking('PICK-02'), picking('PICK-03')]);
    expect(R.pickingsAsignables(t).length, 3);
    expect(R.motivoBloqueoAsignacion(t), isNull);
  });
}
