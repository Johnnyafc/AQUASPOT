// test/tiempos_operativos_trazabilidad_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:aquaspot_postventa/core/enum/ticket_enums.dart';
import 'package:aquaspot_postventa/features/tickets/data/models/ticket_model.dart';
import 'package:aquaspot_postventa/features/tickets/domain/entities/item_despacho_bodega_entity.dart';
import 'package:aquaspot_postventa/features/tickets/domain/entities/tiempos_operativos_entity.dart';
import 'package:aquaspot_postventa/features/tickets/domain/services/calculador_tiempos_operativos.dart';

void main() {
  group('Trazabilidad Concurrente y Retrocompatibilidad de Tickets', () {
    test('1. Un ticket legado (sin tiemposOperativos) debe deserializar sin error con null', () {
      final jsonLegado = <String, dynamic>{
        'id': 'TCK-LEGADO-001',
        'estadoActual': 'compras',
        'sede': 'DURAN',
        'clienteId': 'CLI-01',
        'campamento': 'CAMPO-A',
        'nombreContacto': 'Juan Perez',
        'telefonoContacto': '0999999999',
        'emailContacto': 'juan@test.com',
        'equipo': 'Caracol',
        'fallaReportada': 'Fuga de agua',
        'historialEventos': [
          {
            'timestamp': '2026-09-01T08:00:00Z',
            'usuarioNombre': 'Carlos',
            'usuarioRol': 'TECNICO',
            'accion': 'CREACIÓN DE REQUERIMIENTO',
          }
        ],
        'tipoRequerimiento': 'reparacion',
        'lugarAtencion': 'taller',
        'itemsDespachoBodega': [
          {
            'codigo': 'ROD-6204',
            'descripcion': 'Rodamiento 6204',
            'unidad': 'UND',
            'cantidadSolicitada': 2.0,
            'stockDisponibleAlEvaluar': 0.0,
            'validadoPorCompras': false,
            'cantidadDespachada': 0.0,
          }
        ],
      };

      final ticket = TicketModel.fromJson(jsonLegado);

      expect(ticket.id, 'TCK-LEGADO-001');
      expect(ticket.tiemposOperativos, isNull);
      expect(ticket.itemsDespachoBodega.length, 1);
      expect(ticket.itemsDespachoBodega.first.fechaSolicitud, isNull);
      expect(ticket.itemsDespachoBodega.first.fechaValidadoCompras, isNull);
      expect(ticket.itemsDespachoBodega.first.tiempoAbastecimientoCalculadoHoras, isNull);
    });

    test('2. Un ticket con la nueva estructura debe deserializar tiempos netos y semáforos', () {
      final jsonNuevo = <String, dynamic>{
        'id': 'TCK-NUEVO-042',
        'estadoActual': 'procesoTrabajo',
        'sede': 'DURAN',
        'clienteId': 'CLI-02',
        'campamento': 'CAMPO-B',
        'nombreContacto': 'Maria',
        'telefonoContacto': '0988888888',
        'emailContacto': 'maria@test.com',
        'equipo': 'Cosechadora',
        'fallaReportada': 'Ruido extraño',
        'historialEventos': [],
        'tipoRequerimiento': 'reparacion',
        'lugarAtencion': 'taller',
        'tiemposOperativos': {
          'leadTimeTotalHoras': 72.5,
          'subEstados': {
            'compras': 'COMPLETADO',
            'bodega': 'DESPACHO_TOTAL',
            'taller': 'TRABAJO_EN_CURSO',
          },
          'compras': {
            'fechaInicio': '2026-09-10T08:00:00Z',
            'fechaFin': '2026-09-11T12:00:00Z',
            'tiempoGestionHoras': 28.0,
            'totalRepuestos': 3,
            'repuestosValidados': 3,
          },
          'bodega': {
            'fechaPrimerDespacho': '2026-09-11T12:30:00Z',
            'fechaUltimoDespacho': '2026-09-11T14:00:00Z',
            'tiempoNetoDespachoHoras': 1.5,
            'tiempoEsperaPorComprasHoras': 28.0,
            'totalLotesDespachados': 2,
          },
          'taller': {
            'fechaInicioTrabajo': '2026-09-11T14:30:00Z',
            'tiempoNetoTrabajoHoras': 6.0,
            'tiempoEsperaMaterialHoras': 28.0,
          },
        },
        'itemsDespachoBodega': [
          {
            'codigo': 'SEL-MEC-20',
            'descripcion': 'Sello Mecanico',
            'unidad': 'UND',
            'cantidadSolicitada': 1.0,
            'stockDisponibleAlEvaluar': 0.0,
            'validadoPorCompras': true,
            'cantidadDespachada': 1.0,
            'fechaSolicitud': '2026-09-10T08:00:00Z',
            'fechaValidadoCompras': '2026-09-11T12:00:00Z',
            'fechaUltimoDespacho': '2026-09-11T14:00:00Z',
            'tiempoAbastecimientoHoras': 28.0,
          }
        ],
      };

      final ticket = TicketModel.fromJson(jsonNuevo);

      expect(ticket.id, 'TCK-NUEVO-042');
      expect(ticket.tiemposOperativos, isNotNull);
      expect(ticket.tiemposOperativos!.leadTimeTotalHoras, 72.5);
      expect(ticket.tiemposOperativos!.subEstados.compras, 'COMPLETADO');
      expect(ticket.tiemposOperativos!.subEstados.bodega, 'DESPACHO_TOTAL');
      expect(ticket.tiemposOperativos!.subEstados.taller, 'TRABAJO_EN_CURSO');
      expect(ticket.tiemposOperativos!.bodega.tiempoNetoDespachoHoras, 1.5);
      expect(ticket.tiemposOperativos!.bodega.tiempoEsperaPorComprasHoras, 28.0);
      expect(ticket.itemsDespachoBodega.first.tiempoAbastecimientoHoras, 28.0);
      expect(ticket.itemsDespachoBodega.first.tiempoReaccionBodegaCalculadoHoras, 2.0);
    });

    test('3. CalculadorTiemposOperativos actualiza correctamente las métricas en Compras y Bodega', () {
      final baseTicket = TicketModel.fromJson({
        'id': 'TCK-CALC-001',
        'estadoActual': 'compras',
        'sede': 'DURAN',
        'clienteId': 'CLI-01',
        'campamento': 'CAMPO-A',
        'nombreContacto': 'Juan',
        'telefonoContacto': '0999999999',
        'emailContacto': 'juan@test.com',
        'equipo': 'Caracol',
        'fallaReportada': 'Falla',
        'historialEventos': [
          {
            'timestamp': '2026-09-10T08:00:00Z',
            'usuarioNombre': 'Carlos',
            'usuarioRol': 'TECNICO',
            'accion': 'CREACIÓN',
          }
        ],
        'tipoRequerimiento': 'reparacion',
        'lugarAtencion': 'taller',
      });

      final fechaSol = DateTime.parse('2026-09-10T08:00:00Z');
      final fechaVal = DateTime.parse('2026-09-10T11:00:00Z');

      final itemValidado = ItemDespachoBodegaEntity(
        codigo: 'ROD-6204',
        descripcion: 'Rodamiento',
        unidad: 'UND',
        cantidadSolicitada: 1.0,
        stockDisponibleAlEvaluar: 0.0,
        validadoPorCompras: true,
        fechaSolicitud: fechaSol,
        fechaValidadoCompras: fechaVal,
      );

      // 1. Simular validación en compras
      final metricasCompras = CalculadorTiemposOperativos.actualizarMetricasCompras(
        ticket: baseTicket,
        items: [itemValidado],
        timestamp: fechaVal,
      );

      expect(metricasCompras.compras.repuestosValidados, 1);
      expect(metricasCompras.compras.totalRepuestos, 1);
      expect(metricasCompras.compras.tiempoGestionHoras, 3.0);
      expect(metricasCompras.subEstados.compras, 'COMPLETADO');
      expect(metricasCompras.subEstados.bodega, 'DISPONIBLE_DESPACHO');

      // 2. Simular despacho en bodega 1 hora después
      final fechaDespacho = DateTime.parse('2026-09-10T12:00:00Z');
      final itemDespachado = itemValidado.copyWith(
        cantidadDespachada: 1.0,
        fechaUltimoDespacho: fechaDespacho,
      );

      final ticketConCompras = baseTicket.copyWith(
        tiemposOperativos: metricasCompras,
        itemsDespachoBodega: [itemDespachado],
      );

      final metricasBodega = CalculadorTiemposOperativos.actualizarMetricasBodega(
        ticket: ticketConCompras,
        itemsActualizados: [itemDespachado],
        esDespachoCompleto: true,
        timestamp: fechaDespacho,
      );

      expect(metricasBodega.bodega.tiempoNetoDespachoHoras, 1.0); // 11:00 a 12:00 = 1 hr
      expect(metricasBodega.bodega.tiempoEsperaPorComprasHoras, 3.0);
      expect(metricasBodega.subEstados.bodega, 'DESPACHO_TOTAL');
      expect(metricasBodega.subEstados.taller, 'TRABAJO_EN_CURSO');
    });
  });
}
