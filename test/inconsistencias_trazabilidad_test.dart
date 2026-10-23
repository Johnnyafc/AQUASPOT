import 'package:flutter_test/flutter_test.dart';
import 'package:aquaspot_postventa/features/tickets/domain/entities/evento_auditoria_entity.dart';
import 'package:aquaspot_postventa/features/tickets/domain/services/inconsistencias_trazabilidad_service.dart';

EventoAuditoriaEntity _ev(String fecha, String accion) => EventoAuditoriaEntity(
      accion: accion,
      usuarioNombre: 'U',
      usuarioRol: 'ROL',
      timestamp: DateTime.parse(fecha),
    );

final _ahora = DateTime.parse('2026-10-07 12:00');

List<String> _reglas(List<EventoAuditoriaEntity> h, {bool finalizado = false}) =>
    InconsistenciasTrazabilidadService.detectar(ticketId: 'REQ-1', historial: h, finalizado: finalizado, ahora: _ahora)
        .map((i) => i.reglaId)
        .toList();

// Flujo normal completo, sin nada raro.
final _normal = [
  _ev('2026-09-01 08:00', 'CREACIÓN DE REQUERIMIENTO'),
  _ev('2026-09-01 10:00', 'RECEPCIÓN FÍSICA Y EMISIÓN DE ACTA'),
  _ev('2026-09-02 09:00', 'EVALUACIÓN TÉCNICA Y DOCUMENTAL REGISTRADA'),
  _ev('2026-09-02 15:00', 'COTIZACIÓN GENERADA: x'),
  _ev('2026-09-03 11:00', 'APROBACIÓN COMERCIAL - Órdenes anexadas'),
  _ev('2026-09-03 14:00', 'FASE COSTOS - Código Proyecto Asignado: P-1'),
  _ev('2026-09-03 16:00', 'ÓRDENES DE COMPRA EXTERNAS REGISTRADAS MÚLTIPLE'),
  _ev('2026-09-04 10:00', 'INICIO DE TRABAJO EN CAMPO / TALLER'),
  _ev('2026-09-05 12:00', 'COMPRAS: VALIDACIÓN EN BODEGA APROBADA - TRANSFERIDO DIRECTO A PROCESO DE TRABAJO'),
  _ev('2026-09-06 17:00', 'TALLER: EVIDENCIA REGISTRADA. TÉCNICOS: A. EQUIPO LISTO.'),
  _ev('2026-09-07 10:00', 'REVISIÓN COMERCIAL COMPLETADA. EQUIPO TRANSFERIDO A DESPACHO LOGÍSTICO.'),
  _ev('2026-09-07 12:00', 'CARGA DE GUÍA DE REMISIÓN. Obs: x'),
];

void main() {
  test('Un flujo normal no genera inconsistencias (paralelos Compras/Taller permitidos)', () {
    expect(_reglas(_normal, finalizado: true), isEmpty);
  });

  test('1. Orden de flujo: evaluación después de Compras', () {
    final h = [
      _ev('2026-09-01 08:00', 'CREACIÓN DE REQUERIMIENTO'),
      _ev('2026-09-03 16:00', 'ÓRDENES DE COMPRA EXTERNAS REGISTRADAS MÚLTIPLE'),
      _ev('2026-09-04 09:00', 'EVALUACIÓN TÉCNICA Y DOCUMENTAL REGISTRADA'),
    ];
    expect(_reglas(h), [ReglasInconsistencia.ordenFlujo]);
  });

  test('1. Orden de flujo: una modificación de proforma permite volver a cotizar', () {
    final h = [
      _ev('2026-09-02 15:00', 'COTIZACIÓN GENERADA: v1'),
      _ev('2026-09-03 10:00', 'SOLICITUD DE MODIFICACIÓN: CAMBIAR X'),
      _ev('2026-09-03 12:00', 'COTIZACIÓN GENERADA: v2'),
      _ev('2026-09-04 09:00', 'APROBACIÓN COMERCIAL - Órdenes anexadas'),
    ];
    expect(_reglas(h), isEmpty);
  });

  test('1. Orden de flujo: tras un cambio forzado por admin no se marca', () {
    final h = [
      _ev('2026-08-17 11:10', 'INICIO DE TRABAJO EN CAMPO / TALLER'),
      _ev('2026-08-17 12:00', 'ADMIN: CAMBIO FORZADO A "COMERCIAL" -- Motivo: motor dañado'),
      _ev('2026-08-17 15:00', 'COTIZACIÓN GENERADA: motor nuevo'),
      _ev('2026-08-18 09:00', 'APROBACIÓN COMERCIAL - Órdenes anexadas'),
    ];
    expect(_reglas(h), isEmpty);
  });

  test('1. Orden de flujo: la misma devolución hecha en Firebase (sin ADMIN) sí se marca', () {
    final h = [
      _ev('2026-08-17 11:10', 'INICIO DE TRABAJO EN CAMPO / TALLER'),
      _ev('2026-08-17 11:27', 'COTIZACIÓN GENERADA: motor nuevo'),
      _ev('2026-08-17 11:28', 'APROBACIÓN COMERCIAL - Órdenes anexadas'),
    ];
    expect(_reglas(h).where((r) => r == ReglasInconsistencia.ordenFlujo).length, 2);
  });

  test('2. Falta un paso: finalizado sin evaluación', () {
    final h = _normal.where((e) => !e.accion.startsWith('EVALUACIÓN')).toList();
    final hallazgos = InconsistenciasTrazabilidadService.detectar(ticketId: 'REQ-1', historial: h, finalizado: true, ahora: _ahora);
    expect(hallazgos.map((i) => i.reglaId), [ReglasInconsistencia.faltaPaso]);
    expect(hallazgos.single.detalle, contains('Evaluación Técnica'));
    // En un ticket en curso no se exige.
    expect(_reglas(h, finalizado: false), isEmpty);
  });

  test('3. Mismo minuto: Compras liberó y validó en bodega a la vez', () {
    final h = [
      _ev('2026-09-03 08:00', 'CREACIÓN DE REQUERIMIENTO'),
      _ev('2026-09-03 08:54', 'COMPRAS LIBERADAS (ABASTECIMIENTO DIRECTO DESDE STOCK BODEGA)'),
      _ev('2026-09-03 08:54', 'ORDEN DE COMPRA VALIDADA EN BODEGA'),
    ];
    expect(_reglas(h), [ReglasInconsistencia.mismoMinuto]);
  });

  test('4. Creado tarde: recibido desde El Guabo 6 minutos después de crearlo', () {
    final h = [
      _ev('2026-08-26 11:10', 'CREACIÓN DE REQUERIMIENTO'),
      _ev('2026-08-26 11:16', 'EQUIPO ENVIADO DESDE EL GUABO RECIBIDO EN TALLER'),
    ];
    expect(_reglas(h), [ReglasInconsistencia.creadoTarde]);
  });

  test('5. Fecha fuera de rango: futura y anterior a la creación', () {
    final h = [
      _ev('2026-09-01 07:00', 'EVALUACIÓN TÉCNICA Y DOCUMENTAL REGISTRADA'),
      _ev('2026-09-01 08:00', 'CREACIÓN DE REQUERIMIENTO'),
      _ev('2026-10-09 10:00', 'COTIZACIÓN GENERADA: x'),
    ];
    final r = _reglas(h);
    expect(r.where((x) => x == ReglasInconsistencia.fechaFueraDeRango).length, 2);
  });

  test('6. Tiempo atípico: más de 3 veces la mediana y al menos 8 h', () {
    final horas = {
      for (var i = 1; i <= 5; i++) 'T$i': {'Evaluación Técnica': 10.0},
      'T6': {'Evaluación Técnica': 45.0},
      'T7': {'Evaluación Técnica': 25.0},
    };
    final hallazgos = InconsistenciasTrazabilidadService.detectarAtipicos(
      horasPorTicket: horas,
      finalizados: horas.keys.toSet(),
    );
    expect(hallazgos.map((i) => i.ticketId), ['T6']);
    expect(hallazgos.single.reglaId, ReglasInconsistencia.tiempoAtipico);
  });

  test('6. Tiempo atípico: sin suficientes tickets no se calcula lo típico', () {
    final hallazgos = InconsistenciasTrazabilidadService.detectarAtipicos(
      horasPorTicket: {'A': {'Costos': 1.0}, 'B': {'Costos': 100.0}},
      finalizados: {'A', 'B'},
    );
    expect(hallazgos, isEmpty);
  });

  test('La clave para "Revisado" combina regla y detalle', () {
    const i = InconsistenciaTicket(ticketId: 'REQ-1', reglaId: ReglasInconsistencia.faltaPaso, detalle: 'Finalizado sin «Evaluación Técnica»');
    expect(i.clave, 'falta_paso: Finalizado sin «Evaluación Técnica»');
    expect(i.regla, 'Falta un paso esperado');
  });
}
