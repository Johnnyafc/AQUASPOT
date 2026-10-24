// test/indicadores_postventa_test.dart
//
// Indicadores de Postventa: servicios realizados (fin de Proceso de
// Trabajo), lead time de finalizados y fallas por sistema / equipo.

import 'package:aquaspot_postventa/core/enum/proceso_auditoria.dart';
import 'package:aquaspot_postventa/core/enum/ticket_enums.dart';
import 'package:aquaspot_postventa/features/fallas/domain/entities/metrica_falla_entity.dart';
import 'package:aquaspot_postventa/features/tickets/domain/entities/evento_auditoria_entity.dart';
import 'package:aquaspot_postventa/features/tickets/domain/entities/ticket_entity.dart';
import 'package:aquaspot_postventa/features/tickets/domain/services/indicadores_postventa_service.dart';
import 'package:aquaspot_postventa/features/tickets/presentation/services/generador_excel_indicadores_postventa.dart';
import 'package:flutter_test/flutter_test.dart';

typedef Svc = IndicadoresPostventaService;

EventoAuditoriaEntity ev(String fecha, String accion, {ProcesoAuditoria? proceso, HitoProceso? hito}) =>
    EventoAuditoriaEntity(
      accion: accion,
      usuarioNombre: 'U',
      usuarioRol: 'ROL',
      timestamp: DateTime.parse(fecha),
      proceso: proceso,
      hito: hito,
    );

TicketEntity ticket(
  String id, {
  required EstadoTicket estado,
  required List<EventoAuditoriaEntity> eventos,
  TipoEquipo equipo = TipoEquipo.Caracol,
  LugarAtencion lugar = LugarAtencion.taller,
  TipoRequerimiento tipo = TipoRequerimiento.reparacion,
  List<DiagnosticoFallaEntity> fallas = const [],
}) =>
    TicketEntity(
      id: id,
      estadoActual: estado,
      sede: Sede.DURAN,
      clienteId: 'CLIENTE $id',
      campamento: '',
      nombreContacto: '',
      emailContacto: '',
      telefonoContacto: '',
      equipoDetalle: null,
      accesoriosRecibidos: null,
      equipo: equipo,
      fallaReportada: '',
      numeroSerie: null,
      historialEventos: eventos,
      tipoRequerimiento: tipo,
      lugarAtencion: lugar,
      esRegistroCompleto: true,
      diagnosticoFallas: fallas,
    );

void main() {
  final desde = DateTime(2026, 8);
  final hasta = DateTime(2026, 9, 30); // día final incluido

  group('Indicador 1: servicios realizados', () {
    test('cuenta solo los que terminaron Proceso de Trabajo, en el mes en que salieron', () {
      final tickets = [
        // Ticket antiguo (por texto): terminó taller en agosto, hoy en Entrega.
        ticket('A', estado: EstadoTicket.entrega, lugar: LugarAtencion.campo, eventos: [
          ev('2026-07-20 08:00', 'TICKET CREADO'),
          ev('2026-08-10 10:00', 'TALLER: TRABAJO FINALIZADO'),
          ev('2026-09-02 10:00', 'GUÍA Y FACTURA REGISTRADAS'),
        ]),
        // Ticket nuevo (etiquetado): fin de taller en septiembre, finalizado.
        ticket('B', estado: EstadoTicket.finalizado, tipo: TipoRequerimiento.reclamoGarantia, eventos: [
          ev('2026-09-01 08:00', 'CREADO', proceso: ProcesoAuditoria.recepcion, hito: HitoProceso.inicio),
          ev('2026-09-05 09:00', 'TRABAJO COMPLETADO', proceso: ProcesoAuditoria.taller, hito: HitoProceso.fin),
          ev('2026-09-06 09:00', 'ENTREGADO', proceso: ProcesoAuditoria.entrega, hito: HitoProceso.fin),
        ]),
        // Sigue en taller: no cuenta.
        ticket('C', estado: EstadoTicket.procesoTrabajo, eventos: [
          ev('2026-08-01 08:00', 'CREADO'),
          ev('2026-08-03 08:00', 'TALLER: INICIO'),
        ]),
        // Anulado: no cuenta.
        ticket('D', estado: EstadoTicket.anulado, eventos: [ev('2026-08-01 08:00', 'TALLER: X')]),
        // Venta en entrega sin pasar por taller: no cuenta.
        ticket('E', estado: EstadoTicket.entrega, tipo: TipoRequerimiento.ventaRepuesto, eventos: [
          ev('2026-08-01 08:00', 'CREADO'),
          ev('2026-08-02 08:00', 'GUÍA Y FACTURA'),
        ]),
        // Terminó taller fuera del rango (julio): no cuenta.
        ticket('F', estado: EstadoTicket.finalizado, eventos: [ev('2026-07-01 08:00', 'TALLER: FIN')]),
      ];

      final r = Svc.calcular(tickets: tickets, desde: desde, hasta: hasta);
      expect(r.servicios.map((s) => s.ticket.id), unorderedEquals(['A', 'B']));
      final a = r.servicios.firstWhere((s) => s.ticket.id == 'A');
      expect(a.mes, DateTime(2026, 8));
      expect(a.lugar, Svc.campo);
      final b = r.servicios.firstWhere((s) => s.ticket.id == 'B');
      expect(b.mes, DateTime(2026, 9));
      expect(b.tipo, 'Reclamo de garantía');
    });
  });

  group('Indicador 2: lead time', () {
    test('solo finalizados en el mes; días de creación a finalización', () {
      final tickets = [
        ticket('A', estado: EstadoTicket.finalizado, eventos: [
          ev('2026-08-01 08:00', 'CREADO'),
          ev('2026-08-11 08:00', 'FINALIZADO'),
        ]),
        ticket('B', estado: EstadoTicket.finalizado, lugar: LugarAtencion.campo, eventos: [
          ev('2026-08-20 08:00', 'CREADO'),
          ev('2026-09-01 20:00', 'FINALIZADO'),
        ]),
        ticket('C', estado: EstadoTicket.entrega, eventos: [ev('2026-08-01 08:00', 'CREADO')]),
      ];
      final r = Svc.calcular(tickets: tickets, desde: desde, hasta: hasta);
      expect(r.leadTimes.map((l) => l.ticket.id), unorderedEquals(['A', 'B']));
      expect(r.leadTimes.firstWhere((l) => l.ticket.id == 'A').dias, 10);
      expect(r.leadTimes.firstWhere((l) => l.ticket.id == 'B').mes, DateTime(2026, 9));
      final res = ResumenLeadTime.de(r.leadTimes)!;
      expect(res.tickets, 2);
      expect(res.minimo, 10);
      expect(res.maximo, 12.5);
    });
  });

  group('Indicador 3: fallas por sistema', () {
    test('por mes de creación, sin anulados, razones normalizadas como en el Dashboard', () {
      const electrica = DiagnosticoFallaEntity(
        categoria: 'Eléctrico y Electrónico',
        subcategoria: 'Cableado',
        falla: 'Cables sulfatados',
        razonesProblema: ['Deficiencias de mantenimiento', 'deficiencias de mantenimiento', 'algo libre'],
      );
      final tickets = [
        ticket('A', estado: EstadoTicket.finalizado, equipo: TipoEquipo.Cosechadora, fallas: [electrica], eventos: [
          ev('2026-08-05 08:00', 'CREADO'),
        ]),
        ticket('B', estado: EstadoTicket.anulado, fallas: [electrica], eventos: [ev('2026-08-05 08:00', 'CREADO')]),
        ticket('C', estado: EstadoTicket.procesoTrabajo, fallas: [electrica], eventos: [ev('2026-06-05 08:00', 'CREADO')]),
      ];
      final r = Svc.calcular(tickets: tickets, desde: desde, hasta: hasta);
      expect(r.fallas.length, 1);
      final f = r.fallas.single;
      expect(f.equipo, 'Cosechadora');
      expect(f.sistema, 'Eléctrico y Electrónico');
      expect(f.razones, ['Deficiencias de mantenimiento', Svc.otrasRazones]);
    });
  });

  group('Indicador adicional: tickets creados', () {
    test('todos los creados en el rango (anulados incluidos y diferenciados), sin ventas', () {
      final tickets = [
        ticket('A', estado: EstadoTicket.finalizado, eventos: [ev('2026-08-05 08:00', 'CREADO')]),
        ticket('B', estado: EstadoTicket.recepcionFisica, lugar: LugarAtencion.campo, eventos: [ev('2026-09-01 08:00', 'CREADO')]),
        ticket('C', estado: EstadoTicket.anulado, eventos: [ev('2026-09-02 08:00', 'CREADO')]),
        ticket('D', estado: EstadoTicket.entrega, tipo: TipoRequerimiento.ventaRepuesto, eventos: [ev('2026-09-03 08:00', 'CREADO')]),
        ticket('E', estado: EstadoTicket.creado, tipo: TipoRequerimiento.ventaMaquina, eventos: [ev('2026-09-03 08:00', 'CREADO')]),
        ticket('F', estado: EstadoTicket.finalizado, eventos: [ev('2026-07-31 23:00', 'CREADO')]), // fuera del rango
      ];
      final r = Svc.calcular(tickets: tickets, desde: desde, hasta: hasta);
      expect(r.creados.map((c) => c.ticket.id), ['A', 'B', 'C']);
      expect(r.creados.map((c) => c.estado), [Svc.finalizado, Svc.enProceso, Svc.anulado]);
      expect(r.creados.firstWhere((c) => c.ticket.id == 'B').lugar, Svc.campo);
      // El anulado sigue fuera de los otros indicadores.
      expect(r.leadTimes.any((l) => l.ticket.id == 'C'), isFalse);
    });
  });

  group('Rango por día y filtro por equipo', () {
    test('los días límite se incluyen completos; fuera del rango no cuenta', () {
      final tickets = [
        ticket('A', estado: EstadoTicket.finalizado, eventos: [
          ev('2026-09-10 00:00', 'CREADO'),
          ev('2026-09-15 23:59', 'FINALIZADO'),
        ]),
        ticket('B', estado: EstadoTicket.finalizado, eventos: [
          ev('2026-09-10 00:00', 'CREADO'),
          ev('2026-09-16 00:01', 'FINALIZADO'),
        ]),
      ];
      final r = Svc.calcular(tickets: tickets, desde: DateTime(2026, 9, 10), hasta: DateTime(2026, 9, 15, 8));
      expect(r.leadTimes.map((l) => l.ticket.id), ['A']);
      expect(r.desde, DateTime(2026, 9, 10));
      expect(r.hasta, DateTime(2026, 9, 15));
      expect(r.meses, [DateTime(2026, 9)]);
    });

    test('con equipo solo entran los tickets de ese equipo', () {
      final tickets = [
        ticket('A', estado: EstadoTicket.finalizado, equipo: TipoEquipo.Caracol, eventos: [
          ev('2026-08-01 08:00', 'CREADO'),
          ev('2026-08-02 08:00', 'FINALIZADO'),
        ]),
        ticket('B', estado: EstadoTicket.finalizado, equipo: TipoEquipo.Cosechadora, eventos: [
          ev('2026-08-01 08:00', 'CREADO'),
          ev('2026-08-02 08:00', 'FINALIZADO'),
        ]),
      ];
      final r = Svc.calcular(tickets: tickets, desde: desde, hasta: hasta, equipo: 'Cosechadora');
      expect(r.equipo, 'Cosechadora');
      expect(r.leadTimes.map((l) => l.ticket.id), ['B']);
    });
  });

  test('meses entre dos fechas (cambio de año)', () {
    expect(Svc.mesesEntre(DateTime(2025, 11, 15), DateTime(2026, 2, 3)),
        [DateTime(2025, 11), DateTime(2025, 12), DateTime(2026, 1), DateTime(2026, 2)]);
  });

  test('el Excel se genera sin errores (con y sin datos)', () {
    final vacio = Svc.calcular(tickets: const [], desde: desde, hasta: hasta);
    expect(GeneradorExcelIndicadoresPostventa.generar(vacio), isNotEmpty);

    final conDatos = Svc.calcular(
      tickets: [
        ticket('A', estado: EstadoTicket.finalizado, fallas: const [
          DiagnosticoFallaEntity(categoria: 'Mecánico', falla: 'Eje roto', razonesProblema: ['Operación incorrecta']),
        ], eventos: [
          ev('2026-08-01 08:00', 'CREADO'),
          ev('2026-08-03 08:00', 'TALLER: FIN'),
          ev('2026-08-04 08:00', 'FINALIZADO'),
        ]),
      ],
      desde: desde,
      hasta: hasta,
    );
    expect(GeneradorExcelIndicadoresPostventa.generar(conDatos), isNotEmpty);
  });

  test('reporte de un equipo: Indicador 3 con cascada de pasteles (también los de 100 %)', () {
    const f1 = DiagnosticoFallaEntity(
        categoria: 'Eléctrico', subcategoria: 'Cableado', falla: 'Cables sulfatados',
        razonesProblema: ['Deficiencias de mantenimiento', 'Condiciones de servicio']);
    const f2 = DiagnosticoFallaEntity(
        categoria: 'Eléctrico', subcategoria: 'Cableado', falla: 'Cables pelados', razonesProblema: ['Operación incorrecta']);
    const f3 = DiagnosticoFallaEntity(categoria: 'Mecánico', falla: 'Eje roto');
    final datos = Svc.calcular(
      tickets: [
        ticket('A', estado: EstadoTicket.finalizado, equipo: TipoEquipo.Cosechadora, fallas: const [f1, f2, f3], eventos: [
          ev('2026-08-15 08:00', 'CREADO'),
          ev('2026-08-20 08:00', 'TALLER: FIN'),
          ev('2026-08-21 08:00', 'FINALIZADO'),
        ]),
      ],
      desde: DateTime(2026, 8, 10),
      hasta: hasta,
      equipo: 'Cosechadora',
    );
    expect(datos.fallas.length, 3);
    expect(GeneradorExcelIndicadoresPostventa.generar(datos), isNotEmpty);
  });

  group('Lead time: tiempo exacto y rangos', () {
    test('Días decimales como tiempo exacto', () {
      // 17/08 10:31 → 25/08 08:42 = 7d 22h 11m.
      expect(GeneradorExcelIndicadoresPostventa.tiempoDeDias(11411 / 1440), '7d 22h 11m');
      expect(GeneradorExcelIndicadoresPostventa.tiempoDeDias(0.5), '12h 0m');
      expect(GeneradorExcelIndicadoresPostventa.tiempoDeDias(51.0541666), '51d 1h 18m');
    });

    test('Rangos con el corte exacto en el nombre: 7d 22h va en "Más de 7 a 15"', () {
      final rangos = GeneradorExcelIndicadoresPostventa.rangosLeadTime;
      expect(rangos.map((r) => r.$1), ['Hasta 7 días', 'Más de 7 a 15 días', 'Más de 15 a 30 días', 'Más de 30 días']);
      String rangoDe(double dias) => rangos.firstWhere((r) => dias > r.$2 && dias <= r.$3).$1;
      expect(rangoDe(7), 'Hasta 7 días');
      expect(rangoDe(7.92), 'Más de 7 a 15 días');
      expect(rangoDe(15), 'Más de 7 a 15 días');
      expect(rangoDe(30.5), 'Más de 30 días');
    });
  });
}
