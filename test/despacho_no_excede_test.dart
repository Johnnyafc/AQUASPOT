// test/despacho_no_excede_test.dart
//
// Despacho: no se registra una preparación/picking con más cantidad de la
// que falta de cada repuesto (caso REQ-00089: el mismo repuesto preparado
// dos veces con una lista desactualizada). Aplica a ventas y reparaciones.

import 'package:aquaspot_postventa/core/enum/ticket_enums.dart';
import 'package:aquaspot_postventa/features/tickets/domain/entities/item_despacho_bodega_entity.dart';
import 'package:aquaspot_postventa/features/tickets/domain/entities/registro_despacho_entity.dart';
import 'package:aquaspot_postventa/features/tickets/domain/entities/ticket_entity.dart';
import 'package:aquaspot_postventa/features/tickets/domain/services/estado_despacho_service.dart';
import 'package:flutter_test/flutter_test.dart';

TicketEntity _ticket(double despachado, {double solicitado = 2}) => TicketEntity(
      id: 'REQ-00089',
      estadoActual: EstadoTicket.bodega,
      sede: Sede.NINGUNO,
      clienteId: 'Cliente',
      campamento: '',
      nombreContacto: 'Contacto',
      telefonoContacto: '',
      emailContacto: '',
      equipo: TipoEquipo.Contador,
      equipoDetalle: null,
      accesoriosRecibidos: null,
      numeroSerie: null,
      fallaReportada: '',
      historialEventos: const [],
      tipoRequerimiento: TipoRequerimiento.ventaRepuesto,
      lugarAtencion: LugarAtencion.noAplica,
      esRegistroCompleto: true,
      itemsDespachoBodega: [
        ItemDespachoBodegaEntity(
          codigo: 'A1',
          descripcion: 'FILTRO',
          unidad: 'UND',
          cantidadSolicitada: solicitado,
          stockDisponibleAlEvaluar: 5,
          validadoPorCompras: true,
          cantidadDespachada: despachado,
        ),
      ],
    );

const _a1 = DetalleItemDespachadoEntity(codigo: 'A1', descripcion: 'FILTRO', unidad: 'UND', cantidad: 2);

void main() {
  test('primera preparación completa: permitida', () {
    expect(EstadoDespachoService.motivoExcesoDespacho(_ticket(0), const [_a1]), isNull);
  });

  test('repetir la preparación del mismo repuesto ya despachado: rechazada', () {
    final motivo = EstadoDespachoService.motivoExcesoDespacho(_ticket(2), const [_a1]);
    expect(motivo, contains('ya fue despachado por completo'));
  });

  test('parcial: no más de lo que falta', () {
    expect(EstadoDespachoService.motivoExcesoDespacho(_ticket(1), const [_a1]), contains('solo faltan 1'));
    const uno = DetalleItemDespachadoEntity(codigo: 'a1 ', descripcion: 'FILTRO', unidad: 'UND', cantidad: 1);
    expect(EstadoDespachoService.motivoExcesoDespacho(_ticket(1), const [uno]), isNull);
  });

  test('repuesto que no está en la lista del ticket: no se bloquea', () {
    const otro = DetalleItemDespachadoEntity(codigo: 'Z9', descripcion: 'X', unidad: 'UND', cantidad: 5);
    expect(EstadoDespachoService.motivoExcesoDespacho(_ticket(2), const [otro]), isNull);
  });
}
