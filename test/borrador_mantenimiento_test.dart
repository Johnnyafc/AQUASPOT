// test/borrador_mantenimiento_test.dart
import 'dart:typed_data';

import 'package:aquaspot_postventa/core/enum/rol_usuario.dart';
import 'package:aquaspot_postventa/core/errors/failures.dart';
import 'package:aquaspot_postventa/features/catalogo/domain/entities/actividad_catalogo_entity.dart';
import 'package:aquaspot_postventa/features/catalogo/domain/usecases/catalogo_usecases.dart';
import 'package:aquaspot_postventa/features/inventario/domain/entities/item_inventario_entity.dart';
import 'package:aquaspot_postventa/features/inventario/domain/usecases/obtener_stock_inventario_usecase.dart';
import 'package:aquaspot_postventa/features/plan_preventivo/domain/entities/actividad_preventiva_entity.dart';
import 'package:aquaspot_postventa/features/plan_preventivo/domain/usecases/plan_preventivo_usecases.dart';
import 'package:aquaspot_postventa/features/tickets/domain/entities/actividad_mantenimiento.dart';
import 'package:aquaspot_postventa/features/tickets/domain/entities/archivo_adjunto.dart';
import 'package:aquaspot_postventa/features/tickets/domain/entities/ficha_creacion_repuesto_entity.dart';
import 'package:aquaspot_postventa/features/tickets/domain/entities/mantenimiento_interno_entity.dart';
import 'package:aquaspot_postventa/features/tickets/domain/entities/repuesto_registrado_entity.dart';
import 'package:aquaspot_postventa/features/tickets/domain/entities/ticket_entity.dart';
import 'package:aquaspot_postventa/features/tickets/domain/repositories/borrador_repository.dart';
import 'package:aquaspot_postventa/features/tickets/domain/repositories/ticket_repository.dart';
import 'package:aquaspot_postventa/features/tickets/domain/services/borrador_mantenimiento_service.dart';
import 'package:aquaspot_postventa/features/tickets/domain/services/formulario_mantenimiento_service.dart';
import 'package:aquaspot_postventa/features/tickets/domain/usecases/adjuntar_evidencias_mantenimiento_usecase.dart';
import 'package:aquaspot_postventa/features/tickets/domain/usecases/borrador_usecases.dart';
import 'package:aquaspot_postventa/features/tickets/domain/usecases/crear_mantenimiento_interno_usecase.dart';
import 'package:aquaspot_postventa/features/tickets/domain/usecases/guardar_evaluacion_mantenimiento_usecase.dart';
import 'package:aquaspot_postventa/features/tickets/domain/usecases/obtener_catalogo_activos_mantenimiento_usecase.dart';
import 'package:aquaspot_postventa/features/tickets/domain/usecases/subir_archivo_adjunto_usecase.dart';
import 'package:aquaspot_postventa/features/tickets/domain/usecases/subir_evidencia_usecase.dart';
import 'package:aquaspot_postventa/features/tickets/presentation/bloc/evaluacion_mantenimiento_cubit.dart';
import 'package:aquaspot_postventa/features/tickets/presentation/bloc/mantenimiento_interno_cubit.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

typedef B = BorradorMantenimientoService;

ArchivoAdjunto archivo(String nombre, int tamano) =>
    ArchivoAdjunto(bytes: Uint8List(tamano), nombre: nombre, tipoContenido: 'image/jpeg');

/// Repositorio de borradores en memoria ([demora]: guardado lento, como
/// IndexedDB con videos).
class Borradores implements IBorradorRepository {
  final Map<String, BorradorLocal> guardados = {};
  Duration demora = Duration.zero;
  @override
  Future<void> guardar(String clave, BorradorLocal borrador) async {
    await Future<void>.delayed(demora);
    guardados[clave] = borrador;
  }
  @override
  Future<BorradorLocal?> obtener(String clave) async => guardados[clave];
  @override
  Future<void> eliminar(String clave) async => guardados.remove(clave);
}

class _F {
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _RepoTickets extends _F implements ITicketRepository {
  static int creados = 0;
  @override
  Future<Either<Failure, TicketEntity>> crearTicket(TicketEntity ticket) async {
    creados++;
    return Right(ticket.copyWith(id: 'OT-00001'));
  }
}

class _SubirEvidencia extends _F implements SubirEvidenciaUseCase {
  @override
  Future<Either<Failure, String>> call(XFile archivo, String ticketId) async => Right('https://f/${archivo.name}');
}

class _Adjuntar extends _F implements AdjuntarEvidenciasMantenimientoUseCase {
  @override
  Future<Either<Failure, TicketEntity>> call(TicketEntity ticket, List<String> urls,
          {List<String> videosUrls = const [], String? urlFotoLectura}) async =>
      Right(ticket);
}

class _Catalogo extends _F implements ObtenerCatalogoActivosMantenimientoUseCase {
  @override
  Future<Either<Failure, CatalogoActivos>> call() async => const Right(FormularioMantenimientoService.catalogoPorDefecto);
}

class _Actividades extends _F implements ObtenerActividadesPorEquipoUseCase {
  @override
  Future<Either<Failure, List<ActividadCatalogoEntity>>> call(String equipo) async => const Right([]);
}

class _Inventario extends _F implements ObtenerStockInventarioUseCase {
  @override
  Future<Either<Failure, List<ItemInventarioEntity>>> call() async => const Right([]);
}

class _Preventivo extends _F implements ObtenerPlanPreventivoUseCase {
  @override
  Future<Either<Failure, List<ActividadPreventivaEntity>>> call(TipoActivoMantenimiento tipo) async => const Right([]);
}

class _SubirArchivo extends _F implements SubirArchivoAdjuntoUseCase {}

class _GuardarEvaluacion extends _F implements GuardarEvaluacionMantenimientoUseCase {}

MantenimientoInternoCubit cubitCreacion(Borradores repo) => MantenimientoInternoCubit(
      crearMantenimiento: CrearMantenimientoInternoUseCase(_RepoTickets()),
      subirEvidencia: _SubirEvidencia(),
      adjuntarEvidencias: _Adjuntar(),
      obtenerCatalogo: _Catalogo(),
      guardarBorrador: GuardarBorradorUseCase(repo),
      obtenerBorrador: ObtenerBorradorUseCase(repo),
      eliminarBorrador: EliminarBorradorUseCase(repo),
    );

EvaluacionMantenimientoCubit cubitEvaluacion(Borradores repo) => EvaluacionMantenimientoCubit(
      obtenerActividades: _Actividades(),
      obtenerInventario: _Inventario(),
      subirArchivo: _SubirArchivo(),
      guardarEvaluacion: _GuardarEvaluacion(),
      obtenerPlanPreventivo: _Preventivo(),
      guardarBorrador: GuardarBorradorUseCase(repo),
      obtenerBorrador: ObtenerBorradorUseCase(repo),
      eliminarBorrador: EliminarBorradorUseCase(repo),
    );

final ahora = DateTime(2026, 10, 29, 10, 30);

const datosCosechadora = DatosMantenimientoInterno(
  tipoMantenimiento: TipoMantenimiento.preventivo,
  tipoActivo: TipoActivoMantenimiento.cosechadora,
  serieOPlaca: 'AQ2',
  horometro: 1520.5,
  detalle: 'Cambio de aceite programado',
);

TicketEntity ot() => FormularioMantenimientoService.construirTicket(
      datosCosechadora.copyWith(cantidadFotos: 1, tieneFotoLectura: true),
      usuarioNombre: 'Ana',
      rol: RolUsuario.requerimiento,
      ahora: ahora,
    ).copyWith(id: 'OT-00007');

void main() {
  group('Creación de OT', () {
    test('Ida y vuelta: datos, fotos, videos y foto de la lectura', () {
      final b = B.creacionABorrador(
        datosCosechadora.copyWith(fechaHora: ahora),
        fotos: [archivo('a.jpg', 10), archivo('b.jpg', 20)],
        videos: [archivo('v.mp4', 30)],
        fotoLectura: archivo('h.jpg', 5),
      );
      final r = B.creacionDesdeBorrador(b)!;
      expect(r.datos.tipoMantenimiento, TipoMantenimiento.preventivo);
      expect(r.datos.tipoActivo, TipoActivoMantenimiento.cosechadora);
      expect(r.datos.serieOPlaca, 'AQ2');
      expect(r.datos.horometro, 1520.5);
      expect(r.datos.fechaHora, ahora);
      expect(r.datos.detalle, 'Cambio de aceite programado');
      expect(r.fotos.map((f) => f.nombre), ['a.jpg', 'b.jpg']);
      expect(r.videos.single.nombre, 'v.mp4');
      expect(r.fotoLectura!.nombre, 'h.jpg');
      expect((r.datos.cantidadFotos, r.datos.cantidadVideos, r.datos.tieneFotoLectura), (2, 1, true));
    });

    test('El mismo archivo conserva su id (no se reescribe en cada guardado)', () {
      final f = archivo('a.jpg', 10);
      expect(B.idArchivo('foto', f), B.idArchivo('foto', archivo('a.jpg', 10)));
      expect(B.idArchivo('foto', f), isNot(B.idArchivo('foto', archivo('a.jpg', 11))));
    });

    test('Si falta un archivo se omite y el resto se recupera', () {
      final b = B.creacionABorrador(datosCosechadora, fotos: [archivo('a.jpg', 10), archivo('b.jpg', 20)]);
      final sinUno = BorradorLocal(datos: b.datos, archivos: Map.of(b.archivos)..remove(b.archivos.keys.first));
      final r = B.creacionDesdeBorrador(sinUno)!;
      expect(r.fotos.single.nombre, 'b.jpg');
      expect(r.datos.cantidadFotos, 1);
    });

    test('Formulario recién abierto: vacío; con algo llenado: no', () {
      expect(B.creacionVacia(const DatosMantenimientoInterno()), isTrue);
      expect(B.creacionVacia(const DatosMantenimientoInterno(), archivos: 1), isFalse);
      expect(B.creacionVacia(datosCosechadora), isFalse);
    });

    test('El borrador de creación es de cada usuario', () {
      expect(B.claveCreacion('u1'), isNot(B.claveCreacion('u2')));
    });

    test('Cubit: un guardado lento en curso no revive el borrador después de crear la OT', () async {
      final repo = Borradores()..demora = const Duration(milliseconds: 50);
      final c = cubitCreacion(repo);
      await c.restaurarBorrador(usuario: 'u1');
      c.elegirTipoActivo(TipoActivoMantenimiento.cosechadora);
      c.cambiarDetalle('Fuga de aceite en la bomba');
      c.cambiarHorometro(300);
      c.agregarFotos([XFile.fromData(Uint8List(8), name: 'f.jpg', path: 'f.jpg')]);
      c.ponerFotoLectura(XFile.fromData(Uint8List(4), name: 'h.jpg', path: 'h.jpg'));
      final enCurso = c.guardarBorradorAhora(); // guardado lento a mitad de camino
      await c.enviar(usuarioNombre: 'Ana', rol: RolUsuario.requerimiento);
      await enCurso;
      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(c.state.envio, EstadoEnvioMantenimiento.creado);
      expect(repo.guardados, isEmpty, reason: 'el borrado espera al guardado en curso');
      await c.close();
    });

    test('Cubit: un doble toque en "Crear" crea una sola OT', () async {
      final repo = Borradores()..demora = const Duration(milliseconds: 50);
      final c = cubitCreacion(repo);
      await c.restaurarBorrador(usuario: 'u1');
      c.elegirTipoActivo(TipoActivoMantenimiento.cosechadora);
      c.cambiarDetalle('Fuga de aceite en la bomba');
      c.cambiarHorometro(300);
      c.agregarFotos([XFile.fromData(Uint8List(8), name: 'f.jpg', path: 'f.jpg')]);
      c.ponerFotoLectura(XFile.fromData(Uint8List(4), name: 'h.jpg', path: 'h.jpg'));
      _RepoTickets.creados = 0;
      await Future.wait([
        c.enviar(usuarioNombre: 'Ana', rol: RolUsuario.requerimiento),
        c.enviar(usuarioNombre: 'Ana', rol: RolUsuario.requerimiento),
      ]);
      expect(_RepoTickets.creados, 1);
      await c.close();
    });

    test('Cubit: si el usuario ya empezó a llenar, la recuperación no lo pisa', () async {
      final repo = Borradores();
      repo.guardados[B.claveCreacion('u1')] = B.creacionABorrador(datosCosechadora);
      final c = cubitCreacion(repo);
      final restaurando = c.restaurarBorrador(usuario: 'u1');
      c.elegirTipoActivo(TipoActivoMantenimiento.vehiculo);
      await restaurando;
      expect(c.state.datos.tipoActivo, TipoActivoMantenimiento.vehiculo);
      expect(c.state.borradorRecuperado, isFalse);
      await c.close();
    });

    test('Borrador dañado: null (se ignora)', () {
      expect(B.creacionDesdeBorrador(const BorradorLocal(datos: {'fotos': 'no es lista'})), isNull);
    });

    test('Cubit: guarda lo llenado, lo recupera al volver y lo borra al crear la OT', () async {
      final repo = Borradores();
      final c1 = cubitCreacion(repo);
      await c1.restaurarBorrador(usuario: 'u1');
      c1.elegirTipoActivo(TipoActivoMantenimiento.cosechadora);
      c1.cambiarDetalle('Fuga de aceite en la bomba');
      c1.cambiarHorometro(300);
      c1.agregarFotos([XFile.fromData(Uint8List(8), name: 'f.jpg', path: 'f.jpg')]);
      await c1.guardarBorradorAhora();
      await c1.close();
      expect(repo.guardados.keys, [B.claveCreacion('u1')]);

      final c2 = cubitCreacion(repo);
      await c2.restaurarBorrador(usuario: 'u1');
      expect(c2.state.borradorRecuperado, isTrue);
      expect(c2.state.versionFormulario, 1);
      expect(c2.state.datos.tipoActivo, TipoActivoMantenimiento.cosechadora);
      expect(c2.state.datos.detalle, 'Fuga de aceite en la bomba');
      expect(c2.state.datos.horometro, 300);
      expect(c2.state.fotos.single.name, 'f.jpg');

      c2.ponerFotoLectura(XFile.fromData(Uint8List(4), name: 'h.jpg', path: 'h.jpg'));
      await c2.enviar(usuarioNombre: 'Ana', rol: RolUsuario.requerimiento);
      expect(c2.state.envio, EstadoEnvioMantenimiento.creado);
      expect(repo.guardados, isEmpty, reason: 'la OT ya se creó: el borrador se borra');
      await c2.close();
    });

    test('Cubit: Descartar borra el borrador y vacía el formulario', () async {
      final repo = Borradores();
      repo.guardados[B.claveCreacion('u1')] = B.creacionABorrador(datosCosechadora);
      final c = cubitCreacion(repo);
      await c.restaurarBorrador(usuario: 'u1');
      await c.descartarBorrador();
      expect(repo.guardados, isEmpty);
      expect(c.state.datos.tipoActivo, isNull);
      expect(c.state.borradorRecuperado, isFalse);
      expect(c.state.versionFormulario, 2);
      await c.close();
    });
  });

  group('Evaluación de OT', () {
    final actividad = ActividadMantenimiento(
      codigo: 'PREV-01',
      nombre: 'Cambio de aceite',
      horasHombre: 2.5,
      observacion: 'Aceite oscuro',
      repuestos: const [
        RepuestoRegistradoEntity(codigo: 'F-1', descripcion: 'FILTRO', cantidad: 2),
        RepuestoRegistradoEntity(codigo: '', descripcion: 'SELLO 40MM', unidad: 'JUEGO'),
      ],
      fotos: [archivo('x.jpg', 7), archivo('y.jpg', 8)],
      fotosUrls: const ['https://f/x.jpg'],
    );
    const ficha = FichaCreacionRepuestoEntity(nombre: 'SELLO 40MM', familiaPieza: 'SELLOS', categoria: 'MEC', activo: true);

    test('Ida y vuelta: actividades (con sus fotos y las ya subidas), fichas y compras', () {
      final b = B.evaluacionABorrador(
        actividades: [actividad],
        fichas: {'|SELLO 40MM': ficha},
        necesitaCompras: false,
        motivoNoCompras: 'Hay stock en taller',
      );
      final r = B.evaluacionDesdeBorrador(b)!;
      final a = r.actividades.single;
      expect((a.codigo, a.nombre, a.horasHombre, a.observacion), ('PREV-01', 'Cambio de aceite', 2.5, 'Aceite oscuro'));
      expect(a.repuestos, actividad.repuestos);
      expect(a.fotos.map((f) => f.nombre), ['x.jpg', 'y.jpg']);
      expect(a.fotosUrls, ['https://f/x.jpg']);
      expect(r.fichas, {'|SELLO 40MM': ficha});
      expect((r.necesitaCompras, r.motivoNoCompras), (false, 'Hay stock en taller'));
    });

    test('Si falta una foto (aunque esté en medio) se quita con su URL: el resto sigue alineado', () {
      final conTres = actividad.copyWith(
        fotos: [archivo('x.jpg', 7), archivo('y.jpg', 8), archivo('z.jpg', 9)],
        fotosUrls: const ['https://f/x.jpg', 'https://f/y.jpg'],
      );
      final b = B.evaluacionABorrador(actividades: [conTres], fichas: const {}, necesitaCompras: true, motivoNoCompras: '');
      final idY = b.archivos.entries.firstWhere((e) => e.value.nombre == 'y.jpg').key;
      final r = B.evaluacionDesdeBorrador(BorradorLocal(datos: b.datos, archivos: Map.of(b.archivos)..remove(idY)))!;
      expect(r.actividades.single.fotos.map((f) => f.nombre), ['x.jpg', 'z.jpg']);
      expect(r.actividades.single.fotosUrls, ['https://f/x.jpg'], reason: 'z.jpg no estaba subida: se subirá');
    });

    test('Dos fotos distintas con el mismo nombre y tamaño tienen ids distintos', () {
      final a = ArchivoAdjunto(bytes: Uint8List.fromList([1, 2, 3]), nombre: 'foto.jpg');
      final b = ArchivoAdjunto(bytes: Uint8List.fromList([4, 5, 6]), nombre: 'foto.jpg');
      expect(B.idArchivo('act', a), isNot(B.idArchivo('act', b)));
    });

    test('Cubit: al abrir la OT recupera lo avanzado; Descartar lo borra', () async {
      final repo = Borradores();
      final t = ot();
      repo.guardados[B.claveEvaluacion(t.id)] = B.evaluacionABorrador(
        actividades: [actividad],
        fichas: {'|SELLO 40MM': ficha},
        necesitaCompras: false,
        motivoNoCompras: 'Hay stock',
      );
      final c = cubitEvaluacion(repo);
      await c.cargar(t);
      expect(c.state.borradorRecuperado, isTrue);
      expect(c.state.actividades.single.codigo, 'PREV-01');
      expect(c.state.necesitaCompras, isFalse);

      await c.descartarBorrador();
      expect(repo.guardados, isEmpty);
      expect(c.state.actividades, isEmpty);
      expect(c.state.necesitaCompras, isTrue);
      await c.close();
    });

    test('Cubit: sin borrador abre vacío; lo que se agrega se guarda por OT', () async {
      final repo = Borradores();
      final c = cubitEvaluacion(repo);
      await c.cargar(ot());
      expect(c.state.borradorRecuperado, isFalse);
      c.agregarActividadNueva('Revisión de sellos', 1.5);
      await c.guardarBorradorAhora();
      expect(repo.guardados.keys, [B.claveEvaluacion('OT-00007')]);
      await c.close();
    });
  });
}
