// test/flujo_mantenimiento_test.dart
//
// Mantenimiento interno después de evaluar: destino según el stock ACTUAL
// (sin repuestos → Proceso de Trabajo; "No requiere compras" o todo con
// stock → Despacho Bodega; si falta algo → Compras; con repuestos sin código
// → como quedó) y cierre: la evidencia del taller lo pasa a Finalizado
// (reparación sigue a Validación de Facturación).

import 'package:aquaspot_postventa/core/enum/proceso_auditoria.dart';
import 'package:aquaspot_postventa/core/enum/rol_usuario.dart';
import 'package:aquaspot_postventa/core/enum/ticket_enums.dart';
import 'package:aquaspot_postventa/features/tickets/domain/entities/actividad_mantenimiento.dart';
import 'package:aquaspot_postventa/features/tickets/domain/entities/ficha_creacion_repuesto_entity.dart';
import 'package:aquaspot_postventa/features/tickets/domain/entities/mantenimiento_interno_entity.dart';
import 'package:aquaspot_postventa/features/tickets/domain/entities/repuesto_registrado_entity.dart';
import 'package:aquaspot_postventa/features/tickets/domain/entities/ticket_entity.dart';
import 'package:aquaspot_postventa/features/tickets/domain/services/cierre_trabajo_service.dart';
import 'package:aquaspot_postventa/features/tickets/domain/services/creacion_codigos_mantenimiento_service.dart';
import 'package:aquaspot_postventa/features/tickets/domain/services/evaluacion_mantenimiento_service.dart';
import 'package:aquaspot_postventa/features/tickets/domain/services/formulario_mantenimiento_service.dart';
import 'package:flutter_test/flutter_test.dart';

typedef S = EvaluacionMantenimientoService;

final ahora = DateTime(2026, 10, 28, 11);

TicketEntity creado() => FormularioMantenimientoService.construirTicket(
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
    ).copyWith(id: 'REQ-9');

const filtro = RepuestoRegistradoEntity(codigo: 'F-10', descripcion: 'FILTRO', cantidad: 2);
const aceite = RepuestoRegistradoEntity(codigo: 'A-1', descripcion: 'ACEITE', cantidad: 4);
const sello = RepuestoRegistradoEntity(codigo: '', descripcion: 'SELLO 40MM', cantidad: 1);

TicketEntity evaluado(List<RepuestoRegistradoEntity> repuestos, {bool necesitaCompras = true}) => S.construirTicketEvaluado(
      creado(),
      [ActividadMantenimiento(codigo: 'NUEVA-01', nombre: 'Cambio', horasHombre: 2, observacion: 'ok', repuestos: repuestos)],
      fichas: {
        CreacionCodigosMantenimientoService.claveFicha('SELLO 40MM'):
            const FichaCreacionRepuestoEntity(nombre: 'SELLO', familiaPieza: 'SELLO', categoria: 'REP', udm: 'UNIDAD'),
      },
      necesitaCompras: necesitaCompras,
      usuarioNombre: 'Téc',
      rol: RolUsuario.tecnico,
      ahora: ahora,
    );

void main() {
  group('Destino tras evaluar (stock actual)', () {
    test('Sin repuestos: directo a Proceso de Trabajo', () {
      final t = S.conDestino(evaluado(const []), const {});
      expect(t.estadoActual, EstadoTicket.procesoTrabajo);
      expect(t.historialEventos.last.habilita, [ProcesoAuditoria.taller]);
      expect(t.historialEventos.last.accion, contains('DIRECTO A PROCESO DE TRABAJO'));
    });

    test('Todo con stock suficiente: directo a Despacho Bodega, con el stock leído', () {
      final t = S.conDestino(evaluado([filtro, aceite]), const {'F-10': 5, 'A-1': 4});
      expect(t.estadoActual, EstadoTicket.bodega);
      expect(t.itemsDespachoBodega.map((i) => i.stockDisponibleAlEvaluar), [5, 4]);
      expect(t.historialEventos.last.habilita, [ProcesoAuditoria.bodega]);
      expect(t.historialEventos.length, evaluado([filtro]).historialEventos.length, reason: 'no agrega eventos, ajusta el último');
    });

    test('Falta algo: a Compras (el stock que otro ticket ya apartó no cuenta)', () {
      final t = S.conDestino(evaluado([filtro, aceite]), const {'F-10': 5, 'A-1': 3});
      expect(t.estadoActual, EstadoTicket.compras);
      expect(S.conDestino(evaluado([filtro]), const {}).estadoActual, EstadoTicket.compras, reason: 'sin inventario');
    });

    test('"No requiere compras" con repuestos: directo a Despacho Bodega aunque falte stock', () {
      final t = S.conDestino(evaluado([filtro], necesitaCompras: false), const {'F-10': 0});
      expect(t.estadoActual, EstadoTicket.bodega);
      expect(t.historialEventos.last.accion, contains('SIN COMPRAS'));
    });

    test('Con repuestos sin código: queda como estaba (Compras / Costos)', () {
      expect(S.conDestino(evaluado([filtro, sello]), const {'F-10': 9}).estadoActual, EstadoTicket.compras);
      expect(S.conDestino(evaluado([sello]), const {}).estadoActual, EstadoTicket.costos);
    });
  });

  group('Cierre del trabajo', () {
    test('Mantenimiento interno: la evidencia lo pasa a Finalizado', () {
      final t = creado();
      expect(CierreTrabajoService.estadoTrasEvidencia(t), EstadoTicket.finalizado);
      expect(CierreTrabajoService.procesosTrasEvidencia(t), isEmpty);
      expect(CierreTrabajoService.notaAuditoria(t), contains('FINALIZADO'));
    });

    test('Reparación: sigue a Validación de Facturación', () {
      final t = creado().copyWith(tipoRequerimiento: TipoRequerimiento.reparacion);
      expect(CierreTrabajoService.estadoTrasEvidencia(t), EstadoTicket.validacionFacturacion);
      expect(CierreTrabajoService.procesosTrasEvidencia(t), [ProcesoAuditoria.revisionPagos]);
      expect(CierreTrabajoService.notaAuditoria(t), isEmpty);
    });
  });
}
