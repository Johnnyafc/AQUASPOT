// lib/features/tickets/presentation/bloc/evaluacion_mantenimiento_cubit.dart
//
// Estado de la EVALUACIÓN TÉCNICA de un mantenimiento interno. Las reglas
// (repuestos en una sola lista, consolidado, validación, paso a Compras)
// están en EvaluacionMantenimientoService; aquí solo se guarda lo que el
// técnico arma y se orquesta el envío (desde la revisión del informe):
// subir fotos → subir informe PDF y Solicitud de materiales → guardar.

import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/enum/rol_usuario.dart';
import '../../../catalogo/domain/entities/actividad_catalogo_entity.dart';
import '../../../catalogo/domain/usecases/catalogo_usecases.dart';
import '../../../inventario/domain/entities/item_inventario_entity.dart';
import '../../../inventario/domain/usecases/obtener_stock_inventario_usecase.dart';
import '../../domain/entities/actividad_mantenimiento.dart';
import '../../domain/entities/archivo_adjunto.dart';
import '../../domain/entities/ticket_entity.dart';
import '../../domain/services/evaluacion_mantenimiento_service.dart';
import '../../domain/usecases/guardar_evaluacion_mantenimiento_usecase.dart';
import '../../domain/usecases/subir_archivo_adjunto_usecase.dart';

typedef _S = EvaluacionMantenimientoService;

enum CargaEvaluacionMantenimiento { cargando, lista, error }

enum EnvioEvaluacionMantenimiento { editando, enviando, guardada, error }

class EvaluacionMantenimientoState extends Equatable {
  final TicketEntity? ticket;
  final CargaEvaluacionMantenimiento carga;
  final List<ActividadCatalogoEntity> catalogo;
  final List<ItemInventarioEntity> inventario;
  final List<ActividadMantenimiento> actividades;
  final bool necesitaCompras;
  final String motivoNoCompras;
  final EnvioEvaluacionMantenimiento envio;
  final String mensaje;
  final List<String> errores;

  const EvaluacionMantenimientoState({
    this.ticket,
    this.carga = CargaEvaluacionMantenimiento.cargando,
    this.catalogo = const [],
    this.inventario = const [],
    this.actividades = const [],
    this.necesitaCompras = true,
    this.motivoNoCompras = '',
    this.envio = EnvioEvaluacionMantenimiento.editando,
    this.mensaje = '',
    this.errores = const [],
  });

  EvaluacionMantenimientoState copyWith({
    TicketEntity? ticket,
    CargaEvaluacionMantenimiento? carga,
    List<ActividadCatalogoEntity>? catalogo,
    List<ItemInventarioEntity>? inventario,
    List<ActividadMantenimiento>? actividades,
    bool? necesitaCompras,
    String? motivoNoCompras,
    EnvioEvaluacionMantenimiento? envio,
    String? mensaje,
    List<String>? errores,
  }) {
    return EvaluacionMantenimientoState(
      ticket: ticket ?? this.ticket,
      carga: carga ?? this.carga,
      catalogo: catalogo ?? this.catalogo,
      inventario: inventario ?? this.inventario,
      actividades: actividades ?? this.actividades,
      necesitaCompras: necesitaCompras ?? this.necesitaCompras,
      motivoNoCompras: motivoNoCompras ?? this.motivoNoCompras,
      envio: envio ?? this.envio,
      mensaje: mensaje ?? this.mensaje,
      errores: errores ?? this.errores,
    );
  }

  @override
  List<Object?> get props => [ticket?.id, carga, catalogo, inventario.length, actividades, necesitaCompras,
        motivoNoCompras, envio, mensaje, errores];
}

class EvaluacionMantenimientoCubit extends Cubit<EvaluacionMantenimientoState> {
  final ObtenerActividadesPorEquipoUseCase obtenerActividades;
  final ObtenerStockInventarioUseCase obtenerInventario;
  final SubirArchivoAdjuntoUseCase subirArchivo;
  final GuardarEvaluacionMantenimientoUseCase guardarEvaluacion;

  EvaluacionMantenimientoCubit({
    required this.obtenerActividades,
    required this.obtenerInventario,
    required this.subirArchivo,
    required this.guardarEvaluacion,
  }) : super(const EvaluacionMantenimientoState());

  /// Carga el Plan Maestro del equipo y el inventario registrado.
  Future<void> cargar(TicketEntity ticket) async {
    emit(state.copyWith(ticket: ticket, carga: CargaEvaluacionMantenimiento.cargando));
    final equipo = _S.equipoCatalogo(ticket);
    final catalogo = equipo == null ? null : await obtenerActividades(equipo);
    final inventario = await obtenerInventario();
    final fallo = [
      if (catalogo != null) catalogo.fold((f) => 'Plan Maestro: ${f.message}', (_) => null),
      inventario.fold((f) => 'Inventario: ${f.message}', (_) => null),
    ].whereType<String>();
    emit(state.copyWith(
      carga: fallo.isEmpty ? CargaEvaluacionMantenimiento.lista : CargaEvaluacionMantenimiento.error,
      mensaje: fallo.join('\n'),
      catalogo: catalogo?.getOrElse(() => const []) ?? const [],
      inventario: inventario.getOrElse(() => const []),
    ));
  }

  void _actividades(List<ActividadMantenimiento> lista) => emit(state.copyWith(actividades: lista, errores: const []));

  void _cambiar(int i, ActividadMantenimiento Function(ActividadMantenimiento a) f) =>
      _actividades([...state.actividades]..[i] = f(state.actividades[i]));

  // ------------------------------------------------------------ Actividades
  void agregarActividad(ActividadCatalogoEntity a) => _actividades([...state.actividades, _S.desdeCatalogo(a)]);
  void agregarActividadNueva(String nombre, double? horas) =>
      _actividades([...state.actividades, _S.actividadNueva(state.actividades, nombre: nombre, horasHombre: horas)]);
  void quitarActividad(int i) => _actividades([...state.actividades]..removeAt(i));
  void cambiarHoras(int i, double? horas) => _cambiar(i, (a) => a.copyWith(horasHombre: horas ?? 0));
  void cambiarObservacion(int i, String texto) => _cambiar(i, (a) => a.copyWith(observacion: texto));
  void agregarFotos(int i, List<ArchivoAdjunto> fotos) => _cambiar(i, (a) => a.copyWith(fotos: [...a.fotos, ...fotos]));
  void quitarFoto(int i, int j) => _cambiar(
        i,
        (a) => a.copyWith(
          fotos: [...a.fotos]..removeAt(j),
          fotosUrls: j < a.fotosUrls.length ? ([...a.fotosUrls]..removeAt(j)) : a.fotosUrls,
        ),
      );

  // ------------------------------------------------------------ Repuestos
  void agregarRepuesto(int i, ItemInventarioEntity item) => _cambiar(i, (a) => _S.agregarRepuesto(a, item));
  void agregarRepuestoNoRegistrado(int i, {required String descripcion, required String unidad, required double cantidad}) =>
      _cambiar(i, (a) => _S.agregarRepuestoNoRegistrado(a, descripcion: descripcion, unidad: unidad, cantidad: cantidad));
  void cambiarCantidad(int i, int j, double cantidad) => _cambiar(i, (a) => _S.cambiarCantidad(a, j, cantidad));
  void quitarRepuesto(int i, int j) => _cambiar(i, (a) => _S.quitarRepuesto(a, j));

  // ------------------------------------------------------------ Compras
  void cambiarNecesitaCompras(bool v) => emit(state.copyWith(necesitaCompras: v));
  void cambiarMotivoNoCompras(String texto) => emit(state.copyWith(motivoNoCompras: texto));

  /// Antes de generar el informe: true si la evaluación está completa; si
  /// no, deja los errores a la vista.
  bool validarParaInforme() {
    final errores = _S.validar(state.actividades);
    emit(state.copyWith(errores: errores, envio: EnvioEvaluacionMantenimiento.editando));
    return errores.isEmpty;
  }

  /// Desde la revisión del informe: sube las fotos que faltan, el informe
  /// PDF y la Solicitud de materiales, y guarda la evaluación.
  Future<void> confirmar({
    required Uint8List informePdf,
    required Uint8List solicitudExcel,
    required String usuarioNombre,
    required RolUsuario rol,
  }) async {
    final ticket = state.ticket;
    if (ticket == null || !validarParaInforme()) return;
    emit(state.copyWith(envio: EnvioEvaluacionMantenimiento.enviando, mensaje: 'Guardando evaluación...'));

    // Cada foto subida queda en "fotosUrls" (mismo orden que "fotos"): si
    // algo falla, un reintento solo sube lo que falta.
    final total = state.actividades.fold<int>(0, (s, a) => s + a.fotos.length);
    var subidas = state.actividades.fold<int>(0, (s, a) => s + a.fotosUrls.length);
    for (var i = 0; i < state.actividades.length; i++) {
      while (state.actividades[i].fotosUrls.length < state.actividades[i].fotos.length) {
        final act = state.actividades[i];
        final foto = act.fotos[act.fotosUrls.length];
        emit(state.copyWith(mensaje: 'Subiendo fotos (${subidas + 1}/$total)...'));
        final url = await _subir(foto, ticket.id, 'evaluaciones/actividades');
        if (url == null) return;
        emit(state.copyWith(actividades: [...state.actividades]..[i] = act.copyWith(fotosUrls: [...act.fotosUrls, url])));
        subidas++;
      }
    }

    emit(state.copyWith(mensaje: 'Subiendo informe técnico...'));
    final urlPdf = await _subir(
      ArchivoAdjunto(bytes: informePdf, nombre: 'Informe_Tecnico_${ticket.id}.pdf', tipoContenido: 'application/pdf'),
      ticket.id,
      'evaluaciones/generales',
    );
    if (urlPdf == null) return;
    emit(state.copyWith(mensaje: 'Subiendo solicitud de materiales...'));
    final urlExcel = await _subir(
      ArchivoAdjunto(
        bytes: solicitudExcel,
        nombre: 'Solicitud_Materiales_${ticket.id}.xlsx',
        tipoContenido: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      ),
      ticket.id,
      'evaluaciones/proformas',
    );
    if (urlExcel == null) return;

    emit(state.copyWith(mensaje: 'Guardando evaluación...'));
    final r = await guardarEvaluacion(
      ticket,
      state.actividades,
      necesitaCompras: state.necesitaCompras,
      motivoNoCompras: state.motivoNoCompras,
      usuarioNombre: usuarioNombre,
      rol: rol,
      urlInformePdf: urlPdf,
      urlSolicitudExcel: urlExcel,
    );
    r.fold(
      (f) => emit(state.copyWith(
        envio: EnvioEvaluacionMantenimiento.error,
        mensaje: 'No se pudo guardar la evaluación: ${f.message}',
      )),
      (_) => emit(state.copyWith(
        envio: EnvioEvaluacionMantenimiento.guardada,
        mensaje: 'Evaluación de ${ticket.id} guardada. Pasa a Compras.',
      )),
    );
  }

  /// Sube un archivo; si falla deja el error a la vista y devuelve null.
  Future<String?> _subir(ArchivoAdjunto archivo, String ticketId, String carpeta) async {
    final r = await subirArchivo(archivo, ticketId, carpeta: carpeta);
    return r.fold((f) {
      emit(state.copyWith(
        envio: EnvioEvaluacionMantenimiento.error,
        mensaje: 'No se pudo subir "${archivo.nombre}": ${f.message}',
      ));
      return null;
    }, (u) => u);
  }
}
