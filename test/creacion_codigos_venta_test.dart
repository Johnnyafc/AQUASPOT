// test/creacion_codigos_venta_test.dart
//
// Venta de Repuesto con repuestos que NO están en el sistema:
// ficha de creación (obligatorios), Proformas enviadas → ✔ Cliente aceptó →
// Costos crea códigos → Proformas enviadas (OV habilitada), con un
// repositorio falso que simula la transacción e inventario.

import 'package:aquaspot_postventa/core/enum/proceso_auditoria.dart';
import 'package:aquaspot_postventa/core/enum/ticket_enums.dart';
import 'package:aquaspot_postventa/core/errors/failures.dart';
import 'package:aquaspot_postventa/features/tickets/data/models/linea_repuesto_venta_model.dart';
import 'package:aquaspot_postventa/features/tickets/domain/entities/cambio_venta_repuesto.dart';
import 'package:aquaspot_postventa/features/tickets/domain/entities/ficha_creacion_repuesto_entity.dart';
import 'package:aquaspot_postventa/features/tickets/domain/entities/linea_repuesto_venta_entity.dart';
import 'package:aquaspot_postventa/features/tickets/domain/entities/ticket_entity.dart';
import 'package:aquaspot_postventa/features/tickets/domain/repositories/ticket_repository.dart';
import 'package:aquaspot_postventa/features/tickets/domain/services/creacion_codigos_venta_service.dart';
import 'package:aquaspot_postventa/features/tickets/domain/usecases/confirmar_aceptacion_cliente_venta_usecase.dart';
import 'package:aquaspot_postventa/features/tickets/domain/usecases/registrar_codigos_creados_usecase.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';

class _RepoFalso implements ITicketRepository {
  TicketEntity actual;
  final Set<String> inventario; // códigos que ya existen
  final List<RepuestoInventarioNuevo> inventarioCreado = [];
  int llamadas = 0;
  CambioVentaRepuesto? ultimoCambio;

  _RepoFalso(this.actual, {Set<String>? inventario}) : inventario = inventario ?? {};

  @override
  Future<Either<Failure, TicketEntity>> actualizarVentaRepuestoEnTransaccion({
    required String ticketId,
    required CambioVentaRepuesto Function(TicketEntity actual) aplicar,
  }) async {
    llamadas++;
    try {
      final c = aplicar(actual);
      ultimoCambio = c;
      for (final r in c.inventarioNuevos) {
        if (inventario.add(r.codigo)) inventarioCreado.add(r); // solo si no existía
      }
      actual = actual.copyWith(
        lineasRepuestoVenta: c.lineas,
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

const _ficha = FichaCreacionRepuestoEntity(
  nombre: "VALVULA DE PASO RAPIDO INOX 1/2''",
  familiaPieza: 'VALVULA',
  tipo: 'DE PASO RAPIDO',
  atributoAcabado: 'INOX',
  metrica: "1/2''",
  categoria: 'HIDRAULICO',
);

const _delSistema = LineaRepuestoVentaEntity(
    codigo: 'A1', descripcion: 'FILTRO', unidad: 'UND', cantidad: 1, stockDisponibleAlEvaluar: 5);
final _nueva = const LineaRepuestoVentaEntity(
  codigo: '',
  descripcion: "VALVULA DE PASO RAPIDO INOX 1/2''",
  unidad: 'UNIDAD',
  cantidad: 2,
  stockDisponibleAlEvaluar: 0,
  existeEnSistema: false,
  cotizadaPorCompras: true,
  fichaCreacion: _ficha,
  urlsCotizacionProveedor: ['https://x/cot.pdf'],
);

TicketEntity _ticket(List<LineaRepuestoVentaEntity> lineas, {EstadoTicket estado = EstadoTicket.cotizado}) => TicketEntity(
      id: 'REQ-00100',
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

void main() {
  final t0 = DateTime(2026, 10, 20, 10);

  group('Ficha de creación', () {
    test('obligatorios: nombre, familia, categoría y UDM', () {
      expect(_ficha.completa, isTrue);
      expect(const FichaCreacionRepuestoEntity().faltantes, ['Nombre', 'Familia de pieza', 'Categoría']);
      expect(_ficha.copyWith(udm: '').faltantes, ['UDM']);
    });

    test('valores por defecto de la plantilla', () {
      const f = FichaCreacionRepuestoEntity();
      expect([f.udm, f.tipoProducto], ['UNIDAD', 'ARTÍCULO']);
      expect([f.comprado, f.vendido, f.activo, f.almacenado, f.gravaIva, f.fabricado],
          [true, true, false, true, true, false]);
    });

    test('se guarda y se lee con la línea; líneas antiguas sin ficha', () {
      final vuelta = LineaRepuestoVentaModel.fromJson(LineaRepuestoVentaModel.fromEntity(_nueva).toJson());
      expect(vuelta.fichaCreacion, _ficha);
      final vieja = LineaRepuestoVentaModel.fromJson({'codigo': 'A1', 'descripcion': 'X', 'unidad': 'UND', 'cantidad': 1});
      expect(vieja.fichaCreacion, isNull);
      expect(vieja.codigoCreadoPorCostos, isFalse);
    });
  });

  group('Reglas', () {
    test('venta con repuesto nuevo requiere Costos; la OV se bloquea hasta tener códigos', () {
      final t = _ticket([_delSistema, _nueva]);
      expect(CreacionCodigosVentaService.requiereCreacionCodigos(t), isTrue);
      expect(CreacionCodigosVentaService.puedeRegistrarOV(t), isFalse);
      expect(CreacionCodigosVentaService.indicesPendientes(t), [1]);
    });

    test('venta solo con repuestos del sistema y reparación: OV normal, sin Costos', () {
      expect(CreacionCodigosVentaService.requiereCreacionCodigos(_ticket([_delSistema])), isFalse);
      expect(CreacionCodigosVentaService.puedeRegistrarOV(_ticket([_delSistema])), isTrue);
      final reparacion = _ticket([_nueva]).copyWith(tipoRequerimiento: TipoRequerimiento.reparacion);
      expect(CreacionCodigosVentaService.requiereCreacionCodigos(reparacion), isFalse);
    });
  });

  group('Flujo completo', () {
    test('Cliente aceptó → Costos crea código → Proformas enviadas con OV habilitada', () async {
      final repo = _RepoFalso(_ticket([_delSistema, _nueva]));

      final r1 = await ConfirmarAceptacionClienteVentaUseCase(repo)(
          ticketId: 'REQ-00100', nombreUsuario: 'COM', rolUsuario: 'COMERCIAL', ahora: t0);
      expect(r1.getOrElse(() => throw 'falló').estadoActual, EstadoTicket.costos);
      expect(repo.ultimoCambio!.evento!.proceso, ProcesoAuditoria.aprobacionCliente);
      expect(repo.ultimoCambio!.evento!.habilita, [ProcesoAuditoria.costos]);

      final r2 = await RegistrarCodigosCreadosUseCase(repo)(
        ticketId: 'REQ-00100',
        codigos: const [CodigoCreado(indiceLinea: 1, codigo: 'VAL-0123', descripcion: "VALVULA PASO RAPIDO INOX 1/2''")],
        nombreUsuario: 'COSTOS',
        rolUsuario: 'COSTOS',
        ahora: t0,
      );
      final t = r2.getOrElse(() => throw 'falló');
      expect(t.estadoActual, EstadoTicket.cotizado);
      final l = t.lineasRepuestoVenta[1];
      expect(l.codigo, 'VAL-0123');
      expect(l.descripcion, "VALVULA PASO RAPIDO INOX 1/2''");
      expect(l.existeEnSistema, isTrue);
      expect(l.codigoCreadoPorCostos, isTrue);
      expect(l.codigoCreadoPor, 'COSTOS');
      expect(l.cotizadaPorCompras, isTrue); // se conservan las marcas
      expect(l.fichaCreacion, _ficha);
      expect(t.lineasRepuestoVenta[0], _delSistema); // las demás no cambian
      expect(CreacionCodigosVentaService.tieneCodigosCreados(t), isTrue);
      expect(CreacionCodigosVentaService.puedeRegistrarOV(t), isTrue);
      expect(repo.inventarioCreado.single.codigo, 'VAL-0123');
      expect(repo.ultimoCambio!.evento!.proceso, ProcesoAuditoria.costos);
      expect(repo.ultimoCambio!.evento!.hito, HitoProceso.fin);
    });

    test('si el código ya existía en el inventario, no se vuelve a crear', () async {
      final repo = _RepoFalso(_ticket([_nueva], estado: EstadoTicket.costos), inventario: {'VAL-0123'});
      await RegistrarCodigosCreadosUseCase(repo)(
        ticketId: 'REQ-00100',
        codigos: const [CodigoCreado(indiceLinea: 0, codigo: 'VAL-0123', descripcion: 'VALVULA')],
        nombreUsuario: 'COSTOS',
        rolUsuario: 'COSTOS',
      );
      expect(repo.inventarioCreado, isEmpty);
    });
  });

  group('Validaciones', () {
    test('aceptación fuera de Proformas enviadas o sin repuestos nuevos → rechazada', () async {
      final enComercial = _RepoFalso(_ticket([_nueva], estado: EstadoTicket.comercial));
      final sinNuevos = _RepoFalso(_ticket([_delSistema]));
      final uc1 = ConfirmarAceptacionClienteVentaUseCase(enComercial);
      final uc2 = ConfirmarAceptacionClienteVentaUseCase(sinNuevos);
      expect((await uc1(ticketId: 'x', nombreUsuario: 'C', rolUsuario: 'C')).isLeft(), isTrue);
      expect((await uc2(ticketId: 'x', nombreUsuario: 'C', rolUsuario: 'C')).isLeft(), isTrue);
      expect(enComercial.actual.estadoActual, EstadoTicket.comercial);
    });

    test('códigos vacíos o repetidos no llaman al repositorio', () async {
      final repo = _RepoFalso(_ticket([_nueva, _nueva], estado: EstadoTicket.costos));
      final uc = RegistrarCodigosCreadosUseCase(repo);
      final vacio = await uc(
          ticketId: 'x',
          codigos: const [CodigoCreado(indiceLinea: 0, codigo: ' ', descripcion: 'X')],
          nombreUsuario: 'C',
          rolUsuario: 'C');
      final repetido = await uc(
          ticketId: 'x',
          codigos: const [
            CodigoCreado(indiceLinea: 0, codigo: 'V1', descripcion: 'X'),
            CodigoCreado(indiceLinea: 1, codigo: 'v1', descripcion: 'Y'),
          ],
          nombreUsuario: 'C',
          rolUsuario: 'C');
      expect(vacio.isLeft() && repetido.isLeft(), isTrue);
      expect(repo.llamadas, 0);
    });

    test('faltan códigos de algún repuesto pendiente → rechazado, sin cambios', () async {
      final repo = _RepoFalso(_ticket([_nueva, _nueva], estado: EstadoTicket.costos));
      final r = await RegistrarCodigosCreadosUseCase(repo)(
        ticketId: 'x',
        codigos: const [CodigoCreado(indiceLinea: 0, codigo: 'V1', descripcion: 'X')],
        nombreUsuario: 'C',
        rolUsuario: 'C',
      );
      expect(r.fold((f) => f, (_) => null), isA<ValidationFailure>());
      expect(repo.actual.estadoActual, EstadoTicket.costos);
      expect(repo.inventarioCreado, isEmpty);
    });

    test('Costos sobre un ticket que ya no está en Costos → rechazado', () async {
      final repo = _RepoFalso(_ticket([_nueva]));
      final r = await RegistrarCodigosCreadosUseCase(repo)(
        ticketId: 'x',
        codigos: const [CodigoCreado(indiceLinea: 0, codigo: 'V1', descripcion: 'X')],
        nombreUsuario: 'C',
        rolUsuario: 'C',
      );
      expect(r.isLeft(), isTrue);
    });
  });
}
