import 'package:flutter_test/flutter_test.dart';
import 'package:aquaspot_postventa/core/enum/proceso_auditoria.dart';
import 'package:aquaspot_postventa/features/tickets/domain/entities/evento_auditoria_entity.dart';
import 'package:aquaspot_postventa/features/tickets/domain/services/tiempos_por_proceso_service.dart';

EventoAuditoriaEntity _ev(
  String fecha,
  String accion, {
  ProcesoAuditoria? p,
  HitoProceso? h,
  List<ProcesoAuditoria> hab = const [],
  String usuario = 'U',
}) =>
    EventoAuditoriaEntity(
      accion: accion,
      usuarioNombre: usuario,
      usuarioRol: 'ROL',
      timestamp: DateTime.parse(fecha),
      proceso: p,
      hito: h,
      habilita: hab,
    );

/// Total de horas por parte de un proceso ("Proceso|Parte").
Map<String, double> _partes(List<EventoAuditoriaEntity> historial) {
  final out = <String, double>{};
  for (final t in TiemposPorProcesoService.calcular(historial)) {
    if (t.subproceso == null) continue;
    final k = '${t.proceso}|${t.subproceso}';
    out[k] = (out[k] ?? 0) + t.horas;
  }
  return out;
}

/// Total de horas por proceso (sumando todas las personas).
Map<String, double> _totales(List<EventoAuditoriaEntity> historial) {
  final out = <String, double>{};
  for (final t in TiemposPorProcesoService.calcular(historial)) {
    out[t.proceso] = (out[t.proceso] ?? 0) + t.horas;
  }
  return out;
}

const _procesos = ProcesoAuditoria.values;

void main() {
  group('Tickets con etiquetas (carriles en paralelo)', () {
    // Ejemplo REQ-00150: Compras, Despacho y Taller trabajan a la vez.
    final req150 = [
      _ev('2026-10-01 08:00', 'CREACIÓN DE REQUERIMIENTO', p: ProcesoAuditoria.recepcion, h: HitoProceso.inicio),
      _ev('2026-10-01 10:00', 'RECEPCIÓN FÍSICA Y EMISIÓN DE ACTA', p: ProcesoAuditoria.recepcion, h: HitoProceso.fin, hab: [ProcesoAuditoria.evaluacion]),
      _ev('2026-10-02 09:00', 'EVALUACIÓN TÉCNICA Y DOCUMENTAL REGISTRADA', p: ProcesoAuditoria.evaluacion, h: HitoProceso.fin, hab: [ProcesoAuditoria.comercial]),
      _ev('2026-10-02 15:00', 'COTIZACIÓN GENERADA: x', p: ProcesoAuditoria.comercial, h: HitoProceso.fin, hab: [ProcesoAuditoria.aprobacionCliente]),
      _ev('2026-10-03 11:00', 'APROBACIÓN COMERCIAL - Órdenes anexadas', p: ProcesoAuditoria.aprobacionCliente, h: HitoProceso.fin, hab: [ProcesoAuditoria.costos, ProcesoAuditoria.compras]),
      _ev('2026-10-03 14:00', 'FASE COSTOS - Código Proyecto Asignado: P-88', p: ProcesoAuditoria.costos, h: HitoProceso.fin, hab: [ProcesoAuditoria.bodega]),
      _ev('2026-10-03 16:00', 'ÓRDENES DE COMPRA EXTERNAS REGISTRADAS MÚLTIPLE', p: ProcesoAuditoria.compras, h: HitoProceso.fin, hab: [ProcesoAuditoria.validacionBodega]),
      _ev('2026-10-04 09:00', 'COMPRAS: VALIDACIÓN PARCIAL DE REPUESTOS (1/3 validados)', p: ProcesoAuditoria.validacionBodega, h: HitoProceso.avance, hab: [ProcesoAuditoria.bodega]),
      _ev('2026-10-04 10:00', 'INICIO DE TRABAJO EN CAMPO / TALLER', p: ProcesoAuditoria.taller, h: HitoProceso.inicio),
      _ev('2026-10-04 15:00', 'BODEGA: DESPACHO PARCIAL (1 ítems entregados)', p: ProcesoAuditoria.bodega, h: HitoProceso.avance),
      _ev('2026-10-05 12:00', 'COMPRAS: VALIDACIÓN COMPLETA (3/3) Y TRANSFERENCIA A BODEGA', p: ProcesoAuditoria.validacionBodega, h: HitoProceso.fin, hab: [ProcesoAuditoria.bodega]),
      _ev('2026-10-05 16:00', 'BODEGA: DESPACHO TOTAL Y TRANSFERENCIA A PROCESO DE TRABAJO (3 ítems entregados)', p: ProcesoAuditoria.bodega, h: HitoProceso.fin, hab: [ProcesoAuditoria.taller]),
      _ev('2026-10-06 17:00', 'TALLER: EVIDENCIA REGISTRADA. TÉCNICOS: A. EQUIPO LISTO.', p: ProcesoAuditoria.taller, h: HitoProceso.fin, hab: [ProcesoAuditoria.revisionPagos]),
    ];

    test('REQ-00150: cada proceso se mide en su propio carril', () {
      expect(TiemposPorProcesoService.usaEtiquetas(req150), isTrue);
      final t = _totales(req150);
      expect(t['Recepción'], 2);
      expect(t['Evaluación Técnica'], 23);
      expect(t['En cotización'], 6);
      expect(t['Proforma enviada'], 20);
      expect(t['Costos'], 3);
      expect(t['Compras'], 5);
      expect(t['Validación Bodega'], 44);
      // Costos abrió Despacho de forma provisional, pero Bodega no actuó
      // antes de la primera validación de Compras: cuenta desde ahí.
      expect(t['Despacho'], 31);
      // El supervisor inició antes de que llegara todo el material.
      expect(t['Proceso de Trabajo'], 55);
      expect(t.containsKey('Sin clasificar'), isFalse);
    });

    test('REQ-00150: partes de Recepción, Compras y Taller (suman el total)', () {
      final p = _partes(req150);
      expect(p['Recepción|Registro y acta'], 2);
      expect(p.keys.where((k) => k.startsWith('Compras|')), isEmpty); // Compras no se despliega
      // Taller inició el 04/10 10:00; el material llegó completo el 05/10 16:00.
      expect(p.containsKey('Proceso de Trabajo|Antes de iniciar'), isFalse);
      expect(p['Proceso de Trabajo|Espera de material'], 30);
      expect(p['Proceso de Trabajo|Trabajo'], 25);
    });

    test('Taller habilitado antes de que el supervisor inicie: "Antes de iniciar"', () {
      final h = [
        _ev('2026-10-01 08:00', 'BODEGA: DESPACHO TOTAL Y TRANSFERENCIA A PROCESO DE TRABAJO (2 ítems entregados)', p: ProcesoAuditoria.bodega, h: HitoProceso.fin, hab: [ProcesoAuditoria.taller]),
        _ev('2026-10-01 11:00', 'INICIO DE TRABAJO EN CAMPO / TALLER', p: ProcesoAuditoria.taller, h: HitoProceso.inicio),
        _ev('2026-10-02 11:00', 'TALLER: EVIDENCIA REGISTRADA. TÉCNICOS: A. EQUIPO LISTO.', p: ProcesoAuditoria.taller, h: HitoProceso.fin, hab: [ProcesoAuditoria.revisionPagos]),
      ];
      final p = _partes(h);
      expect(p['Proceso de Trabajo|Antes de iniciar'], 3);
      expect(p.containsKey('Proceso de Trabajo|Espera de material'), isFalse);
      expect(p['Proceso de Trabajo|Trabajo'], 24);
      expect(_totales(h)['Proceso de Trabajo'], 27);
    });

    test('Recepción con traslado desde El Guabo: "Registro y acta" + "En camino"', () {
      final h = [
        _ev('2026-10-01 08:00', 'CREACIÓN DE REQUERIMIENTO', p: ProcesoAuditoria.recepcion, h: HitoProceso.inicio),
        _ev('2026-10-01 10:00', 'RECEPCIÓN FÍSICA Y EMISIÓN DE ACTA', p: ProcesoAuditoria.recepcion, h: HitoProceso.avance),
        _ev('2026-10-02 10:00', 'EQUIPO ENVIADO DESDE EL GUABO RECIBIDO EN TALLER', p: ProcesoAuditoria.recepcion, h: HitoProceso.fin, hab: [ProcesoAuditoria.evaluacion]),
      ];
      final p = _partes(h);
      expect(p['Recepción|Registro y acta'], 2);
      expect(p['Recepción|En camino (Guabo)'], 24);
      expect(_totales(h)['Recepción'], 26);
    });

    test('Venta sin stock: el tiempo de Compras se suma en Compras (sin desplegar)', () {
      final h = [
        _ev('2026-10-01 08:00', 'CREACIÓN DE REQUERIMIENTO', p: ProcesoAuditoria.recepcion, h: HitoProceso.fin, hab: [ProcesoAuditoria.compras]),
        _ev('2026-10-01 14:00', 'COMPRAS: GESTIÓN DE REPUESTO SIN STOCK COMPLETADA (VENTA DE REPUESTO)', p: ProcesoAuditoria.compras, h: HitoProceso.fin, hab: [ProcesoAuditoria.comercial]),
      ];
      expect(_totales(h)['Compras'], 6);
      expect(_partes(h).keys.where((k) => k.startsWith('Compras|')), isEmpty);
    });

    test('Despacho cuenta desde Costos si Bodega despacha stock antes que Compras valide', () {
      final h = [
        _ev('2026-10-01 08:00', 'APROBACIÓN COMERCIAL - Órdenes anexadas', p: ProcesoAuditoria.aprobacionCliente, h: HitoProceso.fin, hab: [ProcesoAuditoria.costos, ProcesoAuditoria.compras]),
        _ev('2026-10-01 10:00', 'FASE COSTOS - Código Proyecto Asignado: P-1', p: ProcesoAuditoria.costos, h: HitoProceso.fin, hab: [ProcesoAuditoria.bodega]),
        _ev('2026-10-01 12:00', 'BODEGA: DESPACHO PARCIAL (1 ítems entregados)', p: ProcesoAuditoria.bodega, h: HitoProceso.avance),
        _ev('2026-10-02 10:00', 'COMPRAS: VALIDACIÓN PARCIAL DE REPUESTOS (1/2 validados)', p: ProcesoAuditoria.validacionBodega, h: HitoProceso.avance, hab: [ProcesoAuditoria.bodega]),
        _ev('2026-10-02 14:00', 'BODEGA: DESPACHO TOTAL Y TRANSFERENCIA A PROCESO DE TRABAJO (2 ítems entregados)', p: ProcesoAuditoria.bodega, h: HitoProceso.fin, hab: [ProcesoAuditoria.taller]),
      ];
      expect(_totales(h)['Despacho'], 28); // 01/10 10:00 → 02/10 14:00
    });

    test('Modificación de proforma: se suman los ciclos (opción A)', () {
      final h = [
        _ev('2026-10-05 08:00', 'EVALUACIÓN TÉCNICA Y DOCUMENTAL REGISTRADA', p: ProcesoAuditoria.evaluacion, h: HitoProceso.fin, hab: [ProcesoAuditoria.comercial]),
        _ev('2026-10-05 10:00', 'COTIZACIÓN GENERADA: v1', p: ProcesoAuditoria.comercial, h: HitoProceso.fin, hab: [ProcesoAuditoria.aprobacionCliente]),
        _ev('2026-10-06 15:00', 'SOLICITUD DE MODIFICACIÓN: CAMBIAR X', p: ProcesoAuditoria.aprobacionCliente, h: HitoProceso.fin, hab: [ProcesoAuditoria.comercial]),
        _ev('2026-10-06 17:00', 'COTIZACIÓN GENERADA: v2', p: ProcesoAuditoria.comercial, h: HitoProceso.fin, hab: [ProcesoAuditoria.aprobacionCliente]),
        _ev('2026-10-07 09:00', 'APROBACIÓN COMERCIAL - Órdenes anexadas', p: ProcesoAuditoria.aprobacionCliente, h: HitoProceso.fin, hab: [ProcesoAuditoria.costos, ProcesoAuditoria.compras]),
      ];
      final t = _totales(h);
      expect(t['En cotización'], 4); // 2 h + 2 h
      expect(t['Proforma enviada'], 45); // 29 h + 16 h
      expect(t.containsKey('Reproceso'), isFalse);
    });

    test('Cambio forzado por admin: reinicia el reloj; la etapa destino cuenta desde el cambio', () {
      final h = [
        _ev('2026-08-17 08:00', 'APROBACIÓN COMERCIAL - Órdenes anexadas', p: ProcesoAuditoria.aprobacionCliente, h: HitoProceso.fin, hab: [ProcesoAuditoria.costos, ProcesoAuditoria.compras]),
        _ev('2026-08-17 11:10', 'INICIO DE TRABAJO EN CAMPO / TALLER', p: ProcesoAuditoria.taller, h: HitoProceso.inicio),
        // El admin devuelve el ticket a Comercial a las 12:00.
        _ev('2026-08-17 12:00', 'ADMIN: CAMBIO FORZADO A "COMERCIAL" -- Motivo: motor dañado', p: ProcesoAuditoria.admin, h: HitoProceso.fin, hab: [ProcesoAuditoria.comercial]),
        _ev('2026-08-17 15:00', 'COTIZACIÓN GENERADA: motor nuevo', p: ProcesoAuditoria.comercial, h: HitoProceso.fin, hab: [ProcesoAuditoria.aprobacionCliente]),
        _ev('2026-08-18 09:00', 'APROBACIÓN COMERCIAL - Órdenes anexadas', p: ProcesoAuditoria.aprobacionCliente, h: HitoProceso.fin, hab: [ProcesoAuditoria.costos, ProcesoAuditoria.compras]),
        _ev('2026-08-18 10:00', 'BODEGA: DESPACHO TOTAL Y TRANSFERENCIA A PROCESO DE TRABAJO (1 ítems entregados)', p: ProcesoAuditoria.bodega, h: HitoProceso.fin, hab: [ProcesoAuditoria.taller]),
        _ev('2026-08-18 18:00', 'TALLER: EVIDENCIA REGISTRADA. TÉCNICOS: A. EQUIPO LISTO.', p: ProcesoAuditoria.taller, h: HitoProceso.fin, hab: [ProcesoAuditoria.revisionPagos]),
      ];
      final t = _totales(h);
      expect(t['En cotización'], 3); // desde el cambio forzado (12:00) hasta la cotización (15:00)
      // El taller vuelve a contar desde que se le habilitó de nuevo (despacho),
      // no desde el primer "Iniciar trabajo" (antes de la devolución).
      expect(t['Proceso de Trabajo'], 8);
      expect(t.keys.where((k) => k.toUpperCase().contains('ADMIN')), isEmpty);
    });

    test('Un evento sin etiqueta en un ticket nuevo aparece como "Sin clasificar"', () {
      final h = [
        _ev('2026-10-01 08:00', 'CREACIÓN DE REQUERIMIENTO', p: ProcesoAuditoria.recepcion, h: HitoProceso.fin, hab: [ProcesoAuditoria.evaluacion]),
        _ev('2026-10-01 12:00', 'ACCIÓN NUEVA OLVIDADA'),
      ];
      expect(_totales(h)['Sin clasificar'], 4);
    });

    test('Ajustes de admin y anulaciones no entran en los promedios', () {
      final h = [
        _ev('2026-10-01 08:00', 'CREACIÓN DE REQUERIMIENTO', p: ProcesoAuditoria.recepcion, h: HitoProceso.fin, hab: [ProcesoAuditoria.evaluacion]),
        _ev('2026-10-01 12:00', 'ANULACIÓN DE TICKET', p: ProcesoAuditoria.otro, h: HitoProceso.fin),
      ];
      expect(_totales(h), isEmpty);
    });
  });

  group('Tickets antiguos (sin etiquetas, por texto)', () {
    final antiguo = [
      _ev('2026-09-01 08:00', 'CREACIÓN DE REQUERIMIENTO'),
      _ev('2026-09-01 10:00', 'RECEPCIÓN FÍSICA Y EMISIÓN DE ACTA'),
      _ev('2026-09-02 09:00', 'EVALUACIÓN TÉCNICA Y DOCUMENTAL REGISTRADA'),
      _ev('2026-09-02 15:00', 'COTIZACIÓN GENERADA: x'),
      _ev('2026-09-03 11:00', 'APROBACIÓN COMERCIAL - Órdenes anexadas'),
      _ev('2026-09-03 14:00', 'FASE COSTOS - Código Proyecto Asignado: P-88'),
      _ev('2026-09-03 16:00', 'ÓRDENES DE COMPRA EXTERNAS REGISTRADAS MÚLTIPLE'),
      _ev('2026-09-04 09:00', 'COMPRAS: VALIDACIÓN PARCIAL DE REPUESTOS (1/3 validados)'),
      _ev('2026-09-04 10:00', 'INICIO DE TRABAJO EN CAMPO / TALLER'),
      _ev('2026-09-04 15:00', 'BODEGA: DESPACHO PARCIAL (1 ítems entregados)'),
      _ev('2026-09-05 12:00', 'COMPRAS: VALIDACIÓN COMPLETA (3/3) Y TRANSFERENCIA A BODEGA'),
      _ev('2026-09-05 16:00', 'BODEGA: DESPACHO TOTAL Y TRANSFERENCIA A PROCESO DE TRABAJO (3 ítems entregados)'),
      _ev('2026-09-06 17:00', 'TALLER: EVIDENCIA REGISTRADA. TÉCNICOS: A. EQUIPO LISTO.'),
      _ev('2026-09-07 10:00', 'REVISIÓN COMERCIAL COMPLETADA. EQUIPO TRANSFERIDO A DESPACHO LOGÍSTICO.'),
      _ev('2026-09-07 12:00', 'CARGA DE FACTURA. Obs: x'),
    ];

    test('Se suma por ticket y se corrigen las etiquetas', () {
      expect(TiemposPorProcesoService.usaEtiquetas(antiguo), isFalse);
      final t = _totales(antiguo);
      expect(t['Recepción'], 2);
      expect(t['Evaluación Técnica'], 23);
      expect(t['En cotización'], 6); // antes caía en "Proforma enviada"
      expect(t['Proforma enviada'], 20); // antes caía en "En cotización"
      expect(t['Costos'], 3);
      expect(t['Compras'], 2);
      expect(t['Validación Bodega'], 17 + 21); // dos tramos del mismo ticket
      expect(t['Despacho'], 5 + 4);
      expect(t['Proceso de Trabajo'], 1 + 25);
      expect(t['Revisión de pagos'], 17); // revisión comercial final
      expect(t['Entrega'], 2); // factura: antes caía en "Revisión de pagos"
      final p = _partes(antiguo);
      expect(p['Recepción|Registro y acta'], 2);
      expect(p['Proceso de Trabajo|Antes de iniciar'], 1);
      expect(p['Proceso de Trabajo|Trabajo'], 25);
    });

    test('Un tramo de 0 minutos SÍ cuenta (el ticket entra en ese proceso con 0)', () {
      final h = [
        _ev('2026-09-03 08:00', 'CREACIÓN DE REQUERIMIENTO'),
        _ev('2026-09-03 08:54', 'COMPRAS LIBERADAS (ABASTECIMIENTO DIRECTO DESDE STOCK BODEGA)'),
        _ev('2026-09-03 08:54', 'ORDEN DE COMPRA VALIDADA EN BODEGA'),
      ];
      final t = _totales(h);
      expect(t['Compras'], 0.9);
      expect(t.containsKey('Validación Bodega'), isTrue);
      expect(t['Validación Bodega'], 0);
    });

    test('Correcciones de lectura: GUABO, Informe técnico, ADMIN, TALLER y Venta', () {
      expect(TiemposPorProcesoService.procesoPorTexto('EQUIPO ENVIADO DESDE EL GUABO RECIBIDO EN TALLER'), 'Recepción');
      expect(TiemposPorProcesoService.procesoPorTexto('Informe técnico adjuntado: x.pdf'), 'Proceso de Trabajo');
      expect(TiemposPorProcesoService.procesoPorTexto('ADMIN: CAMBIO FORZADO A "BODEGA" -- Motivo: x'), isNull);
      expect(TiemposPorProcesoService.procesoPorTexto('TALLER: REPUESTOS RECIBIDOS EN BODEGA POR [JUAN] (2/2 conformes). Trasladados a taller.'), 'Proceso de Trabajo');
      expect(TiemposPorProcesoService.procesoPorTexto('SUPERVISOR DECLARÓ: NO REQUIERE COMPRAS'), 'Evaluación Técnica');
      expect(TiemposPorProcesoService.procesoPorTexto('COTIZACIÓN DE REPUESTO ADJUNTADA POR COMPRAS'), 'Compras');
      expect(TiemposPorProcesoService.procesoPorTexto('COMPRAS: GESTIÓN DE REPUESTO SIN STOCK COMPLETADA (VENTA DE REPUESTO)'), 'Compras');
      expect(TiemposPorProcesoService.procesoPorTexto('ORDEN DE COMPRA VALIDADA EN BODEGA'), 'Validación Bodega');
      expect(TiemposPorProcesoService.procesoPorTexto('CARGA DE GUÍA DE REMISIÓN. Obs: x'), 'Entrega');
    });
  });

  test('Todas las barras del dashboard tienen nombre (excepto admin/otro)', () {
    for (final p in _procesos) {
      final etiqueta = p.etiquetaDashboard;
      if (p == ProcesoAuditoria.admin || p == ProcesoAuditoria.otro) {
        expect(etiqueta, isNull);
      } else {
        expect(etiqueta, isNotNull, reason: p.name);
      }
    }
  });

  group('Despacho desplegable: antes del picking / picking / validación simple', () {
    const d = TiemposPorProcesoService.despacho;
    final antes = '$d|${TiemposPorProcesoService.subAntesPicking}';
    final picking = '$d|${TiemposPorProcesoService.subPicking}';
    final simple = '$d|${TiemposPorProcesoService.subValidacionSimple}';
    EventoAuditoriaEntity creado(String f) => _ev(f, 'TICKET CREADO', p: ProcesoAuditoria.recepcion, h: HitoProceso.inicio);

    test('Picking normal: desde Validación de Bodega, partido en el inicio de picking', () {
      final h = [
        creado('2026-10-10 07:00'),
        _ev('2026-10-10 08:00', 'COMPRAS: VALIDACIÓN COMPLETA (2/2) Y TRANSFERENCIA A BODEGA', p: ProcesoAuditoria.validacionBodega, h: HitoProceso.fin, hab: [ProcesoAuditoria.bodega]),
        _ev('2026-10-10 15:30', 'BODEGA: INICIO DE PICKING', p: ProcesoAuditoria.bodega, h: HitoProceso.avance),
        _ev('2026-10-10 18:00', 'BODEGA: PICKING PARCIAL D1 LISTO PARA RETIRO (2 ítems)', p: ProcesoAuditoria.bodega, h: HitoProceso.avance),
        _ev('2026-10-11 07:36', 'BODEGA: FIN DE PICKING Y TRANSFERENCIA A PROCESO DE TRABAJO (1 despacho(s))', p: ProcesoAuditoria.bodega, h: HitoProceso.fin, hab: [ProcesoAuditoria.taller]),
      ];
      final partes = _partes(h);
      expect(partes[antes], 7.5);
      expect(partes[picking], closeTo(16.1, 0.001)); // 15:30 → 07:36 = 16h 06m
      expect(partes.containsKey(simple), isFalse);
      // Las partes suman exactamente el total de Despacho (23h 36m).
      expect(_totales(h)[d], closeTo(23.6, 0.001));
    });

    test('Sin falta nada (sin Validación de Bodega): cuenta desde Costos', () {
      final h = [
        creado('2026-10-01 07:00'),
        _ev('2026-10-01 10:00', 'FASE COSTOS - Código Proyecto Asignado: P-1', p: ProcesoAuditoria.costos, h: HitoProceso.fin, hab: [ProcesoAuditoria.bodega]),
        _ev('2026-10-02 10:00', 'BODEGA: INICIO DE PICKING', p: ProcesoAuditoria.bodega, h: HitoProceso.avance),
        _ev('2026-10-02 14:00', 'BODEGA: FIN DE PICKING Y TRANSFERENCIA A PROCESO DE TRABAJO (1 despacho(s))', p: ProcesoAuditoria.bodega, h: HitoProceso.fin, hab: [ProcesoAuditoria.taller]),
      ];
      expect(_partes(h)[antes], 24);
      expect(_partes(h)[picking], 4);
    });

    test('Validación simple: todo en su propia parte, sin picking', () {
      final h = [
        creado('2026-10-01 07:00'),
        _ev('2026-10-01 10:00', 'FASE COSTOS - Código Proyecto Asignado: P-1', p: ProcesoAuditoria.costos, h: HitoProceso.fin, hab: [ProcesoAuditoria.bodega]),
        _ev('2026-10-01 13:00', 'BODEGA: DESPACHO TOTAL Y TRANSFERENCIA A PROCESO DE TRABAJO (VALIDACIÓN SIMPLE)', p: ProcesoAuditoria.bodega, h: HitoProceso.fin, hab: [ProcesoAuditoria.taller]),
      ];
      expect(_partes(h), {simple: 3});
    });

    test('Sin inicio de picking (ticket anterior al picking): todo en "Antes del picking"', () {
      final h = [
        creado('2026-10-01 07:00'),
        _ev('2026-10-01 10:00', 'FASE COSTOS - Código Proyecto Asignado: P-1', p: ProcesoAuditoria.costos, h: HitoProceso.fin, hab: [ProcesoAuditoria.bodega]),
        _ev('2026-10-01 12:00', 'BODEGA: DESPACHO PARCIAL (1 ítems entregados)', p: ProcesoAuditoria.bodega, h: HitoProceso.avance),
        _ev('2026-10-01 15:00', 'BODEGA: DESPACHO TOTAL Y TRANSFERENCIA A PROCESO DE TRABAJO (2 ítems entregados)', p: ProcesoAuditoria.bodega, h: HitoProceso.fin, hab: [ProcesoAuditoria.taller]),
      ];
      expect(_partes(h), {antes: 5});
    });

    test('Dos vueltas por Bodega: cada una se parte y se suman; picking de 0 minutos igual cuenta', () {
      final h = [
        creado('2026-10-01 07:00'),
        _ev('2026-10-01 08:00', 'COMPRAS: VALIDACIÓN COMPLETA (1/1) Y TRANSFERENCIA A BODEGA', p: ProcesoAuditoria.validacionBodega, h: HitoProceso.fin, hab: [ProcesoAuditoria.bodega]),
        _ev('2026-10-01 09:00', 'BODEGA: INICIO DE PICKING', p: ProcesoAuditoria.bodega, h: HitoProceso.avance),
        _ev('2026-10-01 11:00', 'BODEGA: FIN DE PICKING Y TRANSFERENCIA A PROCESO DE TRABAJO (1 despacho(s))', p: ProcesoAuditoria.bodega, h: HitoProceso.fin, hab: [ProcesoAuditoria.taller]),
        _ev('2026-10-03 08:00', 'ADMIN: CAMBIO FORZADO A BODEGA', p: ProcesoAuditoria.admin, hab: [ProcesoAuditoria.bodega]),
        _ev('2026-10-03 10:00', 'BODEGA: INICIO DE PICKING', p: ProcesoAuditoria.bodega, h: HitoProceso.avance),
        _ev('2026-10-03 10:00', 'BODEGA: FIN DE PICKING Y TRANSFERENCIA A PROCESO DE TRABAJO (2 despacho(s))', p: ProcesoAuditoria.bodega, h: HitoProceso.fin, hab: [ProcesoAuditoria.taller]),
      ];
      final partes = _partes(h);
      expect(partes[antes], 1 + 2);
      expect(partes[picking], 2 + 0);
      expect(TiemposPorProcesoService.calcular(h).where((t) => t.subproceso == TiemposPorProcesoService.subPicking).length, 1,
          reason: 'mismo usuario: un solo acumulado de picking');
    });
  });
}
