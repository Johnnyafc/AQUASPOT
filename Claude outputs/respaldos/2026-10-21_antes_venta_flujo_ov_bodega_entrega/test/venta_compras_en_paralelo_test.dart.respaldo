// test/venta_compras_en_paralelo_test.dart
//
// Venta de Repuesto con Compras EN PARALELO a la Evaluación técnica:
// ruteo, use cases (FinalizarEvaluacionVentaRepuestoUseCase y
// RegistrarCotizacionComprasVentaUseCase) con un repositorio falso que
// simula la transacción (aplica la regla sobre el ticket ACTUAL), y el orden
// en que terminan Compras y la Evaluación.

import 'package:aquaspot_postventa/core/enum/proceso_auditoria.dart';
import 'package:aquaspot_postventa/core/enum/ticket_enums.dart';
import 'package:aquaspot_postventa/core/errors/failures.dart';
import 'package:aquaspot_postventa/features/tickets/domain/entities/cambio_venta_repuesto.dart';
import 'package:aquaspot_postventa/features/tickets/domain/entities/linea_repuesto_venta_entity.dart';
import 'package:aquaspot_postventa/features/tickets/domain/entities/ticket_entity.dart';
import 'package:aquaspot_postventa/features/tickets/domain/repositories/ticket_repository.dart';
import 'package:aquaspot_postventa/features/tickets/domain/services/ruteo_venta_repuesto_service.dart';
import 'package:aquaspot_postventa/features/tickets/domain/usecases/finalizar_evaluacion_venta_repuesto_usecase.dart';
import 'package:aquaspot_postventa/features/tickets/domain/usecases/registrar_cotizacion_compras_venta_usecase.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';

/// Simula la transacción: aplica la regla sobre el ticket guardado.
class _RepoFalso implements ITicketRepository {
  TicketEntity actual;
  Failure? falla;
  int llamadas = 0;
  CambioVentaRepuesto? ultimoCambio;

  _RepoFalso(this.actual);

  @override
  Future<Either<Failure, TicketEntity>> actualizarVentaRepuestoEnTransaccion({
    required String ticketId,
    required CambioVentaRepuesto Function(TicketEntity actual) aplicar,
  }) async {
    llamadas++;
    if (falla != null) return Left(falla!);
    try {
      final c = aplicar(actual);
      ultimoCambio = c;
      actual = actual.copyWith(
        lineasRepuestoVenta: c.lineas,
        estadoActual: c.estadoNuevo ?? actual.estadoActual,
        historialEventos: [...actual.historialEventos, if (c.evento != null) c.evento!],
        urlsCotizacionCompras: [...actual.urlsCotizacionCompras, ...c.urlsCotizacionComprasNuevas],
      );
      return Right(actual);
    } on CambioVentaRechazado catch (e) {
      return Left(ValidationFailure(e.mensaje));
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _conStock = LineaRepuestoVentaEntity(
  codigo: 'A1', descripcion: 'FILTRO', unidad: 'UND', cantidad: 1, stockDisponibleAlEvaluar: 5);
const _sinStock = LineaRepuestoVentaEntity(
  codigo: 'B1', descripcion: 'BOMBA', unidad: 'UND', cantidad: 2, stockDisponibleAlEvaluar: 0);
const _porDeterminar = LineaRepuestoVentaEntity(
  codigo: '', descripcion: '', unidad: '', cantidad: 1, porDeterminar: true, descripcionCliente: 'Polea motor Deutz');

TicketEntity _ticket(List<LineaRepuestoVentaEntity> lineas, {EstadoTicket estado = EstadoTicket.recepcionFisica}) =>
    TicketEntity(
      id: 'REQ-00090',
      estadoActual: estado,
      sede: Sede.NINGUNO,
      clienteId: 'Cliente',
      campamento: '',
      nombreContacto: 'Contacto',
      telefonoContacto: '',
      emailContacto: '',
      equipo: TipoEquipo.Cosechadora,
      equipoDetalle: null,
      accesoriosRecibidos: null,
      numeroSerie: null,
      fallaReportada: '',
      historialEventos: const [],
      tipoRequerimiento: TipoRequerimiento.ventaRepuesto,
      lugarAtencion: LugarAtencion.noAplica,
      esRegistroCompleto: true,
      lineasRepuestoVenta: lineas,
    );

/// Lo que mandaría la pantalla de evaluación: la por determinar ya definida.
List<LineaRepuestoVentaEntity> _definidas(List<LineaRepuestoVentaEntity> vigentes, {required bool conStock}) => [
      for (final l in vigentes)
        l.porDeterminar
            ? l.copyWith(
                porDeterminar: false, codigo: 'POL-01', descripcion: 'POLEA', stockDisponibleAlEvaluar: conStock ? 3 : 0)
            : l,
    ];

void main() {
  final t0 = DateTime(2026, 10, 14, 9);

  group('Ruteo con Compras en paralelo', () {
    test('al crear: por determinar + sin stock → Evaluación y Compras habilitadas a la vez', () {
      final lineas = [_conStock, _sinStock, _porDeterminar];
      expect(RuteoVentaRepuestoService.destino(lineas), DestinoVentaRepuesto.evaluacion);
      expect(RuteoVentaRepuestoService.procesosHabilitadosAlCrear(lineas),
          [ProcesoAuditoria.evaluacion, ProcesoAuditoria.compras]);
      expect(RuteoVentaRepuestoService.comprasEnParalelo(_ticket(lineas)), isTrue);
    });

    test('al crear: por determinar y el resto con stock → solo Evaluación', () {
      final lineas = [_conStock, _porDeterminar];
      expect(RuteoVentaRepuestoService.procesosHabilitadosAlCrear(lineas), [ProcesoAuditoria.evaluacion]);
      expect(RuteoVentaRepuestoService.comprasEnParalelo(_ticket(lineas)), isFalse);
    });

    test('una línea ya cotizada por Compras no vuelve a requerir gestión', () {
      final cotizada = _sinStock.copyWith(cotizadaPorCompras: true);
      expect(RuteoVentaRepuestoService.requiereGestionCompras(cotizada), isFalse);
      expect(RuteoVentaRepuestoService.motivoGestion(cotizada), isNull);
      expect(RuteoVentaRepuestoService.destino([_conStock, cotizada]), DestinoVentaRepuesto.comercial);
    });
  });

  group('Compras termina primero', () {
    test('marca la línea sin stock, el ticket SIGUE en Evaluación; luego la evaluación con stock → Comercial', () async {
      final repo = _RepoFalso(_ticket([_conStock, _sinStock, _porDeterminar]));

      final rCompras = await RegistrarCotizacionComprasVentaUseCase(repo)(
        ticketId: 'REQ-00090', urlsCotizacion: ['u1'], nombreUsuario: 'COMPRAS', rolUsuario: 'COMPRAS', ahora: t0);
      final tras = rCompras.getOrElse(() => throw 'falló');
      expect(tras.estadoActual, EstadoTicket.recepcionFisica);
      expect(tras.lineasRepuestoVenta[1].cotizadaPorCompras, isTrue);
      expect(tras.lineasRepuestoVenta[1].cotizadaPor, 'COMPRAS');
      expect(tras.urlsCotizacionCompras, ['u1']);
      expect(repo.ultimoCambio!.evento!.proceso, ProcesoAuditoria.compras);
      expect(repo.ultimoCambio!.evento!.hito, HitoProceso.fin);
      expect(repo.ultimoCambio!.evento!.habilita, isEmpty);
      expect(RuteoVentaRepuestoService.comprasEnParalelo(tras), isFalse); // ya no aparece en Compras

      // La pantalla de evaluación se abrió ANTES de que Compras cotizara:
      // manda la línea B1 sin la marca. La transacción debe conservarla.
      final rEval = await FinalizarEvaluacionVentaRepuestoUseCase(repo)(
        ticket: tras,
        lineas: _definidas([_conStock, _sinStock, _porDeterminar], conStock: true),
        nombreUsuario: 'SUP',
        rolUsuario: 'SUPERVISOR',
        ahora: t0,
      );
      final fin = rEval.getOrElse(() => throw 'falló');
      expect(fin.estadoActual, EstadoTicket.comercial);
      expect(fin.lineasRepuestoVenta[1].cotizadaPorCompras, isTrue);
      expect(fin.lineasRepuestoVenta[2].codigo, 'POL-01');
      expect(repo.ultimoCambio!.evento!.habilita, [ProcesoAuditoria.comercial]);
    });

    test('si el repuesto evaluado queda sin stock → Compras lo recibe aparte (solo ese)', () async {
      final repo = _RepoFalso(_ticket([_conStock, _sinStock, _porDeterminar]));
      await RegistrarCotizacionComprasVentaUseCase(repo)(
          ticketId: 'REQ-00090', urlsCotizacion: ['u1'], nombreUsuario: 'COMPRAS', rolUsuario: 'COMPRAS');

      final rEval = await FinalizarEvaluacionVentaRepuestoUseCase(repo)(
        ticket: repo.actual,
        lineas: _definidas(repo.actual.lineasRepuestoVenta, conStock: false),
        nombreUsuario: 'SUP',
        rolUsuario: 'SUPERVISOR',
      );
      final t = rEval.getOrElse(() => throw 'falló');
      expect(t.estadoActual, EstadoTicket.cotizandoRepuesto);
      final pendientes = t.lineasRepuestoVenta.where(RuteoVentaRepuestoService.requiereGestionCompras).toList();
      expect(pendientes.map((l) => l.codigo), ['POL-01']);

      // Segunda cotización de Compras → Comercial.
      final r2 = await RegistrarCotizacionComprasVentaUseCase(repo)(
          ticketId: 'REQ-00090', urlsCotizacion: ['u2'], nombreUsuario: 'COMPRAS', rolUsuario: 'COMPRAS');
      final t2 = r2.getOrElse(() => throw 'falló');
      expect(t2.estadoActual, EstadoTicket.comercial);
      expect(t2.urlsCotizacionCompras, ['u1', 'u2']);
      expect(repo.ultimoCambio!.evento!.accion, 'COMPRAS: GESTIÓN DE REPUESTO SIN STOCK COMPLETADA (VENTA DE REPUESTO)');
    });
  });

  group('Evaluación termina primero', () {
    test('con un repuesto aún sin cotizar → Compras; al cotizar → Comercial', () async {
      final repo = _RepoFalso(_ticket([_conStock, _sinStock, _porDeterminar]));
      final rEval = await FinalizarEvaluacionVentaRepuestoUseCase(repo)(
        ticket: repo.actual,
        lineas: _definidas(repo.actual.lineasRepuestoVenta, conStock: true),
        nombreUsuario: 'SUP',
        rolUsuario: 'SUPERVISOR',
      );
      expect(rEval.getOrElse(() => throw 'falló').estadoActual, EstadoTicket.cotizandoRepuesto);
      expect(repo.ultimoCambio!.evento!.habilita, [ProcesoAuditoria.compras]);

      final r = await RegistrarCotizacionComprasVentaUseCase(repo)(
          ticketId: 'REQ-00090', urlsCotizacion: ['u1'], nombreUsuario: 'COMPRAS', rolUsuario: 'COMPRAS');
      expect(r.getOrElse(() => throw 'falló').estadoActual, EstadoTicket.comercial);
    });

    test('todo con stock → Comercial directo', () async {
      final repo = _RepoFalso(_ticket([_conStock, _porDeterminar]));
      final r = await FinalizarEvaluacionVentaRepuestoUseCase(repo)(
        ticket: repo.actual,
        lineas: _definidas(repo.actual.lineasRepuestoVenta, conStock: true),
        nombreUsuario: 'SUP',
        rolUsuario: 'SUPERVISOR',
      );
      expect(r.getOrElse(() => throw 'falló').estadoActual, EstadoTicket.comercial);
    });
  });

  group('Validaciones', () {
    test('evaluación con líneas por determinar no llama al repositorio', () async {
      final repo = _RepoFalso(_ticket([_conStock, _porDeterminar]));
      final r = await FinalizarEvaluacionVentaRepuestoUseCase(repo)(
        ticket: repo.actual,
        lineas: repo.actual.lineasRepuestoVenta,
        nombreUsuario: 'SUP',
        rolUsuario: 'SUPERVISOR',
      );
      expect(r.fold((f) => f, (_) => null), isA<ValidationFailure>());
      expect(repo.llamadas, 0);
    });

    test('evaluación sobre un ticket que ya salió de Evaluación → rechazada', () async {
      final repo = _RepoFalso(_ticket([_conStock, _porDeterminar], estado: EstadoTicket.anulado));
      final r = await FinalizarEvaluacionVentaRepuestoUseCase(repo)(
        ticket: repo.actual,
        lineas: _definidas(repo.actual.lineasRepuestoVenta, conStock: true),
        nombreUsuario: 'SUP',
        rolUsuario: 'SUPERVISOR',
      );
      expect(r.fold((f) => f, (_) => null), isA<ValidationFailure>());
      expect(repo.actual.estadoActual, EstadoTicket.anulado);
    });

    test('Compras sin repuestos pendientes → rechazada (no cambia nada)', () async {
      final repo = _RepoFalso(_ticket([_conStock, _porDeterminar]));
      final r = await RegistrarCotizacionComprasVentaUseCase(repo)(
          ticketId: 'REQ-00090', urlsCotizacion: ['u1'], nombreUsuario: 'COMPRAS', rolUsuario: 'COMPRAS');
      expect(r.fold((f) => f, (_) => null), isA<ValidationFailure>());
      expect(repo.actual.urlsCotizacionCompras, isEmpty);
    });

    test('error del repositorio se devuelve tal cual', () async {
      final repo = _RepoFalso(_ticket([_conStock, _sinStock], estado: EstadoTicket.cotizandoRepuesto))
        ..falla = const ServerFailure('sin red');
      final r = await RegistrarCotizacionComprasVentaUseCase(repo)(
          ticketId: 'REQ-00090', urlsCotizacion: const [], nombreUsuario: 'COMPRAS', rolUsuario: 'COMPRAS');
      expect(r.fold((f) => f.message, (_) => ''), 'sin red');
    });

    test('ticket antiguo en cotizandoRepuesto (sin marcas) → Comercial', () async {
      final repo = _RepoFalso(_ticket([_conStock, _sinStock], estado: EstadoTicket.cotizandoRepuesto));
      final r = await RegistrarCotizacionComprasVentaUseCase(repo)(
          ticketId: 'REQ-00090', urlsCotizacion: ['u1'], nombreUsuario: 'COMPRAS', rolUsuario: 'COMPRAS');
      expect(r.getOrElse(() => throw 'falló').estadoActual, EstadoTicket.comercial);
    });
  });
}
