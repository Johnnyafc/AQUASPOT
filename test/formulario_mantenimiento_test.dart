// test/formulario_mantenimiento_test.dart
//
// Mantenimiento interno (Crear Ticket): tipo de mantenimiento por rol,
// campos por tipo de máquina, catálogo de series / placas, validaciones,
// ticket que se crea, guardado en Firestore, use case y exclusión de los
// Indicadores de Postventa.

import 'package:aquaspot_postventa/core/enum/rol_usuario.dart';
import 'package:aquaspot_postventa/core/enum/ticket_enums.dart';
import 'package:aquaspot_postventa/core/errors/failures.dart';
import 'package:aquaspot_postventa/features/tickets/data/models/ticket_model.dart';
import 'package:aquaspot_postventa/features/tickets/domain/entities/mantenimiento_interno_entity.dart';
import 'package:aquaspot_postventa/features/tickets/domain/entities/ticket_entity.dart';
import 'package:aquaspot_postventa/features/tickets/domain/repositories/ticket_repository.dart';
import 'package:aquaspot_postventa/features/tickets/domain/services/formulario_mantenimiento_service.dart';
import 'package:aquaspot_postventa/features/tickets/domain/services/indicadores_postventa_service.dart';
import 'package:aquaspot_postventa/features/tickets/domain/usecases/crear_mantenimiento_interno_usecase.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';

typedef F = FormularioMantenimientoService;

final ahora = DateTime(2026, 10, 26, 12);

DatosMantenimientoInterno cosechadoraValida({TipoMantenimiento tipo = TipoMantenimiento.correctivo}) =>
    DatosMantenimientoInterno(
      tipoMantenimiento: tipo,
      tipoActivo: TipoActivoMantenimiento.cosechadora,
      serieOPlaca: 'AQ2',
      horometro: 1520.5,
      detalle: 'Fuga de aceite en el motor',
      cantidadFotos: 1,
    );

class _RepoFalso implements ITicketRepository {
  TicketEntity? creado;

  @override
  Future<Either<Failure, TicketEntity>> crearTicket(TicketEntity ticket) async {
    creado = ticket.copyWith(id: 'REQ-00100');
    return Right(creado!);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('Tipo de mantenimiento por rol', () {
    test('Supervisor y admin eligen; el resto, solo Correctivo', () {
      expect(F.tiposPermitidos(RolUsuario.supervisor), TipoMantenimiento.values);
      expect(F.tiposPermitidos(RolUsuario.admin), TipoMantenimiento.values);
      for (final rol in [RolUsuario.requerimiento, RolUsuario.comercial, RolUsuario.tecnico, RolUsuario.bodega]) {
        expect(F.tiposPermitidos(rol), [TipoMantenimiento.correctivo], reason: rol.name);
      }
    });

    test('Un operador no puede crear un preventivo (se valida al crear)', () {
      final d = cosechadoraValida(tipo: TipoMantenimiento.preventivo);
      expect(F.validar(d, rol: RolUsuario.requerimiento, ahora: ahora), isNotEmpty);
      expect(F.validar(d, rol: RolUsuario.supervisor, ahora: ahora), isEmpty);
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
      expect(vehiculo.detalle, 'Fuga de aceite en el motor', reason: 'el detalle se conserva');
    });
  });

  group('Validaciones', () {
    test('Formulario vacío: pide el tipo de máquina', () {
      expect(F.validar(const DatosMantenimientoInterno(), rol: RolUsuario.requerimiento, ahora: ahora),
          ['Seleccione el tipo de máquina.']);
    });

    test('Cosechadora válida no tiene errores', () {
      expect(F.validar(cosechadoraValida(), rol: RolUsuario.requerimiento, ahora: ahora), isEmpty);
    });

    test('Faltantes: horómetro, detalle corto, sin fotos, serie fuera del catálogo', () {
      final d = DatosMantenimientoInterno(
        tipoActivo: TipoActivoMantenimiento.cosechadora,
        serieOPlaca: 'XX9',
        detalle: 'falla',
      );
      final e = F.validar(d, rol: RolUsuario.requerimiento, ahora: ahora);
      expect(e.length, 4);
      expect(e.any((x) => x.contains('catálogo')), isTrue);
      expect(e.any((x) => x.contains('horómetro')), isTrue);
      expect(e.any((x) => x.contains('10 caracteres')), isTrue);
      expect(e.any((x) => x.contains('foto')), isTrue);
    });

    test('Fecha de la falla: nunca futura en correctivo; en preventivo sí (programada)', () {
      final futura = DatosMantenimientoInterno(
        tipoActivo: TipoActivoMantenimiento.caracol,
        serieOPlaca: 'AQ2',
        fechaHora: ahora.add(const Duration(days: 1)),
        detalle: 'Rodamiento con ruido',
        cantidadFotos: 2,
      );
      expect(F.validar(futura, rol: RolUsuario.supervisor, ahora: ahora).single, contains('futura'));
      expect(
          F.validar(futura.copyWith(tipoMantenimiento: TipoMantenimiento.preventivo),
              rol: RolUsuario.supervisor, ahora: ahora),
          isEmpty);
    });

    test('Kilometraje negativo no se acepta', () {
      final d = DatosMantenimientoInterno(
        tipoActivo: TipoActivoMantenimiento.vehiculo,
        serieOPlaca: 'GTA1234',
        kilometraje: -5,
        detalle: 'Frenos desgastados',
        cantidadFotos: 1,
      );
      expect(F.validar(d, rol: RolUsuario.requerimiento, ahora: ahora).single, contains('negativo'));
    });
  });

  group('Ticket que se crea', () {
    test('Cosechadora: serie, horómetro, sin cliente ni correo', () {
      final t = F.construirTicket(cosechadoraValida(), usuarioNombre: 'Ana', rol: RolUsuario.requerimiento, ahora: ahora);
      expect(t.tipoRequerimiento, TipoRequerimiento.mantenimientoInterno);
      expect(t.esMantenimientoInterno, isTrue);
      expect(t.estadoActual, EstadoTicket.creado);
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
        tipoActivo: TipoActivoMantenimiento.vehiculo,
        serieOPlaca: 'GTA1234',
        kilometraje: 45200,
        detalle: 'Cambio de aceite y filtros',
        cantidadFotos: 1,
      );
      final t = F.construirTicket(d, usuarioNombre: 'Ana', rol: RolUsuario.supervisor, ahora: ahora);
      expect(t.numeroSerie, isNull);
      expect(t.equipo, TipoEquipo.Otros);
      expect(t.mantenimientoInterno!.placa, 'GTA1234');
      expect(t.mantenimientoInterno!.kilometraje, 45200);
    });
  });

  test('Se guarda y se lee igual en Firestore', () {
    final d = DatosMantenimientoInterno(
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
    test('Rechaza un preventivo creado por un operador, sin escribir nada', () async {
      final repo = _RepoFalso();
      final r = await CrearMantenimientoInternoUseCase(repo)(
        cosechadoraValida(tipo: TipoMantenimiento.preventivo),
        usuarioNombre: 'Ana',
        rol: RolUsuario.comercial,
        ahora: ahora,
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
