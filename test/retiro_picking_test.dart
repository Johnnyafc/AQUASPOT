// test/retiro_picking_test.dart
//
// Cada retiro = un picking: la orden lleva solo los repuestos de su picking,
// no se duplican órdenes, la anulación libera el picking, las órdenes
// antiguas se reparten entre pickings. Y el registro aparte de "Cambios de
// materiales" de Comercial.

import 'package:aquaspot_postventa/core/enum/ticket_enums.dart';
import 'package:aquaspot_postventa/features/tickets/domain/entities/cambio_material_entity.dart';
import 'package:aquaspot_postventa/features/tickets/domain/entities/orden_recepcion_repuestos_entity.dart';
import 'package:aquaspot_postventa/features/tickets/domain/entities/registro_despacho_entity.dart';
import 'package:aquaspot_postventa/features/tickets/domain/entities/repuesto_registrado_entity.dart';
import 'package:aquaspot_postventa/features/tickets/domain/entities/ticket_entity.dart';
import 'package:aquaspot_postventa/features/tickets/domain/services/retiro_picking_service.dart';
import 'package:flutter_test/flutter_test.dart';

typedef R = RetiroPickingService;

RegistroDespachoEntity picking(String id, Map<String, double> items) => RegistroDespachoEntity(
      id: 'REQ-1-$id',
      fecha: DateTime(2026, 10, 12),
      usuarioNombre: 'Bodeguero',
      usuarioId: 'u1',
      items: [
        for (final e in items.entries)
          DetalleItemDespachadoEntity(codigo: e.key, descripcion: 'Rep ${e.key}', unidad: 'UNIDAD', cantidad: e.value),
      ],
    );

OrdenRecepcionRepuestosEntity orden(
  String id,
  Map<String, double> items, {
  String? pickingId,
  EstadoOrdenRecepcion estado = EstadoOrdenRecepcion.pendienteRecoger,
  double? recibido, // cantidad recibida por ítem (si se completó)
}) =>
    OrdenRecepcionRepuestosEntity(
      id: id,
      ticketId: 'REQ-1',
      tecnicoId: 't1',
      tecnicoNombre: 'Técnico',
      supervisorAsigna: 'Sup',
      fechaAsignacion: DateTime(2026, 10, 12),
      estado: estado,
      pickingId: pickingId,
      items: [
        for (final e in items.entries)
          ItemRecepcionRepuestoEntity(
            codigo: e.key,
            descripcion: 'Rep ${e.key}',
            unidad: 'UNIDAD',
            cantidadDespachadaBodega: e.value,
            cantidadRecibidaTecnico: recibido ?? (estado == EstadoOrdenRecepcion.pendienteRecoger ? 0 : e.value),
          ),
      ],
    );

TicketEntity ticket({
  List<RegistroDespachoEntity> pickings = const [],
  List<OrdenRecepcionRepuestosEntity> ordenes = const [],
}) =>
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
  final p1 = picking('PICK-01', {'A': 2, 'B': 1});
  final p2 = picking('PICK-02', {'C': 3});

  group('Cada retiro = un picking', () {
    test('sin órdenes, los dos pickings están listos y cada uno solo con sus repuestos', () {
      final t = ticket(pickings: [p1, p2]);
      expect(R.pickingsDisponibles(t).map((p) => p.id), [p1.id, p2.id]);
      expect(R.items(t, p1.id).map((i) => i.codigo), ['A', 'B']);
      expect(R.items(t, p2.id).map((i) => i.codigo), ['C']);
    });

    test('con una orden pendiente el picking queda asignado y no se ofrece de nuevo', () {
      final t = ticket(pickings: [p1, p2], ordenes: [orden('REC-1', {'A': 2, 'B': 1}, pickingId: p1.id)]);
      expect(R.estado(t, p1.id), R.asignado);
      expect(R.pickingsDisponibles(t).map((p) => p.id), [p2.id]);
    });

    test('retiro completo → retirado; retiro parcial → el saldo vuelve a estar disponible', () {
      final completo = ticket(pickings: [p1], ordenes: [
        orden('REC-1', {'A': 2, 'B': 1}, pickingId: p1.id, estado: EstadoOrdenRecepcion.recibidoTotal),
      ]);
      expect(R.estado(completo, p1.id), R.retirado);

      final parcial = ticket(pickings: [p1], ordenes: [
        orden('REC-1', {'A': 2}, pickingId: p1.id, estado: EstadoOrdenRecepcion.recibidoParcial, recibido: 1),
      ]);
      expect(R.estado(parcial, p1.id), R.listo);
      final a = R.items(parcial, p1.id).firstWhere((i) => i.codigo == 'A');
      expect(a.disponible, 1);
    });

    test('una orden anulada libera su picking', () {
      final t = ticket(pickings: [p1], ordenes: [
        orden('REC-1', {'A': 2, 'B': 1}, pickingId: p1.id, estado: EstadoOrdenRecepcion.anulada),
      ]);
      expect(R.estado(t, p1.id), R.listo);
      expect(R.items(t, p1.id).every((i) => i.disponible == i.cantidadPicking), isTrue);
    });

    test('órdenes antiguas sin picking se reparten en orden de llegada', () {
      final t = ticket(
        pickings: [picking('DESP-01', {'A': 2}), picking('PICK-02', {'A': 1})],
        ordenes: [orden('REC-OLD', {'A': 2}, estado: EstadoOrdenRecepcion.recibidoTotal)],
      );
      expect(R.estado(t, 'REQ-1-DESP-01'), R.retirado);
      expect(R.estado(t, 'REQ-1-PICK-02'), R.listo);
      expect(R.codigoCorto(t, 'REQ-1-PICK-02'), 'PICK-02');
    });
  });

  group('Cambios de materiales (registro aparte de la auditoría)', () {
    const a = RepuestoRegistradoEntity(codigo: 'A', descripcion: 'Rep A', cantidad: 1);
    const b = RepuestoRegistradoEntity(codigo: 'B', descripcion: 'Rep B', cantidad: 2);
    const b3 = RepuestoRegistradoEntity(codigo: 'B', descripcion: 'Rep B', cantidad: 3);
    const c = RepuestoRegistradoEntity(codigo: 'C', descripcion: 'Rep C', cantidad: 1);

    List<CambioMaterialEntity> dif(List<RepuestoRegistradoEntity> antes, List<RepuestoRegistradoEntity> despues) =>
        CambioMaterialEntity.diferencias(
          antes: antes,
          despues: despues,
          lista: CambioMaterialEntity.listaTaller,
          momento: CambioMaterialEntity.regresoComercial,
          usuarioNombre: 'Comercial',
          usuarioRol: 'COMERCIAL',
          fecha: DateTime(2026, 10, 12, 15, 13),
        );

    test('agregó, quitó y cambió cantidad', () {
      final cambios = dif([a, b], [b3, c]);
      expect(cambios.map((x) => '${x.accion}:${x.codigo}'),
          unorderedEquals(['quito:A', 'cambioCantidad:B', 'agrego:C']));
      final cambio = cambios.firstWhere((x) => x.codigo == 'B');
      expect(cambio.cantidadAntes, 2);
      expect(cambio.cantidadDespues, 3);
    });

    test('sin cambios no registra nada', () {
      expect(dif([a, b], [b, a]), isEmpty);
    });

    test('se guarda y se lee igual', () {
      final cambio = dif([a], [a, c]).single;
      final leido = CambioMaterialEntity.fromJson(cambio.toJson())!;
      expect(leido, cambio);
      expect(leido.accionTexto, 'Agregó');
      expect(leido.momentoTexto, 'Regreso a Comercial');
    });
  });
}
