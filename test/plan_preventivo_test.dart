// test/plan_preventivo_test.dart
//
// Plan Preventivo: frecuencia por máquina (horas / km / días), código
// PREV-NN correlativo por máquina, búsqueda, repuestos solo del inventario,
// validación, quién puede administrarlo, guardado en Firestore, use cases y
// uso en la evaluación de mantenimiento (botón "Plan preventivo").

import 'package:aquaspot_postventa/core/enum/rol_usuario.dart';
import 'package:aquaspot_postventa/core/errors/failures.dart';
import 'package:aquaspot_postventa/features/inventario/domain/entities/item_inventario_entity.dart';
import 'package:aquaspot_postventa/features/plan_preventivo/data/models/actividad_preventiva_model.dart';
import 'package:aquaspot_postventa/features/plan_preventivo/domain/entities/actividad_preventiva_entity.dart';
import 'package:aquaspot_postventa/features/plan_preventivo/domain/repositories/plan_preventivo_repository.dart';
import 'package:aquaspot_postventa/features/plan_preventivo/domain/services/plan_preventivo_service.dart';
import 'package:aquaspot_postventa/features/plan_preventivo/domain/usecases/plan_preventivo_usecases.dart';
import 'package:aquaspot_postventa/features/tickets/domain/entities/actividad_mantenimiento.dart';
import 'package:aquaspot_postventa/features/tickets/domain/entities/mantenimiento_interno_entity.dart';
import 'package:aquaspot_postventa/features/tickets/domain/entities/repuesto_registrado_entity.dart';
import 'package:aquaspot_postventa/features/tickets/domain/services/evaluacion_mantenimiento_service.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';

typedef P = PlanPreventivoService;

ActividadPreventivaEntity prev(String codigo,
        {TipoActivoMantenimiento tipo = TipoActivoMantenimiento.cosechadora, bool activo = true, String nombre = 'CAMBIO DE ACEITE'}) =>
    ActividadPreventivaEntity(
      id: '${tipo.name}_${codigo.toLowerCase()}',
      codigo: codigo,
      tipoActivo: tipo,
      nombre: nombre,
      horasHombre: 2,
      frecuencia: 250,
      repuestos: const [RepuestoRegistradoEntity(codigo: 'F-10', descripcion: 'FILTRO ACEITE', cantidad: 1)],
      activo: activo,
    );

ItemInventarioEntity inv(String codigo, String descripcion) =>
    ItemInventarioEntity(codigo: codigo, descripcion: descripcion, stockDisponible: 5, fechaActualizacion: DateTime(2026));

class _RepoFalso implements PlanPreventivoRepository {
  ActividadPreventivaEntity? guardada;
  String? desactivada;

  @override
  Future<Either<Failure, ActividadPreventivaEntity>> guardar(ActividadPreventivaEntity actividad) async {
    guardada = actividad.copyWith(id: ActividadPreventivaModel.idDe(actividad));
    return Right(guardada!);
  }

  @override
  Future<Either<Failure, void>> desactivar(String id, {required String usuarioNombre}) async {
    desactivada = id;
    return const Right(null);
  }

  @override
  Future<Either<Failure, List<ActividadPreventivaEntity>>> obtenerPorMaquina(TipoActivoMantenimiento tipo) async =>
      const Right([]);
}

void main() {
  test('Frecuencia según la máquina: horas, km o días', () {
    expect(P.unidadDe(TipoActivoMantenimiento.cosechadora), UnidadFrecuencia.horas);
    expect(P.unidadDe(TipoActivoMantenimiento.vehiculo), UnidadFrecuencia.km);
    for (final t in [
      TipoActivoMantenimiento.contador,
      TipoActivoMantenimiento.caracol,
      TipoActivoMantenimiento.aireAcondicionado,
      TipoActivoMantenimiento.herramientas,
    ]) {
      expect(P.unidadDe(t), UnidadFrecuencia.dias);
    }
    expect(P.textoFrecuencia(prev('PREV-01')), 'cada 250 h');
    expect(P.textoFrecuencia(prev('PREV-01', tipo: TipoActivoMantenimiento.vehiculo).copyWith(frecuencia: 5000)),
        'cada 5000 km');
    expect(P.textoFrecuencia(prev('PREV-01', tipo: TipoActivoMantenimiento.caracol).copyWith(frecuencia: 30)),
        'cada 30 días');
  });

  test('Código PREV-NN correlativo por máquina, contando las desactivadas', () {
    expect(P.siguienteCodigo(const [], TipoActivoMantenimiento.cosechadora), 'PREV-01');
    final todas = [
      prev('PREV-01'),
      prev('PREV-03', activo: false),
      prev('PREV-07', tipo: TipoActivoMantenimiento.vehiculo),
    ];
    expect(P.siguienteCodigo(todas, TipoActivoMantenimiento.cosechadora), 'PREV-04');
    expect(P.siguienteCodigo(todas, TipoActivoMantenimiento.vehiculo), 'PREV-08');
    expect(P.nueva(todas, TipoActivoMantenimiento.caracol).codigo, 'PREV-01');
  });

  test('Activas de la máquina ordenadas y búsqueda sin tildes', () {
    final todas = [
      prev('PREV-02', nombre: 'REVISIÓN DE FRENOS'),
      prev('PREV-01'),
      prev('PREV-03', activo: false),
      prev('PREV-01', tipo: TipoActivoMantenimiento.vehiculo),
    ];
    final activas = P.activasDe(todas, TipoActivoMantenimiento.cosechadora);
    expect(activas.map((a) => a.codigo), ['PREV-01', 'PREV-02']);
    expect(P.buscar(activas, 'revision').single.codigo, 'PREV-02');
    expect(P.buscar(activas, 'prev-01 aceite').single.codigo, 'PREV-01');
    expect(P.buscar(activas, '  '), activas);
  });

  test('Repuestos del inventario: agregar suma, cambiar cantidad y quitar', () {
    var a = prev('PREV-01').copyWith(repuestos: const []);
    a = P.agregarRepuesto(a, inv('F-10', 'FILTRO ACEITE'));
    a = P.agregarRepuesto(a, inv('f-10 ', 'FILTRO ACEITE'));
    expect(a.repuestos.single.cantidad, 2);
    a = P.cambiarCantidad(a, 0, 4.5);
    expect(a.repuestos.single.cantidad, 4.5);
    expect(P.quitarRepuesto(a, 0).repuestos, isEmpty);
  });

  test('Validación', () {
    expect(P.validar(prev('PREV-01')), isEmpty);
    final mal = prev('PREV-01').copyWith(
      nombre: 'X',
      horasHombre: 0,
      frecuencia: 0,
      repuestos: const [RepuestoRegistradoEntity(codigo: '', descripcion: 'SIN CÓDIGO', cantidad: 0)],
    );
    expect(P.validar(mal).length, 5);
    expect(P.validar(mal), contains('Ingrese cada cuánto se hace (h).'));
  });

  test('Solo supervisor y admin lo administran', () {
    expect(P.puedeAdministrar(RolUsuario.supervisor), isTrue);
    expect(P.puedeAdministrar(RolUsuario.admin), isTrue);
    expect(P.puedeAdministrar(RolUsuario.tecnico), isFalse);
  });

  test('Se guarda y se lee igual en Firestore', () {
    final a = prev('PREV-02', tipo: TipoActivoMantenimiento.aireAcondicionado).copyWith(descripcion: 'Limpieza');
    final json = ActividadPreventivaModel.toJson(a)..remove('fechaActualizacion');
    expect(json['unidadFrecuencia'], 'dias');
    final leida = ActividadPreventivaModel.fromJson(json, ActividadPreventivaModel.idDe(a));
    expect(leida, a);
    expect(ActividadPreventivaModel.idDe(a), 'aireAcondicionado_prev-02');
    expect(ActividadPreventivaModel.fromJson({'tipoActivo': 'otro'}, 'x'), isNull);
    expect(ActividadPreventivaModel.toJson(a, incluirActivo: false).containsKey('activo'), isFalse,
        reason: 'editar no reactiva lo que otro desactivó');
  });

  group('Use cases', () {
    test('Guardar: valida, pone el nombre en MAYÚSCULAS y quién la modificó', () async {
      final repo = _RepoFalso();
      final r = await GuardarActividadPreventivaUseCase(repo)(
        prev('PREV-01').copyWith(id: '', nombre: '  cambio de aceite '),
        usuarioNombre: 'Sup',
        rol: RolUsuario.supervisor,
      );
      expect(r.isRight(), isTrue);
      expect(repo.guardada!.nombre, 'CAMBIO DE ACEITE');
      expect(repo.guardada!.actualizadoPor, 'Sup');
      expect(repo.guardada!.id, 'cosechadora_prev-01');
    });

    test('Guardar: rechaza a un técnico y datos inválidos sin escribir', () async {
      final repo = _RepoFalso();
      final uc = GuardarActividadPreventivaUseCase(repo);
      expect((await uc(prev('PREV-01'), usuarioNombre: 'T', rol: RolUsuario.tecnico)).isLeft(), isTrue);
      expect((await uc(prev('PREV-01').copyWith(frecuencia: 0), usuarioNombre: 'S', rol: RolUsuario.admin)).isLeft(),
          isTrue);
      expect(repo.guardada, isNull);
    });

    test('Desactivar', () async {
      final repo = _RepoFalso();
      final r = await DesactivarActividadPreventivaUseCase(repo)(prev('PREV-01'), usuarioNombre: 'S', rol: RolUsuario.admin);
      expect(r.isRight(), isTrue);
      expect(repo.desactivada, 'cosechadora_prev-01');
    });
  });

  group('En la evaluación de mantenimiento', () {
    test('Se agrega modificable con su código, horas y repuestos', () {
      final act = EvaluacionMantenimientoService.desdePreventivo(prev('PREV-01'));
      expect(act.codigo, 'PREV-01');
      expect(act.nombre, 'CAMBIO DE ACEITE');
      expect(act.horasHombre, 2);
      expect(act.repuestos.single.codigo, 'F-10');
      expect(act.observacion, isEmpty);
    });

    test('Disponibles: solo activas y no agregadas', () {
      final plan = [prev('PREV-02'), prev('PREV-01'), prev('PREV-03', activo: false)];
      const agregadas = [ActividadMantenimiento(codigo: 'PREV-02', nombre: 'X')];
      expect(EvaluacionMantenimientoService.preventivasDisponibles(plan, agregadas).map((a) => a.codigo), ['PREV-01']);
    });
  });
}
