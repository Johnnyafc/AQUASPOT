// test/creacion_codigos_mantenimiento_test.dart
//
// Mantenimiento interno con repuestos SIN CÓDIGO: los con código pasan a
// Compras, los sin código (con su ficha) esperan en Costos; si todos son
// sin código el ticket queda en Costos. Costos registra los códigos: pasan a
// la lista de Bodega, al inventario con stock 0 y, si esperaba en Costos, el
// ticket pasa a Compras. Guardado en Firestore y use case.

import 'package:aquaspot_postventa/core/enum/proceso_auditoria.dart';
import 'package:aquaspot_postventa/core/enum/rol_usuario.dart';
import 'package:aquaspot_postventa/core/enum/ticket_enums.dart';
import 'package:aquaspot_postventa/core/errors/failures.dart';
import 'package:aquaspot_postventa/features/tickets/data/models/ticket_model.dart';
import 'package:aquaspot_postventa/features/tickets/domain/entities/actividad_mantenimiento.dart';
import 'package:aquaspot_postventa/features/tickets/domain/entities/cambio_mantenimiento_interno.dart';
import 'package:aquaspot_postventa/features/tickets/domain/entities/ficha_creacion_repuesto_entity.dart';
import 'package:aquaspot_postventa/features/tickets/domain/entities/mantenimiento_interno_entity.dart';
import 'package:aquaspot_postventa/features/tickets/domain/entities/repuesto_registrado_entity.dart';
import 'package:aquaspot_postventa/features/tickets/domain/entities/ticket_entity.dart';
import 'package:aquaspot_postventa/features/tickets/domain/repositories/ticket_repository.dart';
import 'package:aquaspot_postventa/features/tickets/domain/services/creacion_codigos_mantenimiento_service.dart';
import 'package:aquaspot_postventa/features/tickets/domain/services/estado_despacho_service.dart';
import 'package:aquaspot_postventa/features/tickets/domain/services/evaluacion_mantenimiento_service.dart';
import 'package:aquaspot_postventa/features/tickets/domain/services/formulario_mantenimiento_service.dart';
import 'package:aquaspot_postventa/features/tickets/domain/usecases/registrar_codigos_mantenimiento_usecase.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';

typedef C = CreacionCodigosMantenimientoService;

final ahora = DateTime(2026, 10, 27, 15);

TicketEntity ticketCosechadora() => FormularioMantenimientoService.construirTicket(
      const DatosMantenimientoInterno(
        tipoActivo: TipoActivoMantenimiento.cosechadora,
        serieOPlaca: 'AQ2',
        horometro: 1200,
        detalle: 'Fuga en la bomba',
        cantidadFotos: 1,
        tieneFotoLectura: true,
      ),
      usuarioNombre: 'Op',
      rol: RolUsuario.requerimiento,
      ahora: ahora,
    ).copyWith(id: 'REQ-00300');

const sello = RepuestoRegistradoEntity(codigo: '', descripcion: 'SELLO BOMBA 40MM', cantidad: 2);
const filtro = RepuestoRegistradoEntity(codigo: 'F-10', descripcion: 'FILTRO ACEITE', cantidad: 1);

final fichas = {
  C.claveFicha('SELLO BOMBA 40MM'): const FichaCreacionRepuestoEntity(
    nombre: 'SELLO BOMBA 40MM',
    familiaPieza: 'SELLO',
    categoria: 'REPUESTOS',
    udm: 'UNIDAD',
  ),
};

ActividadMantenimiento actividad(List<RepuestoRegistradoEntity> repuestos) => ActividadMantenimiento(
      codigo: 'NUEVA-01',
      nombre: 'Cambio de sello',
      horasHombre: 2,
      observacion: 'Sello roto',
      repuestos: repuestos,
    );

TicketEntity evaluado(List<RepuestoRegistradoEntity> repuestos) => EvaluacionMantenimientoService.construirTicketEvaluado(
      ticketCosechadora(),
      [actividad(repuestos)],
      fichas: fichas,
      necesitaCompras: true,
      usuarioNombre: 'Téc',
      rol: RolUsuario.tecnico,
      ahora: ahora,
    );

class _RepoFalso implements ITicketRepository {
  final TicketEntity actual;
  TicketEntity? guardado;
  CambioMantenimientoInterno? cambio;

  _RepoFalso(this.actual);

  @override
  Future<Either<Failure, TicketEntity>> actualizarMantenimientoEnTransaccion({
    required String ticketId,
    required CambioMantenimientoInterno Function(TicketEntity actual) aplicar,
  }) async {
    try {
      cambio = aplicar(actual);
      guardado = cambio!.ticket;
      return Right(guardado!);
    } on CambioMantenimientoRechazado catch (e) {
      return Left(ValidationFailure(e.mensaje));
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('Al guardar la evaluación', () {
    test('Con y sin código: Compras con los que tienen código; los sin código esperan en Costos', () {
      final t = evaluado([filtro, sello]);
      expect(t.estadoActual, EstadoTicket.compras);
      expect(t.itemsDespachoBodega.map((i) => i.codigo), ['F-10']);
      expect(C.requiereCreacionCodigos(t), isTrue);
      expect(C.esperaSoloCodigos(t), isFalse, reason: 'Compras ya tiene el filtro');
      expect(C.indicesPendientes(t), [0]);
    });

    test('Solo sin código: el ticket queda en Costos y nada va a Compras', () {
      final t = evaluado([sello]);
      expect(t.estadoActual, EstadoTicket.costos);
      expect(t.itemsDespachoBodega, isEmpty);
      expect(C.esperaSoloCodigos(t), isTrue);
      expect(t.historialEventos.last.habilita, [ProcesoAuditoria.costos]);
    });

    test('Sin repuestos sin código: igual que antes, a Compras y nada para Costos', () {
      final t = evaluado([filtro]);
      expect(t.estadoActual, EstadoTicket.compras);
      expect(C.requiereCreacionCodigos(t), isFalse);
      expect(t.mantenimientoInterno!.repuestosPorCodificar, isEmpty);
    });

    test('La ficha inicial toma la descripción y la unidad', () {
      final f = C.fichaInicial(const RepuestoRegistradoEntity(codigo: '', descripcion: 'perno inox', unidad: 'JUEGO'));
      expect(f.nombre, 'PERNO INOX');
      expect(f.udm, 'JUEGO');
      expect(f.completa, isFalse);
    });

    test('El repuesto sin código y su ficha se guardan y se leen igual en Firestore', () {
      final t = evaluado([filtro, sello]);
      final json = TicketModel.fromEntity(t).toJson()..['id'] = t.id;
      final leido = TicketModel.fromJson(json);
      expect(leido.mantenimientoInterno, t.mantenimientoInterno);
      expect(leido.mantenimientoInterno!.repuestosPorCodificar.single.ficha.familiaPieza, 'SELLO');
    });
  });

  group('Costos registra los códigos', () {
    const codigo = CodigoCreadoMantenimiento(indice: 0, codigo: 'SEL-040', descripcion: 'SELLO BOMBA 40 MM');

    test('Esperaba en Costos: los repuestos van a Bodega, al inventario y el ticket pasa a Compras', () {
      final c = C.aplicarCodigos(evaluado([sello]), [codigo], usuarioNombre: 'Costos', usuarioRol: 'COSTOS', ahora: ahora);
      final t = c.ticket;
      expect(t.estadoActual, EstadoTicket.compras);
      expect(t.itemsDespachoBodega.single.codigo, 'SEL-040');
      expect(t.itemsDespachoBodega.single.descripcion, 'SELLO BOMBA 40 MM');
      expect(t.itemsDespachoBodega.single.cantidadSolicitada, 2);
      expect(t.itemsDespachoBodega.single.fechaSolicitud, ahora);
      expect(t.evaluacionTecnica!.repuestosTaller.single.codigo, 'SEL-040');
      final r = t.mantenimientoInterno!.repuestosPorCodificar.single;
      expect(r.pendiente, isFalse);
      expect(r.creadoPor, 'Costos');
      expect(C.requiereCreacionCodigos(t), isFalse);
      expect(c.inventarioNuevos.single.codigo, 'SEL-040');
      expect(c.evento.accion, contains('PASA A COMPRAS'));
      expect(c.evento.proceso, ProcesoAuditoria.costos);
    });

    test('Ya en Compras: se agregan a los repuestos sin cambiar el estado ni tocar los existentes', () {
      final antes = evaluado([filtro, sello]);
      final t = C.aplicarCodigos(antes, [codigo], usuarioNombre: 'Costos', usuarioRol: 'COSTOS', ahora: ahora).ticket;
      expect(t.estadoActual, EstadoTicket.compras);
      expect(t.itemsDespachoBodega.map((i) => i.codigo), ['F-10', 'SEL-040']);
      expect(t.itemsDespachoBodega.first, antes.itemsDespachoBodega.first);
      expect(t.evaluacionTecnica!.repuestosTaller.map((r) => r.codigo), ['F-10', 'SEL-040']);
    });

    test('Rechaza si los pendientes cambiaron o ya no hay pendientes', () {
      final t = evaluado([sello]);
      expect(
        () => C.aplicarCodigos(t, const [CodigoCreadoMantenimiento(indice: 3, codigo: 'X', descripcion: 'X')],
            usuarioNombre: 'C', usuarioRol: 'COSTOS', ahora: ahora),
        throwsA(isA<CambioMantenimientoRechazado>()),
      );
      final listo = C.aplicarCodigos(t, [codigo], usuarioNombre: 'C', usuarioRol: 'COSTOS', ahora: ahora).ticket;
      expect(
        () => C.aplicarCodigos(listo, [codigo], usuarioNombre: 'C', usuarioRol: 'COSTOS', ahora: ahora),
        throwsA(isA<CambioMantenimientoRechazado>()),
      );
    });

    test('Caracol: aparta el stock de los códigos creados (el picking lo libera); cosechadora no', () {
      final caracol = EvaluacionMantenimientoService.construirTicketEvaluado(
        ticketCosechadora().copyWith(equipo: TipoEquipo.Caracol),
        [actividad([sello])],
        fichas: fichas,
        necesitaCompras: true,
        usuarioNombre: 'Téc',
        rol: RolUsuario.tecnico,
        ahora: ahora,
      );
      final c = C.aplicarCodigos(caracol, [codigo], usuarioNombre: 'C', usuarioRol: 'COSTOS', ahora: ahora);
      expect(c.reservas, {'SEL-040': 2.0});
      expect(C.aplicarCodigos(evaluado([sello]), [codigo], usuarioNombre: 'C', usuarioRol: 'COSTOS', ahora: ahora).reservas,
          isEmpty);
    });

    test('Ya en Proceso de Trabajo o más allá: no se agregan repuestos', () {
      final enTaller = evaluado([filtro, sello]).copyWith(estadoActual: EstadoTicket.procesoTrabajo);
      expect(
        () => C.aplicarCodigos(enTaller, [codigo], usuarioNombre: 'C', usuarioRol: 'COSTOS', ahora: ahora),
        throwsA(isA<CambioMantenimientoRechazado>()),
      );
    });

    test('Bodega no puede finalizar el picking mientras haya repuestos esperando código', () {
      final t = evaluado([filtro, sello]);
      expect(EstadoDespachoService.puedeFinalizarPicking(t), isFalse);
      expect(EstadoDespachoService.motivoNoFinaliza(t), isNotNull);
    });

    test('Use case: valida código y descripción, y no repetir códigos', () async {
      final repo = _RepoFalso(evaluado([sello]));
      final uc = RegistrarCodigosMantenimientoUseCase(repo);
      final vacio = await uc(
        ticketId: 'REQ-00300',
        codigos: const [CodigoCreadoMantenimiento(indice: 0, codigo: ' ', descripcion: 'X')],
        usuarioNombre: 'C',
        usuarioRol: 'COSTOS',
      );
      expect(vacio.isLeft(), isTrue);
      expect(repo.guardado, isNull);
      final ok = await uc(ticketId: 'REQ-00300', codigos: [codigo], usuarioNombre: 'C', usuarioRol: 'COSTOS', ahora: ahora);
      expect(ok.fold((_) => null, (t) => t.estadoActual), EstadoTicket.compras);
    });

    test('Use case: repetidos', () async {
      final repo = _RepoFalso(evaluado([sello]));
      final r = await RegistrarCodigosMantenimientoUseCase(repo)(
        ticketId: 'REQ-00300',
        codigos: const [
          CodigoCreadoMantenimiento(indice: 0, codigo: 'A-1', descripcion: 'X'),
          CodigoCreadoMantenimiento(indice: 1, codigo: 'a-1', descripcion: 'Y'),
        ],
        usuarioNombre: 'C',
        usuarioRol: 'COSTOS',
      );
      expect(r.fold((f) => f.message, (_) => ''), contains('repetidos'));
    });
  });
}
