// test/comercial_edita_repuestos_venta_test.dart
//
// Venta de Repuesto: Comercial agrega (desde el sistema), quita o cambia la
// cantidad de repuestos. EdicionVentaComercialService (diferencias, línea
// nueva) y GuardarRepuestosVentaComercialUseCase con un repositorio falso que
// simula la transacción: solo en Comercial, sin auditoría ni cambio de etapa,
// cambios en el registro "Cambios de materiales" (lista venta).

import 'package:aquaspot_postventa/core/enum/ticket_enums.dart';
import 'package:aquaspot_postventa/core/errors/failures.dart';
import 'package:aquaspot_postventa/features/tickets/domain/entities/cambio_material_entity.dart';
import 'package:aquaspot_postventa/features/tickets/domain/entities/cambio_venta_repuesto.dart';
import 'package:aquaspot_postventa/features/tickets/domain/entities/linea_repuesto_venta_entity.dart';
import 'package:aquaspot_postventa/features/tickets/domain/entities/ticket_entity.dart';
import 'package:aquaspot_postventa/features/tickets/domain/repositories/ticket_repository.dart';
import 'package:aquaspot_postventa/features/tickets/domain/services/edicion_venta_comercial_service.dart';
import 'package:aquaspot_postventa/features/tickets/domain/usecases/guardar_repuestos_venta_comercial_usecase.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';

class _RepoFalso implements ITicketRepository {
  TicketEntity actual;
  int llamadas = 0;
  CambioVentaRepuesto? ultimoCambio;

  _RepoFalso(this.actual);

  @override
  Future<Either<Failure, TicketEntity>> actualizarVentaRepuestoEnTransaccion({
    required String ticketId,
    required CambioVentaRepuesto Function(TicketEntity actual) aplicar,
  }) async {
    llamadas++;
    try {
      final c = aplicar(actual);
      ultimoCambio = c;
      actual = actual.copyWith(
        lineasRepuestoVenta: c.lineas,
        estadoActual: c.estadoNuevo ?? actual.estadoActual,
        historialEventos: [...actual.historialEventos, if (c.evento != null) c.evento!],
        historialCambiosMateriales: [...actual.historialCambiosMateriales, ...c.cambiosMateriales],
      );
      return Right(actual);
    } on CambioVentaRechazado catch (e) {
      return Left(ValidationFailure(e.mensaje));
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _a = LineaRepuestoVentaEntity(codigo: 'A1', descripcion: 'FILTRO', unidad: 'UND', cantidad: 2, stockDisponibleAlEvaluar: 5);
const _b = LineaRepuestoVentaEntity(codigo: 'B1', descripcion: 'BOMBA', unidad: 'UND', cantidad: 1, stockDisponibleAlEvaluar: 0);

TicketEntity _ticket({EstadoTicket estado = EstadoTicket.comercial}) => TicketEntity(
      id: 'REQ-00095',
      estadoActual: estado,
      sede: Sede.NINGUNO,
      clienteId: 'Cliente',
      campamento: '',
      nombreContacto: 'Contacto',
      telefonoContacto: '',
      emailContacto: '',
      equipo: TipoEquipo.Caracol,
      equipoDetalle: null,
      accesoriosRecibidos: null,
      numeroSerie: null,
      fallaReportada: '',
      historialEventos: const [],
      tipoRequerimiento: TipoRequerimiento.ventaRepuesto,
      lugarAtencion: LugarAtencion.noAplica,
      esRegistroCompleto: true,
      lineasRepuestoVenta: const [_a, _b],
    );

void main() {
  final t0 = DateTime(2026, 10, 14, 11);

  group('EdicionVentaComercialService', () {
    test('línea nueva desde el sistema: está en el sistema y lleva su stock', () {
      final l = EdicionVentaComercialService.nuevaLineaDesdeInventario(
          codigo: 'C1', descripcion: 'SELLO', unidad: 'UND', cantidad: 3, stockNeto: 1);
      expect(l.existeEnSistema, isTrue);
      expect(l.porDeterminar, isFalse);
      expect(l.stockDisponibleAlEvaluar, 1);
      expect(l.tieneStockSuficiente, isFalse); // solo informativo para Comercial
    });

    test('diferencias: agregó, quitó y cambió cantidad (lista venta)', () {
      final c1 = EdicionVentaComercialService.nuevaLineaDesdeInventario(
          codigo: 'C1', descripcion: 'SELLO', unidad: 'UND', cantidad: 3, stockNeto: 1);
      final cambios = EdicionVentaComercialService.diferencias(
        antes: const [_a, _b],
        despues: [_a.copyWith(cantidad: 1), c1],
        momento: CambioMaterialEntity.primeraCotizacion,
        usuarioNombre: 'COM',
        usuarioRol: 'COMERCIAL',
        fecha: t0,
      );
      final porCodigo = {for (final c in cambios) c.codigo: c};
      expect(porCodigo['A1']!.accion, CambioMaterialEntity.cambioCantidad);
      expect(porCodigo['A1']!.cantidadAntes, 2);
      expect(porCodigo['A1']!.cantidadDespues, 1);
      expect(porCodigo['B1']!.accion, CambioMaterialEntity.quito);
      expect(porCodigo['C1']!.accion, CambioMaterialEntity.agrego);
      expect(cambios.every((c) => c.lista == CambioMaterialEntity.listaVenta), isTrue);
      expect(cambios.first.listaTexto, 'Repuestos de la venta');
    });
  });

  group('GuardarRepuestosVentaComercialUseCase', () {
    test('guarda la lista, NO cambia de etapa y NO registra auditoría', () async {
      final repo = _RepoFalso(_ticket());
      final r = await GuardarRepuestosVentaComercialUseCase(repo)(
        ticketId: 'REQ-00095',
        lineas: [_a.copyWith(cantidad: 1)], // quitó B1 y bajó A1
        nombreUsuario: 'COM',
        rolUsuario: 'COMERCIAL',
        ahora: t0,
      );
      final t = r.getOrElse(() => throw 'falló');
      expect(t.estadoActual, EstadoTicket.comercial);
      expect(t.lineasRepuestoVenta.map((l) => l.codigo), ['A1']);
      expect(t.historialEventos, isEmpty);
      expect(repo.ultimoCambio!.evento, isNull);
      expect(t.historialCambiosMateriales.length, 2);
      expect(t.historialCambiosMateriales.every((c) => c.usuarioNombre == 'COM'), isTrue);
    });

    test('agregar un repuesto sin stock también se queda en Comercial', () async {
      final repo = _RepoFalso(_ticket());
      final sinStock = EdicionVentaComercialService.nuevaLineaDesdeInventario(
          codigo: 'C1', descripcion: 'SELLO', unidad: 'UND', cantidad: 4, stockNeto: 0);
      final r = await GuardarRepuestosVentaComercialUseCase(repo)(
        ticketId: 'REQ-00095', lineas: const [_a, _b] + [sinStock], nombreUsuario: 'COM', rolUsuario: 'COMERCIAL');
      expect(r.getOrElse(() => throw 'falló').estadoActual, EstadoTicket.comercial);
      expect(repo.actual.historialCambiosMateriales.single.accion, CambioMaterialEntity.agrego);
    });

    test('si el ticket ya no está en Comercial → rechazado, sin cambios', () async {
      final repo = _RepoFalso(_ticket(estado: EstadoTicket.cotizado));
      final r = await GuardarRepuestosVentaComercialUseCase(repo)(
        ticketId: 'REQ-00095', lineas: const [_a], nombreUsuario: 'COM', rolUsuario: 'COMERCIAL');
      expect(r.fold((f) => f, (_) => null), isA<ValidationFailure>());
      expect(repo.actual.lineasRepuestoVenta.length, 2);
    });

    test('lista vacía o cantidad 0 → no llama al repositorio', () async {
      final repo = _RepoFalso(_ticket());
      final uc = GuardarRepuestosVentaComercialUseCase(repo);
      final vacia = await uc(ticketId: 'REQ-00095', lineas: const [], nombreUsuario: 'COM', rolUsuario: 'COMERCIAL');
      final cero = await uc(
          ticketId: 'REQ-00095', lineas: [_a.copyWith(cantidad: 0)], nombreUsuario: 'COM', rolUsuario: 'COMERCIAL');
      expect(vacia.isLeft(), isTrue);
      expect(cero.isLeft(), isTrue);
      expect(repo.llamadas, 0);
    });

    test('ticket sin proforma previa: momento = primera cotización', () {
      final cambio = GuardarRepuestosVentaComercialUseCase.aplicarSobre(
          _ticket(), const [_a], 'COM', 'COMERCIAL', t0);
      expect(cambio.cambiosMateriales.single.momento, CambioMaterialEntity.primeraCotizacion);
    });
  });
}
