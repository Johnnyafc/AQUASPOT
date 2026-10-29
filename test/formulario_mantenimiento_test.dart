// test/formulario_mantenimiento_test.dart
//
// Mantenimiento interno (Crear Ticket): tipo de mantenimiento por rol,
// campos por tipo de máquina, catálogo de series / placas, validaciones,
// ticket que se crea, guardado en Firestore, use case y exclusión de los
// Indicadores de Postventa; videos de evidencia y foto obligatoria del
// horómetro / kilometraje.

import 'package:aquaspot_postventa/core/enum/proceso_auditoria.dart';
import 'package:aquaspot_postventa/core/enum/rol_usuario.dart';
import 'package:aquaspot_postventa/core/enum/ticket_enums.dart';
import 'package:aquaspot_postventa/core/errors/failures.dart';
import 'package:aquaspot_postventa/features/tickets/data/models/ticket_model.dart';
import 'package:aquaspot_postventa/features/tickets/domain/entities/mantenimiento_interno_entity.dart';
import 'package:aquaspot_postventa/features/tickets/domain/entities/ticket_entity.dart';
import 'package:aquaspot_postventa/features/tickets/domain/repositories/ticket_repository.dart';
import 'package:aquaspot_postventa/features/tickets/domain/services/documentos_ticket_service.dart';
import 'package:aquaspot_postventa/features/tickets/domain/services/formulario_mantenimiento_service.dart';
import 'package:aquaspot_postventa/features/tickets/domain/services/indicadores_postventa_service.dart';
import 'package:aquaspot_postventa/features/tickets/domain/usecases/adjuntar_evidencias_mantenimiento_usecase.dart';
import 'package:aquaspot_postventa/features/tickets/domain/usecases/crear_mantenimiento_interno_usecase.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';

typedef F = FormularioMantenimientoService;

final ahora = DateTime(2026, 10, 26, 12);

DatosMantenimientoInterno cosechadoraValida({TipoMantenimiento tipo = TipoMantenimiento.correctivo}) =>
    DatosMantenimientoInterno(
      marca: 'JOHN DEERE',
      especificacion: 'S700',
      tipoMantenimiento: tipo,
      tipoActivo: TipoActivoMantenimiento.cosechadora,
      serieOPlaca: 'AQ2',
      horometro: 1520.5,
      detalle: 'Fuga de aceite en el motor',
      cantidadFotos: 1,
      tieneFotoLectura: true,
    );

class _RepoFalso implements ITicketRepository {
  TicketEntity? creado;
  TicketEntity? actualizado;

  @override
  Future<Either<Failure, TicketEntity>> actualizarTicket(TicketEntity ticket) async {
    actualizado = ticket;
    return Right(ticket);
  }

  @override
  Future<Either<Failure, TicketEntity>> crearTicket(TicketEntity ticket) async {
    creado = ticket.copyWith(id: 'REQ-00100');
    return Right(creado!);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('Tipo de mantenimiento', () {
    test('Cualquier usuario puede crear un preventivo', () {
      final d = cosechadoraValida(tipo: TipoMantenimiento.preventivo);
      expect(F.validar(d, ahora: ahora), isEmpty);
    });
  });

  group('Campos según la máquina y catálogo', () {
    test('Qué pide cada tipo', () {
      expect(F.pideHorometro(TipoActivoMantenimiento.cosechadora), isTrue);
      expect(F.pideFechaHora(TipoActivoMantenimiento.contador), isTrue);
      expect(F.pideFechaHora(TipoActivoMantenimiento.caracol), isTrue);
      expect(F.pideKilometraje(TipoActivoMantenimiento.vehiculo), isTrue);
      expect(F.etiquetaSerieOPlaca(TipoActivoMantenimiento.vehiculo), 'Placa');
      expect(F.pideHorometro(TipoActivoMantenimiento.vehiculo), isFalse);
      expect(F.pideFechaHora(TipoActivoMantenimiento.cosechadora), isFalse);
    });

    test('Aire acondicionado pide la ubicación del equipo; herramientas, la especificación', () {
      expect(F.etiquetaEspecificacion(TipoActivoMantenimiento.aireAcondicionado), 'Ubicación del equipo');
      expect(F.etiquetaEspecificacion(TipoActivoMantenimiento.herramientas), 'Especificación del equipo');
    });

    test('Catálogo de Firestore: el tipo que no viene usa el de por defecto; limpia vacíos y repetidos', () {
      final c = F.combinarCatalogo({
        'cosechadora': ['AQ2', ' AQ3 ', 'AQ3', ''],
        'vehiculo': [],
      });
      expect(F.opcionesDe(TipoActivoMantenimiento.cosechadora, c), ['AQ2', 'AQ3']);
      expect(F.opcionesDe(TipoActivoMantenimiento.vehiculo, c), isEmpty, reason: 'lista vacía en Firestore: sin opciones');
      expect(F.opcionesDe(TipoActivoMantenimiento.contador, c), ['Contador AQUASPOT']);
      expect(F.opcionesDe(TipoActivoMantenimiento.aireAcondicionado, c), isEmpty);
    });

    test('Se valida contra el catálogo leído', () {
      final c = F.combinarCatalogo({'cosechadora': ['AQ9']});
      final d = cosechadoraValida();
      expect(F.validar(d.copyWith(serieOPlaca: 'AQ9'), ahora: ahora, catalogo: c), isEmpty);
      expect(F.validar(d, ahora: ahora, catalogo: c), isNotEmpty, reason: 'AQ2 ya no está en el catálogo leído');
      expect(F.cambiarTipoActivo(const DatosMantenimientoInterno(), TipoActivoMantenimiento.cosechadora, catalogo: c).serieOPlaca, 'AQ9');
    });

    test('Catálogo inicial', () {
      expect(F.opcionesDe(TipoActivoMantenimiento.cosechadora), ['AQ2']);
      expect(F.opcionesDe(TipoActivoMantenimiento.contador), ['Contador AQUASPOT']);
      expect(F.opcionesDe(TipoActivoMantenimiento.caracol), ['AQ2']);
      expect(F.opcionesDe(TipoActivoMantenimiento.vehiculo), ['GTA1234']);
    });

    test('Cambiar de máquina borra lo que no aplica y preselecciona la única opción', () {
      final vehiculo = F.cambiarTipoActivo(cosechadoraValida(), TipoActivoMantenimiento.vehiculo);
      expect(vehiculo.serieOPlaca, 'GTA1234');
      expect(vehiculo.horometro, isNull);
      expect(vehiculo.tieneFotoLectura, isFalse, reason: 'la foto del horómetro no sirve como foto del kilometraje');
      expect(vehiculo.detalle, 'Fuga de aceite en el motor', reason: 'el detalle se conserva');
    });
  });

  group('Validaciones', () {
    test('Formulario vacío: pide el tipo de máquina', () {
      expect(F.validar(const DatosMantenimientoInterno(), ahora: ahora),
          ['Seleccione el tipo de máquina.']);
    });

    test('Marca y especificación: solo aire acondicionado y herramientas, obligatorias y en MAYÚSCULAS', () {
      expect(F.pideMarcaYEspecificacion(TipoActivoMantenimiento.aireAcondicionado), isTrue);
      expect(F.pideMarcaYEspecificacion(TipoActivoMantenimiento.herramientas), isTrue);
      expect(F.pideMarcaYEspecificacion(TipoActivoMantenimiento.cosechadora), isFalse);
      expect(F.pideMarcaYEspecificacion(TipoActivoMantenimiento.vehiculo), isFalse);
      final cosechadora = cosechadoraValida().copyWith(marca: ' ', especificacion: '');
      expect(F.validar(cosechadora, ahora: ahora), isEmpty, reason: 'la cosechadora no las pide');
      final aire = DatosMantenimientoInterno(
        tipoActivo: TipoActivoMantenimiento.aireAcondicionado,
        fechaHora: DateTime(2026, 10, 20),
        detalle: 'No enfría la oficina',
        cantidadFotos: 1,
      );
      expect(F.validar(aire, ahora: ahora),
          containsAll(['Ingrese la marca.', 'Ingrese la ubicación del equipo.']));
      final t = F.construirTicket(aire.copyWith(marca: ' lg ', especificacion: 'split 12000 btu'),
          usuarioNombre: 'Ana', rol: RolUsuario.requerimiento, ahora: ahora);
      expect(t.marca, 'LG');
      expect(t.mantenimientoInterno!.especificacion, 'SPLIT 12000 BTU');
      final tc = F.construirTicket(cosechadoraValida(), usuarioNombre: 'Ana', rol: RolUsuario.requerimiento, ahora: ahora);
      expect(tc.mantenimientoInterno!.especificacion, isEmpty);
      // Al pasar a una máquina que no las pide, se vacían (sus campos se ocultan).
      final escrito = aire.copyWith(marca: 'LG', especificacion: 'SPLIT');
      final cambiado = F.cambiarTipoActivo(escrito, TipoActivoMantenimiento.cosechadora);
      expect(cambiado.marca, isEmpty);
      expect(cambiado.especificacion, isEmpty);
      final herramienta = F.cambiarTipoActivo(escrito, TipoActivoMantenimiento.herramientas);
      expect(herramienta.marca, 'LG', reason: 'entre aire y herramientas la marca sigue a la vista');
      expect(herramienta.especificacion, isEmpty, reason: 'la ubicación del aire no es la especificación de una herramienta');
      final json = TicketModel.fromEntity(t.copyWith(id: 'REQ-3')).toJson()..['id'] = 'REQ-3';
      expect(TicketModel.fromJson(json).mantenimientoInterno!.especificacion, 'SPLIT 12000 BTU');
    });

    test('Cosechadora válida no tiene errores', () {
      expect(F.validar(cosechadoraValida(), ahora: ahora), isEmpty);
    });

    test('Faltantes: horómetro y su foto, detalle corto, sin evidencias, serie fuera del catálogo', () {
      final d = DatosMantenimientoInterno(
        marca: 'JOHN DEERE',
        especificacion: 'S700',
        tipoActivo: TipoActivoMantenimiento.cosechadora,
        serieOPlaca: 'XX9',
        detalle: 'falla',
      );
      final e = F.validar(d, ahora: ahora);
      expect(e.length, 5);
      expect(e.any((x) => x.contains('catálogo')), isTrue);
      expect(e, contains('Ingrese el horómetro.'));
      expect(e, contains('Agregue la foto del horómetro.'));
      expect(e.any((x) => x.contains('10 caracteres')), isTrue);
      expect(e, contains('Agregue al menos una evidencia (foto o video).'));
    });

    test('Fecha de la falla: nunca futura en correctivo; en preventivo sí (programada)', () {
      final futura = DatosMantenimientoInterno(
        marca: 'JOHN DEERE',
        especificacion: 'S700',
        tipoActivo: TipoActivoMantenimiento.caracol,
        serieOPlaca: 'AQ2',
        fechaHora: ahora.add(const Duration(days: 1)),
        detalle: 'Rodamiento con ruido',
        cantidadFotos: 2,
      );
      expect(F.validar(futura, ahora: ahora).single, contains('futura'));
      expect(
          F.validar(futura.copyWith(tipoMantenimiento: TipoMantenimiento.preventivo),
              ahora: ahora),
          isEmpty);
    });

    test('Kilometraje negativo no se acepta', () {
      final d = DatosMantenimientoInterno(
        marca: 'JOHN DEERE',
        especificacion: 'S700',
        tipoActivo: TipoActivoMantenimiento.vehiculo,
        serieOPlaca: 'GTA1234',
        kilometraje: -5,
        detalle: 'Frenos desgastados',
        cantidadFotos: 1,
        tieneFotoLectura: true,
      );
      expect(F.validar(d, ahora: ahora).single, contains('negativo'));
    });

    test('Vehículo: kilometraje y su foto son obligatorios', () {
      const d = DatosMantenimientoInterno(
        marca: 'JOHN DEERE',
        especificacion: 'S700',
        tipoActivo: TipoActivoMantenimiento.vehiculo,
        serieOPlaca: 'GTA1234',
        detalle: 'Frenos desgastados',
        cantidadFotos: 1,
      );
      expect(F.validar(d, ahora: ahora),
          ['Ingrese el kilometraje.', 'Agregue la foto del kilometraje.']);
    });

    test('Contador / caracol no piden foto de lectura', () {
      expect(F.pideFotoLectura(TipoActivoMantenimiento.caracol), isFalse);
      expect(F.pideFotoLectura(TipoActivoMantenimiento.contador), isFalse);
      expect(F.pideFotoLectura(TipoActivoMantenimiento.cosechadora), isTrue);
      expect(F.pideFotoLectura(TipoActivoMantenimiento.vehiculo), isTrue);
    });

    test('Un video sirve como evidencia; más de 3 videos no', () {
      final soloVideo = cosechadoraValida().copyWith(cantidadFotos: 0, cantidadVideos: 1);
      expect(F.validar(soloVideo, ahora: ahora), isEmpty);
      final muchos = cosechadoraValida().copyWith(cantidadVideos: 4);
      expect(F.validar(muchos, ahora: ahora).single, contains('Máximo 3 videos'));
    });
  });

  group('Ticket que se crea', () {
    test('Cosechadora: serie, horómetro, sin cliente ni correo', () {
      final t = F.construirTicket(cosechadoraValida(), usuarioNombre: 'Ana', rol: RolUsuario.requerimiento, ahora: ahora);
      expect(t.tipoRequerimiento, TipoRequerimiento.mantenimientoInterno);
      expect(t.esMantenimientoInterno, isTrue);
      expect(t.estadoActual, EstadoTicket.recepcionFisica, reason: 'entra directo a Evaluación Técnica');
      expect(t.historialEventos.single.habilita, [ProcesoAuditoria.evaluacion]);
      expect(t.equipo, TipoEquipo.Cosechadora);
      expect(t.numeroSerie, 'AQ2');
      expect(t.horometro, 1520.5);
      expect(t.fallaReportada, 'Fuga de aceite en el motor');
      expect(t.clienteId, F.clienteInterno);
      expect(t.emailContacto, isEmpty, reason: 'sin correo: no se envían correos a clientes');
      expect(t.mantenimientoInterno!.tipoMantenimiento, TipoMantenimiento.correctivo);
      expect(t.historialEventos.single.usuarioRol, 'REQUERIMIENTO');
      expect(t.historialEventos.single.accion, contains('CORRECTIVO'));
    });

    test('Vehículo: la placa va en mantenimientoInterno, no en la serie', () {
      final d = DatosMantenimientoInterno(
        marca: 'JOHN DEERE',
        especificacion: 'S700',
        tipoActivo: TipoActivoMantenimiento.vehiculo,
        serieOPlaca: 'GTA1234',
        kilometraje: 45200,
        detalle: 'Cambio de aceite y filtros',
        cantidadFotos: 1,
        tieneFotoLectura: true,
      );
      final t = F.construirTicket(d, usuarioNombre: 'Ana', rol: RolUsuario.supervisor, ahora: ahora);
      expect(t.numeroSerie, isNull);
      expect(t.equipo, TipoEquipo.Otros);
      expect(t.mantenimientoInterno!.placa, 'GTA1234');
      expect(t.mantenimientoInterno!.kilometraje, 45200);
    });
  });

  group('Aire acondicionado y Herramientas', () {
    DatosMantenimientoInterno aire({String? serie, DateTime? fecha, TipoMantenimiento tipo = TipoMantenimiento.correctivo}) =>
        DatosMantenimientoInterno(
          marca: 'JOHN DEERE',
          especificacion: 'S700',
          tipoMantenimiento: tipo,
          tipoActivo: TipoActivoMantenimiento.aireAcondicionado,
          serieOPlaca: serie,
          fechaHora: fecha,
          detalle: 'No enfría la oficina',
          cantidadFotos: 1,
        );

    test('Solo fecha y serie opcional escrita a mano, sin horómetro ni kilometraje', () {
      for (final t in [TipoActivoMantenimiento.aireAcondicionado, TipoActivoMantenimiento.herramientas]) {
        expect(F.serieManual(t), isTrue);
        expect(F.pideFecha(t), isTrue);
        expect(F.pideFechaHora(t), isFalse);
        expect(F.pideHorometro(t), isFalse);
        expect(F.pideKilometraje(t), isFalse);
        expect(F.pideFotoLectura(t), isFalse);
        expect(F.opcionesDe(t), isEmpty);
        expect(F.equipoDe(t), TipoEquipo.Otros);
      }
      expect(F.serieManual(TipoActivoMantenimiento.cosechadora), isFalse);
      expect(F.pideFecha(TipoActivoMantenimiento.contador), isFalse);
      expect(TipoActivoMantenimiento.aireAcondicionado.etiqueta, 'Aire acondicionado');
      expect(TipoActivoMantenimiento.herramientas.etiqueta, 'Herramientas');
    });

    test('Válido sin serie; la fecha es obligatoria y no puede ser futura en correctivo', () {
      expect(F.validar(aire(fecha: DateTime(2026, 10, 26)), ahora: ahora), isEmpty);
      expect(F.validar(aire(), ahora: ahora), contains('Seleccione la fecha.'));
      expect(F.validar(aire(fecha: DateTime(2026, 10, 27)), ahora: ahora),
          contains('La fecha de la falla no puede ser futura.'));
      expect(
          F.validar(aire(fecha: DateTime(2026, 12, 1), tipo: TipoMantenimiento.preventivo),
              ahora: ahora),
          isEmpty);
    });

    test('El ticket guarda la serie en MAYÚSCULAS (o sin serie) y solo la fecha', () {
      final con = F.construirTicket(aire(serie: ' lg-12k ', fecha: DateTime(2026, 10, 20, 15, 40)),
          usuarioNombre: 'Ana', rol: RolUsuario.requerimiento, ahora: ahora);
      expect(con.numeroSerie, 'LG-12K');
      expect(con.equipo, TipoEquipo.Otros);
      expect(con.equipoDetalle, 'Aire acondicionado');
      expect(con.mantenimientoInterno!.fechaHoraFalla, DateTime(2026, 10, 20));
      expect(con.historialEventos.first.accion, contains('AIRE ACONDICIONADO LG-12K'));

      final sin = F.construirTicket(aire(fecha: DateTime(2026, 10, 20)),
          usuarioNombre: 'Ana', rol: RolUsuario.requerimiento, ahora: ahora);
      expect(sin.numeroSerie, isNull);
      expect(sin.historialEventos.first.accion, contains('AIRE ACONDICIONADO S/N'));
    });

    test('Fecha sin hora en el texto y en la etiqueta', () {
      final f = DateTime(2026, 10, 20, 15, 40);
      expect(F.textoFecha(TipoActivoMantenimiento.herramientas, f), '20/10/2026');
      expect(F.textoFecha(TipoActivoMantenimiento.contador, f), '20/10/2026 15:40');
      expect(F.etiquetaFechaDe(TipoActivoMantenimiento.herramientas, TipoMantenimiento.correctivo), 'Fecha de la falla');
      expect(F.etiquetaFechaDe(TipoActivoMantenimiento.caracol, TipoMantenimiento.preventivo), 'Fecha y hora programada');
    });

    test('Al pasar de "fecha y hora" a "solo fecha" se borra la fecha; entre iguales se conserva', () {
      final contador = DatosMantenimientoInterno(
        marca: 'JOHN DEERE',
        especificacion: 'S700',
        tipoActivo: TipoActivoMantenimiento.contador,
        serieOPlaca: 'Contador AQUASPOT',
        fechaHora: DateTime(2026, 10, 20, 9, 30),
      );
      expect(F.cambiarTipoActivo(contador, TipoActivoMantenimiento.aireAcondicionado).fechaHora, isNull);
      expect(F.cambiarTipoActivo(contador, TipoActivoMantenimiento.aireAcondicionado).serieOPlaca, isNull);
      expect(F.cambiarTipoActivo(contador, TipoActivoMantenimiento.caracol).fechaHora, DateTime(2026, 10, 20, 9, 30));
      final aireConFecha = aire(fecha: DateTime(2026, 10, 20));
      expect(F.cambiarTipoActivo(aireConFecha, TipoActivoMantenimiento.herramientas).fechaHora, DateTime(2026, 10, 20));
    });

    test('Se guarda y se lee igual en Firestore', () {
      final t = F.construirTicket(aire(serie: 'X1', fecha: DateTime(2026, 10, 20)),
          usuarioNombre: 'Ana', rol: RolUsuario.requerimiento, ahora: ahora);
      final json = TicketModel.fromEntity(t.copyWith(id: 'REQ-2')).toJson()..['id'] = 'REQ-2';
      final leido = TicketModel.fromJson(json);
      expect(leido.mantenimientoInterno, t.mantenimientoInterno);
      expect(leido.mantenimientoInterno!.tipoActivo, TipoActivoMantenimiento.aireAcondicionado);
    });
  });

  test('Se guarda y se lee igual en Firestore', () {
    final d = DatosMantenimientoInterno(
      marca: 'JOHN DEERE',
      especificacion: 'S700',
      tipoMantenimiento: TipoMantenimiento.preventivo,
      tipoActivo: TipoActivoMantenimiento.contador,
      serieOPlaca: 'Contador AQUASPOT',
      fechaHora: DateTime(2026, 11, 3, 9, 30),
      detalle: 'Calibración trimestral',
      cantidadFotos: 1,
    );
    final t = F.construirTicket(d, usuarioNombre: 'Sup', rol: RolUsuario.supervisor, ahora: ahora);
    final json = TicketModel.fromEntity(t.copyWith(id: 'REQ-1')).toJson()..['id'] = 'REQ-1';
    final leido = TicketModel.fromJson(json);
    expect(leido.tipoRequerimiento, TipoRequerimiento.mantenimientoInterno);
    expect(leido.mantenimientoInterno, t.mantenimientoInterno);
    expect(leido.numeroSerie, 'Contador AQUASPOT');
  });

  group('Use case', () {
    test('Rechaza una serie que no está en el catálogo leído, sin escribir nada', () async {
      final repo = _RepoFalso();
      final r = await CrearMantenimientoInternoUseCase(repo)(
        cosechadoraValida(tipo: TipoMantenimiento.preventivo),
        usuarioNombre: 'Ana',
        rol: RolUsuario.comercial,
        ahora: ahora,
        catalogo: F.combinarCatalogo({'cosechadora': ['AQ9']}),
      );
      expect(r.isLeft(), isTrue);
      expect(r.fold((f) => f, (_) => null), isA<ValidationFailure>());
      expect(repo.creado, isNull);
    });

    test('Crea el ticket con datos válidos', () async {
      final repo = _RepoFalso();
      final r = await CrearMantenimientoInternoUseCase(repo)(
        cosechadoraValida(),
        usuarioNombre: 'Ana',
        rol: RolUsuario.requerimiento,
        ahora: ahora,
      );
      expect(r.fold((_) => null, (t) => t.id), 'REQ-00100');
      expect(repo.creado!.esMantenimientoInterno, isTrue);
    });

    test('Adjunta fotos, videos y la foto del horómetro, y se guardan en Firestore', () async {
      final repo = _RepoFalso();
      final ticket = F.construirTicket(cosechadoraValida(), usuarioNombre: 'Ana', rol: RolUsuario.requerimiento, ahora: ahora)
          .copyWith(id: 'REQ-2');
      await AdjuntarEvidenciasMantenimientoUseCase(repo)(
        ticket,
        ['https://f/foto1.jpg'],
        videosUrls: ['https://f/video1.mp4'],
        urlFotoLectura: 'https://f/horometro.jpg',
      );
      final t = repo.actualizado!;
      expect(t.fotosUrls, ['https://f/foto1.jpg']);
      expect(t.mantenimientoInterno!.videosUrls, ['https://f/video1.mp4']);
      expect(t.mantenimientoInterno!.urlFotoLectura, 'https://f/horometro.jpg');

      final json = TicketModel.fromEntity(t).toJson()..['id'] = 'REQ-2';
      expect(TicketModel.fromJson(json).mantenimientoInterno, t.mantenimientoInterno);

      // Biblioteca / Dashboard: la foto del horómetro y los videos en su carpeta.
      final carpetas = {for (final c in DocumentosTicketService.carpetas(t)) c.id: c};
      expect(carpetas['mantenimientoFotoLectura']!.urls, ['https://f/horometro.jpg']);
      expect(carpetas['mantenimientoVideos']!.urls, ['https://f/video1.mp4']);
    });
  });

  test('No entra en los Indicadores de Postventa', () {
    final t = F.construirTicket(cosechadoraValida(), usuarioNombre: 'Ana', rol: RolUsuario.requerimiento, ahora: ahora)
        .copyWith(id: 'REQ-1');
    final datos = IndicadoresPostventaService.calcular(
      tickets: [t],
      desde: DateTime(2026, 10, 1),
      hasta: DateTime(2026, 10, 31),
    );
    expect(datos.creados, isEmpty);
    expect(IndicadoresPostventaService.etiquetaTipo(t), 'Mantenimiento interno');
  });
}
