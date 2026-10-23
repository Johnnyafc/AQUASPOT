// test/flujo_venta_repuesto_test.dart
//
// Venta de Repuesto después de la OV: Compras sin proyecto, lista para
// Bodega con los repuestos de la venta, Validación por repuesto, picking →
// Entrega y sin liberar reservas de Caracol. Las reparaciones no cambian.

import 'package:aquaspot_postventa/core/enum/proceso_auditoria.dart';
import 'package:aquaspot_postventa/core/enum/ticket_enums.dart';
import 'package:aquaspot_postventa/features/tickets/domain/entities/linea_repuesto_venta_entity.dart';
import 'package:aquaspot_postventa/features/tickets/domain/entities/ticket_entity.dart';
import 'package:aquaspot_postventa/features/tickets/domain/services/flujo_venta_repuesto_service.dart';
import 'package:flutter_test/flutter_test.dart';

TicketEntity _ticket({
  TipoRequerimiento tipo = TipoRequerimiento.ventaRepuesto,
  TipoEquipo equipo = TipoEquipo.Cosechadora,
  List<LineaRepuestoVentaEntity> lineas = const [],
}) =>
    TicketEntity(
      id: 'REQ-00110',
      estadoActual: EstadoTicket.cotizado,
      sede: Sede.NINGUNO,
      clienteId: 'Cliente',
      campamento: '',
      nombreContacto: 'Contacto',
      telefonoContacto: '',
      emailContacto: '',
      equipo: equipo,
      equipoDetalle: null,
      accesoriosRecibidos: null,
      numeroSerie: null,
      fallaReportada: '',
      historialEventos: const [],
      tipoRequerimiento: tipo,
      lugarAtencion: LugarAtencion.noAplica,
      esRegistroCompleto: true,
      lineasRepuestoVenta: lineas,
    );

void main() {
  final fecha = DateTime(2026, 10, 21, 8);

  group('OV', () {
    test('venta → Compras sin Costos; reparación → Costos + Compras (sin cambios)', () {
      final venta = _ticket();
      final reparacion = _ticket(tipo: TipoRequerimiento.reparacion);
      expect(FlujoVentaRepuestoService.estadoTrasOV(venta), EstadoTicket.compras);
      expect(FlujoVentaRepuestoService.procesosTrasOV(venta), [ProcesoAuditoria.compras]);
      expect(FlujoVentaRepuestoService.estadoTrasOV(reparacion), EstadoTicket.costos);
      expect(FlujoVentaRepuestoService.procesosTrasOV(reparacion), [ProcesoAuditoria.costos, ProcesoAuditoria.compras]);
    });

    test('lista para Bodega con los repuestos finales (incluido el código creado por Costos)', () {
      const lineas = [
        LineaRepuestoVentaEntity(codigo: 'A1', descripcion: 'FILTRO', unidad: 'UND', cantidad: 2, stockDisponibleAlEvaluar: 5),
        LineaRepuestoVentaEntity(
          codigo: 'VAL-0123',
          descripcion: 'VALVULA INOX',
          unidad: 'UNIDAD',
          cantidad: 1,
          stockDisponibleAlEvaluar: 0,
          codigoCreadoPorCostos: true,
        ),
      ];
      final items = FlujoVentaRepuestoService.itemsDespachoDesdeLineas(lineas, fechaSolicitud: fecha);
      expect(items.map((i) => i.codigo), ['A1', 'VAL-0123']);
      expect(items.map((i) => i.cantidadSolicitada), [2, 1]);
      expect(items.map((i) => i.stockDisponibleAlEvaluar), [5, 0]);
      expect(items.every((i) => !i.validadoPorCompras && i.cantidadDespachada == 0), isTrue);
      expect(items.first.fechaSolicitud, fecha);
      expect(items.last.descripcion, 'VALVULA INOX');
    });
  });

  group('Validación Bodega y picking', () {
    test('venta usa validación por repuesto en cualquier equipo; reparación solo Caracol', () {
      expect(FlujoVentaRepuestoService.validacionPorRepuesto(_ticket(equipo: TipoEquipo.Contador)), isTrue);
      expect(FlujoVentaRepuestoService.validacionPorRepuesto(_ticket(tipo: TipoRequerimiento.reparacion)), isFalse);
      expect(
        FlujoVentaRepuestoService.validacionPorRepuesto(
            _ticket(tipo: TipoRequerimiento.reparacion, equipo: TipoEquipo.Caracol)),
        isTrue,
      );
    });

    test('finalizar picking: venta → Entrega; reparación → Proceso de Trabajo', () {
      expect(FlujoVentaRepuestoService.estadoTrasPicking(_ticket()), EstadoTicket.entrega);
      expect(FlujoVentaRepuestoService.procesosTrasPicking(_ticket()), [ProcesoAuditoria.entrega]);
      final reparacion = _ticket(tipo: TipoRequerimiento.reparacion);
      expect(FlujoVentaRepuestoService.estadoTrasPicking(reparacion), EstadoTicket.procesoTrabajo);
      expect(FlujoVentaRepuestoService.procesosTrasPicking(reparacion), [ProcesoAuditoria.taller]);
    });

    test('la venta Caracol no libera reservas; la reparación Caracol sí', () {
      expect(FlujoVentaRepuestoService.liberaReservaEnPicking(_ticket(equipo: TipoEquipo.Caracol)), isFalse);
      expect(
        FlujoVentaRepuestoService.liberaReservaEnPicking(
            _ticket(tipo: TipoRequerimiento.reparacion, equipo: TipoEquipo.Caracol)),
        isTrue,
      );
      expect(
        FlujoVentaRepuestoService.liberaReservaEnPicking(_ticket(tipo: TipoRequerimiento.reparacion)),
        isFalse,
      );
    });
  });
}
