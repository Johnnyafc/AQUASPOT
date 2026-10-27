// test/evaluacion_mantenimiento_test.dart
//
// Evaluación técnica de MANTENIMIENTO INTERNO: actividades del Plan Maestro
// con una sola lista de repuestos, agregar / quitar / cambiar repuestos del
// inventario, consolidado para bodega, validación, ticket evaluado (pasa a
// Compras sin Comercial ni Costos) y use case (reserva de stock en Caracol).

import 'package:aquaspot_postventa/core/enum/proceso_auditoria.dart';
import 'package:aquaspot_postventa/core/enum/rol_usuario.dart';
import 'package:aquaspot_postventa/core/enum/ticket_enums.dart';
import 'package:aquaspot_postventa/core/errors/failures.dart';
import 'package:aquaspot_postventa/features/catalogo/domain/entities/actividad_catalogo_entity.dart';
import 'package:aquaspot_postventa/features/catalogo/domain/entities/item_catalogo_entity.dart';
import 'package:aquaspot_postventa/features/inventario/domain/entities/item_inventario_entity.dart';
import 'package:aquaspot_postventa/features/tickets/domain/entities/actividad_mantenimiento.dart';
import 'package:aquaspot_postventa/features/tickets/domain/entities/mantenimiento_interno_entity.dart';
import 'package:aquaspot_postventa/features/tickets/domain/entities/repuesto_registrado_entity.dart';
import 'package:aquaspot_postventa/features/tickets/domain/entities/ticket_entity.dart';
import 'package:aquaspot_postventa/features/tickets/domain/repositories/ticket_repository.dart';
import 'package:aquaspot_postventa/features/tickets/domain/services/evaluacion_mantenimiento_service.dart';
import 'package:aquaspot_postventa/features/tickets/domain/services/formulario_mantenimiento_service.dart';
import 'package:aquaspot_postventa/features/tickets/domain/usecases/guardar_evaluacion_mantenimiento_usecase.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';

typedef S = EvaluacionMantenimientoService;

final ahora = DateTime(2026, 10, 27, 10);

TicketEntity ticketDe(TipoActivoMantenimiento tipo) {
  final d = FormularioMantenimientoService.cambiarTipoActivo(
    const DatosMantenimientoInterno(detalle: 'Ruido en el motor', cantidadFotos: 1, tieneFotoLectura: true),
    tipo,
  ).copyWith(horometro: 100, kilometraje: 100, fechaHora: ahora);
  return FormularioMantenimientoService.construirTicket(d, usuarioNombre: 'Op', rol: RolUsuario.requerimiento, ahora: ahora)
      .copyWith(id: 'REQ-00200');
}

const actividadPlan = ActividadCatalogoEntity(
  id: 'x',
  codigo: 'MO010',
  nombre: 'Cambio de rodamientos',
  equipo: 'caracol',
  horasHombre: 3,
  esVariable: false,
  itemsInternos: [
    ItemCatalogoEntity(codigo: 'R-1', descripcion: 'RODAMIENTO 6205', cantidad: 2),
    ItemCatalogoEntity(codigo: '', descripcion: 'Grasa', unidad: 'GRAMOS', cantidad: 50),
  ],
  itemsComerciales: [
    ItemCatalogoEntity(codigo: 'r-1 ', descripcion: 'RODAMIENTO 6205', cantidad: 2), // repetido
    ItemCatalogoEntity(codigo: 'SELLO-9', descripcion: 'SELLO MECÁNICO', cantidad: 1),
    ItemCatalogoEntity(codigo: 'Z-0', descripcion: 'NO VA', cantidad: 0),
  ],
);

ItemInventarioEntity inv(String codigo, String descripcion) =>
    ItemInventarioEntity(codigo: codigo, descripcion: descripcion, stockDisponible: 10, fechaActualizacion: ahora);

ActividadMantenimiento lista() => S.desdeCatalogo(actividadPlan).copyWith(observacion: 'Rodamientos con juego');

class _RepoFalso implements ITicketRepository {
  TicketEntity? actualizado;
  List<Map<String, dynamic>>? reservados;

  @override
  Future<Either<Failure, TicketEntity>> actualizarTicket(TicketEntity ticket) async {
    actualizado = ticket;
    return Right(ticket);
  }

  @override
  Future<Either<Failure, void>> guardarEvaluacionTecnicaConReservaStock({
    required TicketEntity ticket,
    required List<Map<String, dynamic>> itemsAReservar,
  }) async {
    actualizado = ticket;
    reservados = itemsAReservar;
    return const Right(null);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('Equipo del Plan Maestro según la máquina (vehículo sin plan)', () {
    expect(S.equipoCatalogo(ticketDe(TipoActivoMantenimiento.cosechadora)), 'cosechadora');
    expect(S.equipoCatalogo(ticketDe(TipoActivoMantenimiento.contador)), 'contador');
    expect(S.equipoCatalogo(ticketDe(TipoActivoMantenimiento.caracol)), 'caracol');
    expect(S.equipoCatalogo(ticketDe(TipoActivoMantenimiento.vehiculo)), isNull);
  });

  test('El mantenimiento entra directo a Evaluación Técnica', () {
    expect(ticketDe(TipoActivoMantenimiento.caracol).estadoActual, EstadoTicket.recepcionFisica);
  });

  group('Actividad del Plan Maestro', () {
    test('Junta internos y comerciales en una sola lista, sin repetir ni cantidades 0', () {
      final a = S.desdeCatalogo(actividadPlan);
      expect(a.codigo, 'MO010');
      expect(a.horasHombre, 3);
      expect(a.repuestos.map((r) => r.descripcion), ['RODAMIENTO 6205', 'Grasa', 'SELLO MECÁNICO']);
    });

    test('Disponibles: no ofrece las ya agregadas; búsqueda por código o nombre', () {
      expect(S.disponibles([actividadPlan], [lista()]), isEmpty);
      expect(S.buscarActividades([actividadPlan], 'rodam mo010'), [actividadPlan]);
      expect(S.buscarActividades([actividadPlan], 'aceite'), isEmpty);
    });
  });

  group('Repuestos', () {
    test('Agregar del inventario: nuevo con cantidad 1; si ya está, suma 1', () {
      var a = S.agregarRepuesto(lista(), inv('F-7', 'FILTRO DE ACEITE'));
      expect(a.repuestos.last.cantidad, 1);
      a = S.agregarRepuesto(a, inv('R-1', 'RODAMIENTO 6205'));
      expect(a.repuestos.first.cantidad, 3);
      expect(a.repuestos.length, 4);
    });

    test('Cambiar cantidad y quitar', () {
      var a = S.cambiarCantidad(lista(), 0, 4);
      expect(a.repuestos.first.cantidad, 4);
      a = S.quitarRepuesto(a, 0);
      expect(a.repuestos.map((r) => r.codigo), ['', 'SELLO-9']);
    });

    test('Buscar en inventario: todas las palabras, máximo 30', () {
      final inventario = [inv('F-7', 'FILTRO DE ACEITE'), inv('F-8', 'FILTRO DE AIRE'), inv('R-1', 'RODAMIENTO')];
      expect(S.buscarInventario(inventario, 'filtro aceite').map((i) => i.codigo), ['F-7']);
      expect(S.buscarInventario(inventario, '  '), isEmpty);
      expect(S.buscarInventario([for (var i = 0; i < 50; i++) inv('X$i', 'TORNILLO')], 'tornillo').length, 30);
    });

    test('Consolidado: suma los iguales de todas las actividades', () {
      final otra = const ActividadMantenimiento(codigo: 'MO020', nombre: 'Otra', repuestos: [
        RepuestoRegistradoEntity(codigo: 'R-1', descripcion: 'RODAMIENTO 6205', cantidad: 1),
      ]);
      final c = S.consolidar([lista(), otra]);
      expect(c.firstWhere((r) => r.codigo == 'R-1').cantidad, 3);
      expect(c.length, 3);
    });

    test('"Incluye" con todos los repuestos de la actividad', () {
      expect(S.textoIncluye(lista()), 'Incluye: 2 RODAMIENTO 6205, 50 GRAMOS DE Grasa, 1 SELLO MECÁNICO.');
      expect(S.textoIncluye(const ActividadMantenimiento(codigo: 'A', nombre: 'B')), '');
    });
  });

  test('Validación: actividades, horas, observación y cantidades', () {
    expect(S.validar(const []), ['Agregue al menos una actividad.']);
    expect(S.validar([lista()]), isEmpty);
    final mal = S.cambiarCantidad(S.desdeCatalogo(actividadPlan).copyWith(horasHombre: 0), 0, 0);
    expect(S.validar([mal]).length, 3);
  });

  test('Ticket evaluado: todos los repuestos a bodega, pasa a Compras sin Costos', () {
    final t = S.construirTicketEvaluado(
      ticketDe(TipoActivoMantenimiento.caracol),
      [lista().copyWith(fotosUrls: ['https://f/1.jpg'])],
      necesitaCompras: false,
      motivoNoCompras: 'Hay stock',
      usuarioNombre: 'Téc',
      rol: RolUsuario.tecnico,
      ahora: ahora,
    );
    expect(t.estadoActual, EstadoTicket.compras);
    expect(t.isCostosCompletado, isTrue);
    expect(t.evaluacionTecnica!.repuestosTaller.length, 3);
    expect(t.evaluacionTecnica!.repuestosComercial, isEmpty);
    expect(t.itemsDespachoBodega.map((i) => i.cantidadSolicitada), [2, 50, 1]);
    expect(t.evaluacionTecnica!.actividades.single.fotosUrls, ['https://f/1.jpg']);
    expect(t.evaluacionTecnica!.actividades.single.incluye, startsWith('Incluye: 2 RODAMIENTO'));
    expect(t.evaluacionTecnica!.totalHorasHombre, 3);
    expect(t.noRequiereCompras, isTrue);
    expect(t.motivoNoRequiereCompras, 'Hay stock');
    final ev = t.historialEventos.last;
    expect(ev.accion, contains('NO REQUIERE COMPRAS (Hay stock)'));
    expect(ev.proceso, ProcesoAuditoria.evaluacion);
    expect(ev.habilita, [ProcesoAuditoria.compras]);
  });

  group('Use case', () {
    test('No escribe si la evaluación no es válida', () async {
      final repo = _RepoFalso();
      final r = await GuardarEvaluacionMantenimientoUseCase(repo)(
        ticketDe(TipoActivoMantenimiento.cosechadora),
        const [],
        necesitaCompras: true,
        usuarioNombre: 'Téc',
        rol: RolUsuario.tecnico,
      );
      expect(r.fold((f) => f, (_) => null), isA<ValidationFailure>());
      expect(repo.actualizado, isNull);
    });

    test('Caracol: aparta el stock de todos los repuestos', () async {
      final repo = _RepoFalso();
      final r = await GuardarEvaluacionMantenimientoUseCase(repo)(
        ticketDe(TipoActivoMantenimiento.caracol),
        [lista()],
        necesitaCompras: true,
        usuarioNombre: 'Téc',
        rol: RolUsuario.tecnico,
        ahora: ahora,
      );
      expect(r.isRight(), isTrue);
      expect(repo.reservados!.map((m) => m['codigo']), ['R-1', '', 'SELLO-9']);
    });

    test('Cosechadora: guarda sin reserva', () async {
      final repo = _RepoFalso();
      await GuardarEvaluacionMantenimientoUseCase(repo)(
        ticketDe(TipoActivoMantenimiento.cosechadora),
        [lista()],
        necesitaCompras: true,
        usuarioNombre: 'Téc',
        rol: RolUsuario.tecnico,
        ahora: ahora,
      );
      expect(repo.reservados, isNull);
      expect(repo.actualizado!.estadoActual, EstadoTicket.compras);
    });
  });
}
