// test/entrega_venta_test.dart
//
// Venta de Repuesto: Despacho → Entrega → Finalizado.
// - "Pasar a entrega" sin exigir evidencia (solo en ventas).
// - Finaliza solo con guía + factura (Entregas) + guía firmada de Bodega,
//   en cualquier orden (CerrarEntregaVentaUseCase, repositorio falso).
// - Reparación: sin cambios (picking exige evidencia; guía + factura).

import 'package:aquaspot_postventa/core/enum/proceso_auditoria.dart';
import 'package:aquaspot_postventa/core/enum/ticket_enums.dart';
import 'package:aquaspot_postventa/core/errors/failures.dart';
import 'package:aquaspot_postventa/features/tickets/domain/entities/cambio_venta_repuesto.dart';
import 'package:aquaspot_postventa/features/tickets/domain/entities/item_despacho_bodega_entity.dart';
import 'package:aquaspot_postventa/features/tickets/domain/entities/registro_despacho_entity.dart';
import 'package:aquaspot_postventa/features/tickets/domain/entities/ticket_entity.dart';
import 'package:aquaspot_postventa/features/tickets/domain/repositories/ticket_repository.dart';
import 'package:aquaspot_postventa/features/tickets/domain/services/estado_despacho_service.dart';
import 'package:aquaspot_postventa/features/tickets/domain/services/flujo_venta_repuesto_service.dart';
import 'package:aquaspot_postventa/features/tickets/domain/usecases/cerrar_entrega_venta_usecase.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';

class _RepoFalso implements ITicketRepository {
  TicketEntity actual;
  int escrituras = 0;
  CambioVentaRepuesto? ultimoCambio;

  _RepoFalso(this.actual);

  @override
  Future<Either<Failure, TicketEntity>> actualizarVentaRepuestoEnTransaccion({
    required String ticketId,
    required CambioVentaRepuesto Function(TicketEntity actual) aplicar,
  }) async {
    try {
      final c = aplicar(actual);
      ultimoCambio = c;
      final hayCambio = c.evento != null || c.estadoNuevo != null || c.urlGuiaRemision != null || c.urlFactura != null;
      if (hayCambio) escrituras++;
      actual = actual.copyWith(
        urlGuiaRemision: c.urlGuiaRemision,
        urlFactura: c.urlFactura,
        estadoActual: c.estadoNuevo ?? actual.estadoActual,
        historialEventos: [...actual.historialEventos, if (c.evento != null) c.evento!],
      );
      return Right(actual);
    } on CambioVentaRechazado catch (e) {
      return Left(ValidationFailure(e.mensaje));
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

RegistroDespachoEntity _despacho({bool conEvidencia = false}) => RegistroDespachoEntity(
      id: 'REQ-00120-PICK-01',
      fecha: DateTime(2026, 10, 21, 9),
      usuarioNombre: 'BODEGA',
      usuarioId: 'u1',
      items: const [],
      fotosEvidenciasUrls: conEvidencia ? const ['https://x/guia_firmada.jpg'] : const [],
    );

const _itemDespachado = ItemDespachoBodegaEntity(
  codigo: 'A1',
  descripcion: 'FILTRO',
  unidad: 'UND',
  cantidadSolicitada: 2,
  stockDisponibleAlEvaluar: 5,
  validadoPorCompras: true,
  cantidadDespachada: 2,
);

TicketEntity _ticket({
  TipoRequerimiento tipo = TipoRequerimiento.ventaRepuesto,
  EstadoTicket estado = EstadoTicket.entrega,
  bool conEvidencia = false,
  String? guia,
  String? factura,
}) =>
    TicketEntity(
      id: 'REQ-00120',
      estadoActual: estado,
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
      tipoRequerimiento: tipo,
      lugarAtencion: LugarAtencion.noAplica,
      esRegistroCompleto: true,
      itemsDespachoBodega: const [_itemDespachado],
      historialDespachos: [_despacho(conEvidencia: conEvidencia)],
      estadoDespacho: EstadoDespachoService.despachoParcial,
      urlGuiaRemision: guia,
      urlFactura: factura,
    );

void main() {
  group('Pasar a entrega (finalizar picking)', () {
    test('venta: todo despachado sin evidencia → se puede pasar a entrega', () {
      final t = _ticket(estado: EstadoTicket.bodega);
      expect(EstadoDespachoService.puedeFinalizarPicking(t), isTrue);
      expect(EstadoDespachoService.motivoNoFinaliza(t), isNull);
    });

    test('reparación: sigue exigiendo la evidencia (sin cambios)', () {
      final t = _ticket(tipo: TipoRequerimiento.reparacion, estado: EstadoTicket.bodega);
      expect(EstadoDespachoService.puedeFinalizarPicking(t), isFalse);
      expect(EstadoDespachoService.motivoNoFinaliza(t), 'Hay despachos sin evidencia.');
    });
  });

  group('Reglas de Entrega', () {
    test('venta en Entrega sin guía firmada: sigue en Despacho y le falta para finalizar', () {
      final t = _ticket(guia: 'g', factura: 'f');
      expect(FlujoVentaRepuestoService.esperaGuiaFirmada(t), isTrue);
      expect(FlujoVentaRepuestoService.faltantesParaFinalizar(t), ['Guía firmada de Bodega']);
      expect(FlujoVentaRepuestoService.puedeFinalizarEntrega(t), isFalse);
    });

    test('venta con las tres piezas → puede finalizar', () {
      final t = _ticket(guia: 'g', factura: 'f', conEvidencia: true);
      expect(FlujoVentaRepuestoService.esperaGuiaFirmada(t), isFalse);
      expect(FlujoVentaRepuestoService.puedeFinalizarEntrega(t), isTrue);
    });

    test('reparación: guía + factura bastan (sin cambios)', () {
      final t = _ticket(tipo: TipoRequerimiento.reparacion, guia: 'g', factura: 'f');
      expect(FlujoVentaRepuestoService.faltantesParaFinalizar(t), isEmpty);
    });
  });

  group('CerrarEntregaVentaUseCase (cualquier orden)', () {
    test('guía → factura → guía firmada: finaliza recién con la guía firmada', () async {
      final repo = _RepoFalso(_ticket());
      final uc = CerrarEntregaVentaUseCase(repo);

      final r1 = await uc(ticketId: 'REQ-00120', urlGuiaRemision: 'g', nombreUsuario: 'COM', rolUsuario: 'COMERCIAL');
      expect(r1.getOrElse(() => throw 'x').estadoActual, EstadoTicket.entrega);
      final r2 = await uc(ticketId: 'REQ-00120', urlFactura: 'f', nombreUsuario: 'COM', rolUsuario: 'COMERCIAL');
      expect(r2.getOrElse(() => throw 'x').estadoActual, EstadoTicket.entrega); // falta la guía firmada
      expect(repo.ultimoCambio!.evento!.hito, HitoProceso.avance);

      // Bodega sube la guía firmada (el handler la guarda) y luego se intenta cerrar.
      repo.actual = repo.actual.copyWith(historialDespachos: [_despacho(conEvidencia: true)]);
      final r3 = await uc(ticketId: 'REQ-00120', nombreUsuario: 'BODEGA', rolUsuario: 'BODEGA');
      final t = r3.getOrElse(() => throw 'x');
      expect(t.estadoActual, EstadoTicket.finalizado);
      expect(repo.ultimoCambio!.evento!.proceso, ProcesoAuditoria.entrega);
      expect(repo.ultimoCambio!.evento!.hito, HitoProceso.fin);
    });

    test('guía firmada primero → la factura (último documento) finaliza', () async {
      final repo = _RepoFalso(_ticket(conEvidencia: true, guia: 'g'));
      final r = await CerrarEntregaVentaUseCase(repo)(
          ticketId: 'REQ-00120', urlFactura: 'f', nombreUsuario: 'COM', rolUsuario: 'COMERCIAL');
      expect(r.getOrElse(() => throw 'x').estadoActual, EstadoTicket.finalizado);
    });

    test('guía firmada sin guía/factura aún: no escribe nada', () async {
      final repo = _RepoFalso(_ticket(conEvidencia: true));
      await CerrarEntregaVentaUseCase(repo)(ticketId: 'REQ-00120', nombreUsuario: 'BODEGA', rolUsuario: 'BODEGA');
      expect(repo.escrituras, 0);
      expect(repo.actual.estadoActual, EstadoTicket.entrega);
    });

    test('documentos subidos antes de Entrega se guardan pero no finalizan', () async {
      final repo = _RepoFalso(_ticket(estado: EstadoTicket.bodega, conEvidencia: true, guia: 'g'));
      final r = await CerrarEntregaVentaUseCase(repo)(
          ticketId: 'REQ-00120', urlFactura: 'f', nombreUsuario: 'COM', rolUsuario: 'COMERCIAL');
      final t = r.getOrElse(() => throw 'x');
      expect(t.urlFactura, 'f');
      expect(t.estadoActual, EstadoTicket.bodega);
    });

    test('no aplica a reparaciones ni a tickets finalizados', () async {
      final rep = _RepoFalso(_ticket(tipo: TipoRequerimiento.reparacion));
      final fin = _RepoFalso(_ticket(estado: EstadoTicket.finalizado));
      final r1 = await CerrarEntregaVentaUseCase(rep)(ticketId: 'x', urlFactura: 'f', nombreUsuario: 'C', rolUsuario: 'C');
      final r2 = await CerrarEntregaVentaUseCase(fin)(ticketId: 'x', urlFactura: 'f', nombreUsuario: 'C', rolUsuario: 'C');
      expect(r1.isLeft() && r2.isLeft(), isTrue);
    });
  });
}
