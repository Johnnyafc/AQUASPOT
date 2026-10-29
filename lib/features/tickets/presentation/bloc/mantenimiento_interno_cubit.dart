// lib/features/tickets/presentation/bloc/mantenimiento_interno_cubit.dart
//
// Estado del formulario de MANTENIMIENTO INTERNO (Crear Ticket). Las reglas
// (campos por máquina, catálogo de series / placas, validaciones) están
// en FormularioMantenimientoService; aquí solo se guarda lo que el usuario
// llena y se orquesta el envío: crear el ticket → subir la foto del
// horómetro / kilometraje, las fotos y los videos → adjuntarlos.

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/enum/rol_usuario.dart';
import '../../domain/entities/mantenimiento_interno_entity.dart';
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
    );
  }

  @override
  List<Object?> get props => [datos.tipoMantenimiento, datos.tipoActivo, datos.serieOPlaca, datos.horometro,
        datos.kilometraje, datos.fechaHora, datos.marca, datos.especificacion, datos.detalle, fotos, videos, fotoLectura, envio, mensaje, errores,
        ticketCreadoId, catalogo, avisoCatalogo];
}

class MantenimientoInternoCubit extends Cubit<MantenimientoInternoState> {
  final CrearMantenimientoInternoUseCase crearMantenimiento;
  final SubirEvidenciaUseCase subirEvidencia;
  final AdjuntarEvidenciasMantenimientoUseCase adjuntarEvidencias;
  final ObtenerCatalogoActivosMantenimientoUseCase obtenerCatalogo;

  MantenimientoInternoCubit({
    required this.crearMantenimiento,
    required this.subirEvidencia,
    required this.adjuntarEvidencias,
    required this.obtenerCatalogo,
  }) : super(MantenimientoInternoState(datos: DatosMantenimientoInterno(fechaHora: DateTime.now())));

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
  Future<void> enviar({required String usuarioNombre, required RolUsuario rol}) async {
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
