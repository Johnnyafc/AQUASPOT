// test/flujo_reportes_automaticos_test.dart
//
// "Usa flujo con generación de reportes automáticos": a quién corresponde al
// evaluar (todo mantenimiento interno; reparación / garantía de Caracol,
// Cosechadora y Contador), quién lo usa después (marca o Caracol antiguo),
// tickets en curso sin marca, venta de repuesto aparte, validación por
// repuesto / liberación de reserva y la marca en Firestore.

import 'package:aquaspot_postventa/core/enum/rol_usuario.dart';
import 'package:aquaspot_postventa/core/enum/ticket_enums.dart';
import 'package:aquaspot_postventa/features/tickets/data/models/ticket_model.dart';
import 'package:aquaspot_postventa/features/tickets/domain/entities/actividad_mantenimiento.dart';
import 'package:aquaspot_postventa/features/tickets/domain/entities/evaluacion_tecnica_entity.dart';
import 'package:aquaspot_postventa/features/tickets/domain/entities/mantenimiento_interno_entity.dart';
import 'package:aquaspot_postventa/features/tickets/domain/entities/ticket_entity.dart';
import 'package:aquaspot_postventa/features/tickets/domain/services/evaluacion_mantenimiento_service.dart';
import 'package:aquaspot_postventa/features/tickets/domain/services/flujo_reportes_automaticos_service.dart';
import 'package:aquaspot_postventa/features/tickets/domain/services/flujo_venta_repuesto_service.dart';
import 'package:aquaspot_postventa/features/tickets/domain/services/formulario_mantenimiento_service.dart';
import 'package:flutter_test/flutter_test.dart';

typedef F = FlujoReportesAutomaticosService;

final ahora = DateTime(2026, 10, 28, 9);

TicketEntity mantenimiento() => FormularioMantenimientoService.construirTicket(
      const DatosMantenimientoInterno(
        tipoActivo: TipoActivoMantenimiento.cosechadora,
        serieOPlaca: 'AQ2',
        horometro: 100,
        detalle: 'Ruido en el motor',
        cantidadFotos: 1,
        tieneFotoLectura: true,
      ),
      usuarioNombre: 'Op',
      rol: RolUsuario.requerimiento,
      ahora: ahora,
    ).copyWith(id: 'REQ-1');

TicketEntity reparacion(TipoEquipo equipo, {TipoRequerimiento tipo = TipoRequerimiento.reparacion}) =>
    mantenimiento().copyWith(tipoRequerimiento: tipo, equipo: equipo);

const evaluada = EvaluacionTecnicaEntity(urlsAdjuntosPdf: [], observacion: 'x');

void main() {
  test('Al evaluar: todo mantenimiento y reparación / garantía de Caracol, Cosechadora y Contador', () {
    expect(F.correspondeAlEvaluar(mantenimiento()), isTrue);
    expect(F.correspondeAlEvaluar(mantenimiento().copyWith(equipo: TipoEquipo.Otros)), isTrue,
        reason: 'vehículo, aire y herramientas también');
    for (final e in [TipoEquipo.Caracol, TipoEquipo.Cosechadora, TipoEquipo.Contador]) {
      expect(F.correspondeAlEvaluar(reparacion(e)), isTrue, reason: e.name);
      expect(F.correspondeAlEvaluar(reparacion(e, tipo: TipoRequerimiento.reclamoGarantia)), isTrue, reason: e.name);
    }
    expect(F.correspondeAlEvaluar(reparacion(TipoEquipo.Otros)), isFalse);
    expect(F.correspondeAlEvaluar(reparacion(TipoEquipo.Caracol, tipo: TipoRequerimiento.ventaRepuesto)), isFalse);
  });

  test('Después: lo usa con la marca o si es un Caracol antiguo; los demás en curso siguen igual', () {
    final cosechadoraVieja = reparacion(TipoEquipo.Cosechadora).copyWith(evaluacionTecnica: evaluada);
    expect(F.usa(cosechadoraVieja), isFalse);
    expect(F.paraEvaluacion(cosechadoraVieja), isFalse, reason: 'una re-evaluación sigue con el flujo viejo');
    expect(F.usa(cosechadoraVieja.copyWith(usaFlujoReportesAutomaticos: true)), isTrue);
    expect(F.usa(reparacion(TipoEquipo.Caracol).copyWith(evaluacionTecnica: evaluada)), isTrue);
    expect(F.paraEvaluacion(reparacion(TipoEquipo.Contador)), isTrue, reason: 'aún no evaluado');
    expect(F.usa(mantenimiento().copyWith(evaluacionTecnica: evaluada)), isFalse,
        reason: 'mantenimiento ya evaluado sin marca termina como iba');
  });

  test('Plan Maestro del equipo', () {
    expect(F.equipoPlanMaestro(TipoEquipo.Cosechadora), 'cosechadora');
    expect(F.equipoPlanMaestro(TipoEquipo.Contador), 'contador');
    expect(F.equipoPlanMaestro(TipoEquipo.Caracol), 'caracol');
  });

  test('Venta de repuesto: su propia regla (validación por repuesto, sin liberar reservas)', () {
    final venta = reparacion(TipoEquipo.Caracol, tipo: TipoRequerimiento.ventaRepuesto)
        .copyWith(usaFlujoReportesAutomaticos: true);
    expect(F.usa(venta), isFalse);
    expect(FlujoVentaRepuestoService.validacionPorRepuesto(venta), isTrue);
    expect(FlujoVentaRepuestoService.liberaReservaEnPicking(venta), isFalse);
  });

  test('Validación por repuesto y liberación de reserva siguen a la regla', () {
    final nueva = reparacion(TipoEquipo.Cosechadora).copyWith(usaFlujoReportesAutomaticos: true);
    final vieja = reparacion(TipoEquipo.Cosechadora).copyWith(evaluacionTecnica: evaluada);
    expect(FlujoVentaRepuestoService.validacionPorRepuesto(nueva), isTrue);
    expect(FlujoVentaRepuestoService.liberaReservaEnPicking(nueva), isTrue);
    expect(FlujoVentaRepuestoService.validacionPorRepuesto(vieja), isFalse);
    expect(FlujoVentaRepuestoService.liberaReservaEnPicking(vieja), isFalse);
    expect(FlujoVentaRepuestoService.validacionPorRepuesto(reparacion(TipoEquipo.Otros)), isFalse);
  });

  test('La evaluación de mantenimiento marca el ticket, aparta stock y lo deja en la auditoría', () {
    final t = EvaluacionMantenimientoService.construirTicketEvaluado(
      mantenimiento(),
      const [ActividadMantenimiento(codigo: 'NUEVA-01', nombre: 'Revisión', horasHombre: 1, observacion: 'ok')],
      necesitaCompras: true,
      usuarioNombre: 'Téc',
      rol: RolUsuario.tecnico,
      ahora: ahora,
    );
    expect(t.usaFlujoReportesAutomaticos, isTrue);
    expect(EvaluacionMantenimientoService.reservaStock(t), isTrue);
    expect(t.historialEventos.last.accion, contains(F.etiqueta.toUpperCase()));
  });

  test('La marca se guarda solo cuando es sí (una copia vieja no la borra)', () {
    final con = reparacion(TipoEquipo.Contador).copyWith(usaFlujoReportesAutomaticos: true);
    final json = TicketModel.fromEntity(con).toJson()..['id'] = con.id;
    expect(json['usaFlujoReportesAutomaticos'], isTrue);
    expect(TicketModel.fromJson(json).usaFlujoReportesAutomaticos, isTrue);
    final sin = TicketModel.fromEntity(reparacion(TipoEquipo.Contador)).toJson();
    expect(sin.containsKey('usaFlujoReportesAutomaticos'), isFalse);
  });
}
