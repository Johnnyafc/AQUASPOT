// lib/features/tickets/presentation/bloc/mantenimiento_interno_cubit.dart
//
// Estado del formulario de MANTENIMIENTO INTERNO (Crear Ticket). Las reglas
// (campos por máquina, catálogo de series / placas, validaciones) están
// en FormularioMantenimientoService; aquí solo se guarda lo que el usuario
// llena y se orquesta el envío: crear el ticket → subir la foto del
// horómetro / kilometraje, las fotos y los videos → adjuntarlos.
// Borrador: lo llenado se guarda solo (unos segundos después de cada cambio)
// y se recupera al volver a abrir; se borra al crear la OT
// (BorradorMantenimientoService).

import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/enum/rol_usuario.dart';
import '../../domain/entities/archivo_adjunto.dart';
import '../../domain/entities/mantenimiento_interno_entity.dart';
import '../../domain/services/borrador_mantenimiento_service.dart';
import '../../domain/usecases/borrador_usecases.dart';
import '../../domain/services/formulario_mantenimiento_service.dart';
import '../../domain/usecases/adjuntar_evidencias_mantenimiento_usecase.dart';
import '../../domain/usecases/crear_mantenimiento_interno_usecase.dart';
import '../../domain/usecases/obtener_catalogo_activos_mantenimiento_usecase.dart';
import '../../domain/usecases/subir_evidencia_usecase.dart';

enum EstadoEnvioMantenimiento { editando, enviando, creado, error }

class MantenimientoInternoState extends Equatable {
  final DatosMantenimientoInterno datos;
  final List<XFile> fotos;
  final List<XFile> videos;
  final XFile? fotoLectura; // foto del horómetro / kilometraje
  final EstadoEnvioMantenimiento envio;
  final String mensaje;
  final List<String> errores;
  final String? ticketCreadoId;
  // Series / placas por tipo (de Firestore; por defecto mientras carga).
  final CatalogoActivos catalogo;
  final String avisoCatalogo; // si no se pudo leer el catálogo
  // Sube cada vez que el formulario se reemplaza entero (borrador recuperado
  // o descartado): la pantalla vuelve a llenar sus campos de texto.
  final int versionFormulario;
  final bool borradorRecuperado;

  const MantenimientoInternoState({
    this.datos = const DatosMantenimientoInterno(),
    this.fotos = const [],
    this.videos = const [],
    this.fotoLectura,
    this.envio = EstadoEnvioMantenimiento.editando,
    this.mensaje = '',
    this.errores = const [],
    this.ticketCreadoId,
    this.catalogo = FormularioMantenimientoService.catalogoPorDefecto,
    this.avisoCatalogo = '',
    this.versionFormulario = 0,
    this.borradorRecuperado = false,
  });

  MantenimientoInternoState copyWith({
    DatosMantenimientoInterno? datos,
    List<XFile>? fotos,
    List<XFile>? videos,
    XFile? fotoLectura,
    bool limpiarFotoLectura = false,
    EstadoEnvioMantenimiento? envio,
    String? mensaje,
    List<String>? errores,
    String? ticketCreadoId,
    CatalogoActivos? catalogo,
    String? avisoCatalogo,
    int? versionFormulario,
    bool? borradorRecuperado,
  }) {
    return MantenimientoInternoState(
      datos: datos ?? this.datos,
      fotos: fotos ?? this.fotos,
      videos: videos ?? this.videos,
      fotoLectura: limpiarFotoLectura ? null : (fotoLectura ?? this.fotoLectura),
      envio: envio ?? this.envio,
      mensaje: mensaje ?? this.mensaje,
      errores: errores ?? this.errores,
      ticketCreadoId: ticketCreadoId ?? this.ticketCreadoId,
      catalogo: catalogo ?? this.catalogo,
      avisoCatalogo: avisoCatalogo ?? this.avisoCatalogo,
      versionFormulario: versionFormulario ?? this.versionFormulario,
      borradorRecuperado: borradorRecuperado ?? this.borradorRecuperado,
    );
  }

  @override
  List<Object?> get props => [datos.tipoMantenimiento, datos.tipoActivo, datos.serieOPlaca, datos.horometro,
        datos.kilometraje, datos.fechaHora, datos.marca, datos.especificacion, datos.detalle, fotos, videos, fotoLectura, envio, mensaje, errores,
        ticketCreadoId, catalogo, avisoCatalogo, versionFormulario, borradorRecuperado];
}

class MantenimientoInternoCubit extends Cubit<MantenimientoInternoState> {
  final CrearMantenimientoInternoUseCase crearMantenimiento;
  final SubirEvidenciaUseCase subirEvidencia;
  final AdjuntarEvidenciasMantenimientoUseCase adjuntarEvidencias;
  final ObtenerCatalogoActivosMantenimientoUseCase obtenerCatalogo;
  final GuardarBorradorUseCase guardarBorrador;
  final ObtenerBorradorUseCase obtenerBorrador;
  final EliminarBorradorUseCase eliminarBorrador;

  /// Pausa antes de guardar el borrador (se guarda una vez, no en cada tecla).
  static const Duration pausaBorrador = Duration(seconds: 2);
  // Un borrador por usuario (PC compartida del taller): se fija al restaurar.
  String _clave = BorradorMantenimientoService.claveCreacion('');

  Timer? _timerBorrador;
  // Guardados en fila: uno espera al anterior, y borrar espera a ambos.
  Future<void> _guardando = Future.value();
  bool _borradorActivo = true; // false desde que se crea la OT
  // Bytes de cada archivo ya leído: se leen una sola vez, no en cada guardado.
  final Map<XFile, ArchivoAdjunto> _archivos = {};

  MantenimientoInternoCubit({
    required this.crearMantenimiento,
    required this.subirEvidencia,
    required this.adjuntarEvidencias,
    required this.obtenerCatalogo,
    required this.guardarBorrador,
    required this.obtenerBorrador,
    required this.eliminarBorrador,
  }) : super(MantenimientoInternoState(datos: DatosMantenimientoInterno(fechaHora: DateTime.now())));

  // ------------------------------------------------------------ Borrador
  @override
  void onChange(Change<MantenimientoInternoState> change) {
    super.onChange(change);
    final a = change.currentState, b = change.nextState;
    final cambioFormulario = a.datos != b.datos || a.fotos != b.fotos || a.videos != b.videos || a.fotoLectura != b.fotoLectura;
    if (_borradorActivo && cambioFormulario && b.envio != EstadoEnvioMantenimiento.enviando) {
      _timerBorrador?.cancel();
      _timerBorrador = Timer(pausaBorrador, guardarBorradorAhora);
    }
  }

  Future<ArchivoAdjunto> _adjunto(XFile f) async =>
      _archivos[f] ??= ArchivoAdjunto(bytes: await f.readAsBytes(), nombre: f.name, tipoContenido: f.mimeType);

  /// Guarda lo llenado (o borra el borrador si el formulario está vacío).
  Future<void> guardarBorradorAhora() {
    _timerBorrador?.cancel();
    return _guardando = _guardando.then((_) => _guardar()).catchError((_) {});
  }

  Future<void> _guardar() async {
    if (!_borradorActivo) return;
    final s = state;
    final n = s.fotos.length + s.videos.length + (s.fotoLectura == null ? 0 : 1);
    if (BorradorMantenimientoService.creacionVacia(s.datos, archivos: n)) {
      await eliminarBorrador(_clave);
      return;
    }
    final borrador = BorradorMantenimientoService.creacionABorrador(
      s.datos,
      fotos: [for (final f in s.fotos) await _adjunto(f)],
      videos: [for (final v in s.videos) await _adjunto(v)],
      fotoLectura: s.fotoLectura == null ? null : await _adjunto(s.fotoLectura!),
    );
    if (_borradorActivo) await guardarBorrador(_clave, borrador);
  }

  /// Deja de guardar y borra el borrador, después del guardado en curso.
  Future<void> _terminarBorrador() async {
    _borradorActivo = false;
    _timerBorrador?.cancel();
    await _guardando;
    await eliminarBorrador(_clave);
  }

  XFile _xfile(ArchivoAdjunto a) {
    // path: en el celular el nombre sale de la ruta; en web se ignora.
    final f = XFile.fromData(a.bytes, name: a.nombre, path: a.nombre, mimeType: a.tipoContenido, length: a.bytes.length);
    _archivos[f] = a;
    return f;
  }

  /// Recupera lo que [usuario] dejó llenado la última vez (si hay algo).
  /// Si mientras se leía ya empezó a llenar el formulario, no se pisa.
  Future<void> restaurarBorrador({required String usuario}) async {
    _clave = BorradorMantenimientoService.claveCreacion(usuario);
    final antes = state;
    final guardado = await obtenerBorrador(_clave);
    if (isClosed || guardado == null) return;
    final b = BorradorMantenimientoService.creacionDesdeBorrador(guardado);
    final tocado = !identical(state.datos, antes.datos) ||
        state.fotos != antes.fotos ||
        state.videos != antes.videos ||
        state.fotoLectura != antes.fotoLectura;
    if (b == null || tocado || state.envio != EstadoEnvioMantenimiento.editando) return;
    emit(state.copyWith(
      datos: b.datos.fechaHora == null ? b.datos.copyWith(fechaHora: state.datos.fechaHora) : b.datos,
      fotos: [for (final a in b.fotos) _xfile(a)],
      videos: [for (final a in b.videos) _xfile(a)],
      fotoLectura: b.fotoLectura == null ? null : _xfile(b.fotoLectura!),
      limpiarFotoLectura: b.fotoLectura == null,
      versionFormulario: state.versionFormulario + 1,
      borradorRecuperado: true,
      errores: const [],
    ));
  }

  /// Empieza de cero: borra el borrador y vacía el formulario.
  Future<void> descartarBorrador() async {
    _timerBorrador?.cancel();
    await _guardando;
    await eliminarBorrador(_clave);
    if (isClosed) return;
    _archivos.clear();
    emit(MantenimientoInternoState(
      datos: DatosMantenimientoInterno(fechaHora: DateTime.now()),
      catalogo: state.catalogo,
      avisoCatalogo: state.avisoCatalogo,
      versionFormulario: state.versionFormulario + 1,
    ));
  }

  /// Al salir se guarda lo de los últimos segundos (si había un guardado
  /// pendiente).
  @override
  Future<void> close() {
    if (_timerBorrador?.isActive ?? false) guardarBorradorAhora();
    _timerBorrador?.cancel();
    return super.close();
  }

  /// Series y placas de Firestore. Si no se pueden leer, se queda el
  /// catálogo por defecto y se avisa en el formulario.
  Future<void> cargarCatalogo() async {
    final r = await obtenerCatalogo();
    if (isClosed) return;
    r.fold(
      (f) => emit(state.copyWith(avisoCatalogo: 'No se pudo leer el catálogo de series y placas (${f.message}); se muestran las de siempre.')),
      (c) => emit(state.copyWith(catalogo: c, avisoCatalogo: '', datos: _serieSegun(state.datos, c))),
    );
  }

  /// Si la máquina ya estaba elegida cuando llegó el catálogo, su serie /
  /// placa se vuelve a elegir con las opciones nuevas.
  static DatosMantenimientoInterno _serieSegun(DatosMantenimientoInterno d, CatalogoActivos c) {
    final tipo = d.tipoActivo;
    if (tipo == null || FormularioMantenimientoService.serieManual(tipo)) return d;
    final opciones = FormularioMantenimientoService.opcionesDe(tipo, c);
    if (opciones.contains(d.serieOPlaca)) return d;
    return opciones.length == 1 ? d.copyWith(serieOPlaca: opciones.first) : d.copyWith(limpiarSerieOPlaca: true);
  }

  void _datos(DatosMantenimientoInterno d) => emit(state.copyWith(datos: d, errores: const []));

  void elegirTipoMantenimiento(TipoMantenimiento t) => _datos(state.datos.copyWith(tipoMantenimiento: t));
  void elegirTipoActivo(TipoActivoMantenimiento t) {
    if (state.datos.tipoActivo == t) return;
    emit(state.copyWith(
      datos: FormularioMantenimientoService.cambiarTipoActivo(state.datos, t, catalogo: state.catalogo),
      limpiarFotoLectura: true,
      errores: const [],
    ));
  }
  void elegirSerieOPlaca(String valor) => _datos(state.datos.copyWith(serieOPlaca: valor));
  void cambiarHorometro(double? v) =>
      _datos(v == null ? state.datos.copyWith(limpiarHorometro: true) : state.datos.copyWith(horometro: v));
  void cambiarKilometraje(double? v) =>
      _datos(v == null ? state.datos.copyWith(limpiarKilometraje: true) : state.datos.copyWith(kilometraje: v));
  void cambiarFechaHora(DateTime f) => _datos(state.datos.copyWith(fechaHora: f));
  void cambiarDetalle(String texto) => _datos(state.datos.copyWith(detalle: texto));
  void cambiarMarca(String texto) => _datos(state.datos.copyWith(marca: texto));
  void cambiarEspecificacion(String texto) => _datos(state.datos.copyWith(especificacion: texto));

  void agregarFotos(List<XFile> nuevas) {
    final fotos = [...state.fotos, ...nuevas];
    emit(state.copyWith(fotos: fotos, datos: state.datos.copyWith(cantidadFotos: fotos.length), errores: const []));
  }

  void quitarFoto(int index) {
    final fotos = [...state.fotos]..removeAt(index);
    emit(state.copyWith(fotos: fotos, datos: state.datos.copyWith(cantidadFotos: fotos.length)));
  }

  void agregarVideos(List<XFile> nuevos) {
    final videos = [...state.videos, ...nuevos];
    emit(state.copyWith(videos: videos, datos: state.datos.copyWith(cantidadVideos: videos.length), errores: const []));
  }

  void quitarVideo(int index) {
    final videos = [...state.videos]..removeAt(index);
    emit(state.copyWith(videos: videos, datos: state.datos.copyWith(cantidadVideos: videos.length)));
  }

  void ponerFotoLectura(XFile foto) =>
      emit(state.copyWith(fotoLectura: foto, datos: state.datos.copyWith(tieneFotoLectura: true), errores: const []));

  void quitarFotoLectura() =>
      emit(state.copyWith(limpiarFotoLectura: true, datos: state.datos.copyWith(tieneFotoLectura: false)));

  /// Crea el ticket, sube las evidencias y las adjunta. Si un archivo falla,
  /// el ticket ya quedó creado: se avisa cuál y con qué número.
  bool _enviando = false;

  /// Un solo envío a la vez: un doble toque no crea dos OT.
  Future<void> enviar({required String usuarioNombre, required RolUsuario rol}) async {
    if (_enviando) return;
    _enviando = true;
    try {
      await _enviar(usuarioNombre: usuarioNombre, rol: rol);
    } finally {
      _enviando = false;
    }
  }

  Future<void> _enviar({required String usuarioNombre, required RolUsuario rol}) async {
    // Lo último escrito queda en el borrador (si algo falla, no se pierde).
    await guardarBorradorAhora();
    final errores = FormularioMantenimientoService.validar(state.datos, ahora: DateTime.now(), catalogo: state.catalogo);
    if (errores.isNotEmpty) {
      emit(state.copyWith(errores: errores, envio: EstadoEnvioMantenimiento.editando));
      return;
    }
    emit(state.copyWith(envio: EstadoEnvioMantenimiento.enviando, mensaje: 'Creando requerimiento...', errores: const []));

    final creado = await crearMantenimiento(state.datos, usuarioNombre: usuarioNombre, rol: rol, catalogo: state.catalogo);
    final ticket = creado.fold((_) => null, (t) => t);
    if (ticket == null) {
      final msg = creado.fold((f) => f.message, (_) => '');
      emit(state.copyWith(envio: EstadoEnvioMantenimiento.error, mensaje: 'No se pudo crear el requerimiento: $msg'));
      return;
    }
    // La OT ya existe: el borrador no debe volver a crearla.
    await _terminarBorrador();

    // Foto de la lectura primero, luego fotos y videos, en ese orden.
    final archivos = [if (state.fotoLectura != null) state.fotoLectura!, ...state.fotos, ...state.videos];
    final urls = <String>[];
    for (final archivo in archivos) {
      emit(state.copyWith(mensaje: 'Subiendo evidencias a ${ticket.id} (${urls.length + 1}/${archivos.length})...'));
      final r = await subirEvidencia(archivo, ticket.id);
      final url = r.fold((_) => null, (u) => u);
      if (url == null) {
        final msg = r.fold((f) => f.message, (_) => '');
        emit(state.copyWith(
          envio: EstadoEnvioMantenimiento.error,
          ticketCreadoId: ticket.id,
          mensaje: 'El requerimiento ${ticket.id} se creó, pero no se pudo subir "${archivo.name}": $msg',
        ));
        return;
      }
      urls.add(url);
    }
    final conLectura = state.fotoLectura != null ? 1 : 0;
    final adjunto = await adjuntarEvidencias(
      ticket,
      urls.sublist(conLectura, conLectura + state.fotos.length),
      urlFotoLectura: conLectura == 1 ? urls.first : null,
      videosUrls: urls.sublist(conLectura + state.fotos.length),
    );
    adjunto.fold(
      (f) => emit(state.copyWith(
        envio: EstadoEnvioMantenimiento.error,
        ticketCreadoId: ticket.id,
        mensaje: 'El requerimiento ${ticket.id} se creó, pero no se pudieron guardar las evidencias: ${f.message}',
      )),
      (_) => emit(state.copyWith(
        envio: EstadoEnvioMantenimiento.creado,
        ticketCreadoId: ticket.id,
        mensaje: 'Requerimiento ${ticket.id} creado',
      )),
    );
  }
}
