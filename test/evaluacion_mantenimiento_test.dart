// test/evaluacion_mantenimiento_test.dart
//
// Evaluación técnica de MANTENIMIENTO INTERNO: actividades del Plan Maestro
// con una sola lista de repuestos, agregar / quitar / cambiar repuestos del
// inventario, consolidado para bodega, validación, ticket evaluado (pasa a
// Compras sin Comercial ni Costos) y use case (reserva de stock en Caracol);
// actividades nuevas, repuestos no registrados ("SIN CÓDIGO"), datos del
// informe técnico y generación del PDF y la Solicitud de materiales. Los
// repuestos sin código (con su ficha) esperan en Costos.

import 'package:aquaspot_postventa/core/enum/proceso_auditoria.dart';
import 'package:aquaspot_postventa/core/enum/rol_usuario.dart';
import 'package:aquaspot_postventa/core/enum/ticket_enums.dart';
import 'package:aquaspot_postventa/core/errors/failures.dart';
import 'package:aquaspot_postventa/features/catalogo/domain/entities/actividad_catalogo_entity.dart';
import 'package:aquaspot_postventa/features/catalogo/domain/entities/item_catalogo_entity.dart';
import 'package:aquaspot_postventa/features/inventario/domain/entities/item_inventario_entity.dart';
import 'package:aquaspot_postventa/features/tickets/domain/entities/actividad_mantenimiento.dart';
import 'package:aquaspot_postventa/features/tickets/domain/entities/ficha_creacion_repuesto_entity.dart';
import 'package:aquaspot_postventa/features/tickets/domain/entities/mantenimiento_interno_entity.dart';
import 'package:aquaspot_postventa/features/tickets/domain/entities/repuesto_registrado_entity.dart';
import 'package:aquaspot_postventa/features/tickets/domain/entities/ticket_entity.dart';
import 'package:aquaspot_postventa/features/tickets/domain/repositories/ticket_repository.dart';
import 'package:aquaspot_postventa/features/tickets/domain/services/creacion_codigos_mantenimiento_service.dart';
import 'package:aquaspot_postventa/features/tickets/domain/services/evaluacion_mantenimiento_service.dart';
import 'package:aquaspot_postventa/features/tickets/domain/services/formulario_mantenimiento_service.dart';
import 'package:aquaspot_postventa/features/tickets/domain/usecases/guardar_evaluacion_mantenimiento_usecase.dart';
import 'package:aquaspot_postventa/features/tickets/domain/entities/archivo_adjunto.dart';
import 'package:aquaspot_postventa/features/tickets/presentation/services/generador_excel_mantenimiento.dart';
import 'package:aquaspot_postventa/features/tickets/presentation/services/generador_pdf_mantenimiento.dart';
import 'dart:io';
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

/// Ficha de la "Grasa" del plan (no tiene código).
final fichas = {
  CreacionCodigosMantenimientoService.claveFicha('Grasa'): const FichaCreacionRepuestoEntity(
    nombre: 'GRASA DE LITIO',
    familiaPieza: 'LUBRICANTE',
    categoria: 'INSUMOS',
    udm: 'GRAMOS',
  ),
};

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

  /// Stock neto que "lee" la transacción (código → cantidad).
  Map<String, double> stock = const {};

  @override
  Future<Either<Failure, TicketEntity>> guardarEvaluacionConReservaYDestino({
    required TicketEntity ticket,
    required List<Map<String, dynamic>> itemsAReservar,
    required TicketEntity Function(Map<String, double> stockNeto) ajustarConStock,
  }) async {
    reservados = itemsAReservar;
    actualizado = ajustarConStock(stock);
    return Right(actualizado!);
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
    expect(S.validar([lista()]), ['Grasa: llene la ficha de creación de código (repuesto sin código).']);
    expect(S.validar([lista()], fichas: fichas), isEmpty);
    final incompleta = {CreacionCodigosMantenimientoService.claveFicha('Grasa'): const FichaCreacionRepuestoEntity(nombre: 'GRASA')};
    expect(S.validar([lista()], fichas: incompleta).single, contains('falta Familia de pieza, Categoría'));
    final mal = S.cambiarCantidad(S.desdeCatalogo(actividadPlan).copyWith(horasHombre: 0), 0, 0);
    expect(S.validar([mal], fichas: fichas).length, 3);
  });

  test('Ticket evaluado: repuestos con código a bodega y Compras; los sin código esperan en Costos', () {
    final t = S.construirTicketEvaluado(
      ticketDe(TipoActivoMantenimiento.caracol),
      [lista().copyWith(fotosUrls: ['https://f/1.jpg'])],
      fichas: fichas,
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
    expect(t.itemsDespachoBodega.map((i) => i.codigo), ['R-1', 'SELLO-9']);
    expect(t.itemsDespachoBodega.map((i) => i.cantidadSolicitada), [2, 1]);
    final porCodificar = t.mantenimientoInterno!.repuestosPorCodificar.single;
    expect(porCodificar.descripcion, 'Grasa');
    expect(porCodificar.cantidad, 50);
    expect(porCodificar.ficha.nombre, 'GRASA DE LITIO');
    expect(porCodificar.pendiente, isTrue);
    expect(t.evaluacionTecnica!.actividades.single.fotosUrls, ['https://f/1.jpg']);
    expect(t.evaluacionTecnica!.actividades.single.incluye, startsWith('Incluye: 2 RODAMIENTO'));
    expect(t.evaluacionTecnica!.totalHorasHombre, 3);
    expect(t.noRequiereCompras, isTrue);
    expect(t.motivoNoRequiereCompras, 'Hay stock');
    final ev = t.historialEventos.last;
    expect(ev.accion, contains('NO REQUIERE COMPRAS (Hay stock)'));
    expect(ev.proceso, ProcesoAuditoria.evaluacion);
    expect(ev.accion, contains('1 REPUESTO(S) SIN CÓDIGO A COSTOS'));
    expect(ev.habilita, [ProcesoAuditoria.compras, ProcesoAuditoria.costos]);
  });

  group('Actividad nueva', () {
    test('Código NUEVA-01, NUEVA-02… sin repetir y misma estructura', () {
      var acts = <ActividadMantenimiento>[lista()];
      final a1 = S.actividadNueva(acts, nombre: '  Cambio de banda ', horasHombre: 2);
      expect(a1.codigo, 'NUEVA-01');
      expect(a1.nombre, 'Cambio de banda');
      expect(S.esActividadNueva(a1), isTrue);
      expect(S.esActividadNueva(lista()), isFalse);
      acts = [...acts, a1];
      expect(S.codigoActividadNueva(acts), 'NUEVA-02');
      // Admite repuestos igual que las del plan.
      final conRepuesto = S.agregarRepuesto(a1, inv('F-7', 'FILTRO DE ACEITE'));
      expect(conRepuesto.repuestos.single.codigo, 'F-7');
    });

    test('Nombre obligatorio (mínimo 3 caracteres)', () {
      expect(S.validarActividadNueva('ab'), isNotNull);
      expect(S.validarActividadNueva('Cambio de banda'), isNull);
    });
  });

  group('Repuesto no registrado', () {
    test('Sin código, en MAYÚSCULAS; si se repite suma la cantidad', () {
      var a = S.agregarRepuestoNoRegistrado(lista(), descripcion: 'banda en v a-42', unidad: 'UNIDAD', cantidad: 2);
      final r = a.repuestos.last;
      expect(r.codigo, '');
      expect(r.descripcion, 'BANDA EN V A-42');
      expect(S.esSinCodigo(r), isTrue);
      a = S.agregarRepuestoNoRegistrado(a, descripcion: 'BANDA EN V A-42 ', unidad: 'UNIDAD', cantidad: 1);
      expect(a.repuestos.last.cantidad, 3);
      expect(S.consolidar([a]).where(S.esSinCodigo).map((r) => r.descripcion), ['Grasa', 'BANDA EN V A-42']);
    });

    test('Validación: descripción y cantidad > 0', () {
      expect(S.validarRepuestoNoRegistrado('ab', 1), isNotNull);
      expect(S.validarRepuestoNoRegistrado('Banda', 0), isNotNull);
      expect(S.validarRepuestoNoRegistrado('Banda', null), isNotNull);
      expect(S.validarRepuestoNoRegistrado('Banda', 1.5), isNull);
    });
  });

  group('Informe técnico y solicitud de materiales', () {
    test('Datos del informe: mantenimiento, máquina, serie, fecha y solicitante (sin cliente)', () {
      final datos = {for (final (k, v) in S.datosInforme(ticketDe(TipoActivoMantenimiento.caracol), fecha: ahora)) k: v};
      expect(datos['FECHA:'], '27 de octubre de 2026');
      expect(datos['INGRESO:'], 'REQ-00200');
      expect(datos['ACTIVIDAD:'], 'MANTENIMIENTO INTERNO CORRECTIVO');
      expect(datos['MÁQUINA:'], 'CARACOL');
      expect(datos['N° SERIE:'], 'AQ2');
      expect(datos['FECHA FALLA:'], '27/10/2026 10:00');
      expect(datos['SOLICITADO POR:'], 'Op');
      expect(datos.containsKey('CLIENTE:'), isFalse);
      final vehiculo = {for (final (k, v) in S.datosInforme(ticketDe(TipoActivoMantenimiento.vehiculo), fecha: ahora)) k: v};
      expect(vehiculo['PLACA:'], 'GTA1234');
      expect(vehiculo['KILOMETRAJE:'], '100 km');
    });

    test('Firma "Ing." sin duplicar y encabezado de la solicitud', () {
      expect(S.firma('Tyrone Villavicencio'), 'Ing. Tyrone Villavicencio');
      expect(S.firma('ING. Tyrone'), 'Ing. Tyrone');
      expect(S.firma(''), 'Ing. Técnico de Servicio');
      expect(S.encabezadoSolicitud.centroCosto, 'MANTENIMIENTO INTERNO');
    });

    test('El ticket evaluado guarda el PDF y el Excel subidos', () {
      final t = S.construirTicketEvaluado(ticketDe(TipoActivoMantenimiento.caracol), [lista()],
          necesitaCompras: true, usuarioNombre: 'Téc', rol: RolUsuario.tecnico, ahora: ahora,
          urlInformePdf: 'https://f/informe.pdf', urlSolicitudExcel: 'https://f/solicitud.xlsx');
      expect(t.evaluacionTecnica!.urlsAdjuntosPdf, ['https://f/informe.pdf']);
      expect(t.evaluacionTecnica!.urlProformaExcel, 'https://f/solicitud.xlsx');
    });

    test('Genera el Excel y el PDF (con actividad nueva, foto y repuesto sin código)', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final foto = ArchivoAdjunto(bytes: File('assets/images/logo.png').readAsBytesSync(), nombre: 'foto.png');
      final nueva = S.agregarRepuestoNoRegistrado(
        S.actividadNueva([lista()], nombre: 'Cambio de banda', horasHombre: 1)
            .copyWith(observacion: 'Banda rota', fotos: [foto]),
        descripcion: 'Banda A-42', unidad: 'UNIDAD', cantidad: 1,
      );
      final acts = [lista(), nueva];
      final excel = GeneradorExcelMantenimiento.generar(ticket: ticketDe(TipoActivoMantenimiento.caracol), actividades: acts);
      expect(excel.sublist(0, 2), [0x50, 0x4B], reason: 'xlsx = zip');
      final pdf = await GeneradorPdfMantenimiento.generar(
        ticket: ticketDe(TipoActivoMantenimiento.caracol),
        actividades: acts,
        nombreTecnico: 'Tyrone',
      );
      expect(String.fromCharCodes(pdf.sublist(0, 4)), '%PDF');
    });
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

    test('Caracol: aparta el stock de los repuestos con código', () async {
      final repo = _RepoFalso();
      final r = await GuardarEvaluacionMantenimientoUseCase(repo)(
        ticketDe(TipoActivoMantenimiento.caracol),
        [lista()],
        fichas: fichas,
        necesitaCompras: true,
        usuarioNombre: 'Téc',
        rol: RolUsuario.tecnico,
        ahora: ahora,
      );
      expect(r.isRight(), isTrue);
      expect(repo.reservados!.map((m) => m['codigo']), ['R-1', 'SELLO-9'], reason: 'lo sin código no se aparta');
    });

    test('Cosechadora: también aparta el stock (flujo de reportes automáticos)', () async {
      final repo = _RepoFalso();
      await GuardarEvaluacionMantenimientoUseCase(repo)(
        ticketDe(TipoActivoMantenimiento.cosechadora),
        [lista()],
        fichas: fichas,
        necesitaCompras: true,
        usuarioNombre: 'Téc',
        rol: RolUsuario.tecnico,
        ahora: ahora,
      );
      expect(repo.reservados!.map((m) => m['codigo']), ['R-1', 'SELLO-9']);
      expect(repo.actualizado!.estadoActual, EstadoTicket.compras);
      expect(repo.actualizado!.usaFlujoReportesAutomaticos, isTrue);
    });
  });
}
