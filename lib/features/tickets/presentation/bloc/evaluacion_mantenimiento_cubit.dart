// lib/features/tickets/presentation/bloc/evaluacion_mantenimiento_cubit.dart
//
// Estado de la EVALUACIÓN TÉCNICA de un mantenimiento interno. Las reglas
// (repuestos en una sola lista, consolidado, validación, paso a Compras)
// están en EvaluacionMantenimientoService; aquí solo se guarda lo que el
// técnico arma (incluidas las fichas de creación de código de los repuestos
// sin código) y se orquesta el envío (desde la revisión del informe):
// subir fotos → subir informe PDF y Solicitud de materiales → guardar.

import 'dart:async';
import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/enum/rol_usuario.dart';
import '../../../../core/enum/ticket_enums.dart';
import '../../../catalogo/domain/entities/actividad_catalogo_entity.dart';
import '../../../catalogo/domain/usecases/catalogo_usecases.dart';
import '../../../inventario/domain/entities/item_inventario_entity.dart';
import '../../../inventario/domain/usecases/obtener_stock_inventario_usecase.dart';
import '../../../plan_preventivo/domain/entities/actividad_preventiva_entity.dart';
import '../../../plan_preventivo/domain/usecases/plan_preventivo_usecases.dart';
import '../../domain/entities/actividad_mantenimiento.dart';
import '../../domain/entities/archivo_adjunto.dart';
import '../../domain/entities/ficha_creacion_repuesto_entity.dart';
import '../../domain/entities/ticket_entity.dart';
import '../../domain/services/borrador_mantenimiento_service.dart';
import '../../domain/services/creacion_codigos_mantenimiento_service.dart';
import '../../domain/services/evaluacion_mantenimiento_service.dart';
import '../../domain/usecases/borrador_usecases.dart';
import '../../domain/usecases/guardar_evaluacion_mantenimiento_usecase.dart';
import '../../domain/usecases/subir_archivo_adjunto_usecase.dart';

typedef _S = EvaluacionMantenimientoService;

enum CargaEvaluacionMantenimiento { cargando, lista, error }

enum EnvioEvaluacionMantenimiento { editando, enviando, guardada, error }

class EvaluacionMantenimientoState extends Equatable {
  final TicketEntity? ticket;
  final CargaEvaluacionMantenimiento carga;
  final List<ActividadCatalogoEntity> catalogo;
  final List<ActividadPreventivaEntity> planPreventivo; // de la máquina
  final List<ItemInventarioEntity> inventario;
  final List<ActividadMantenimiento> actividades;
  // Fichas de creación de código de los repuestos sin código (clave:
  // CreacionCodigosMantenimientoService.claveFicha).
  final Map<String, FichaCreacionRepuestoEntity> fichas;
  final bool necesitaCompras;
  final String motivoNoCompras;
  final EnvioEvaluacionMantenimiento envio;
  final String mensaje;
  final List<String> errores;
  // Sube cuando la evaluación se reemplaza entera (borrador recuperado o
  // descartado): la pantalla vuelve a dibujar sus campos de texto.
  final int versionFormulario;
  final bool borradorRecuperado;

  const EvaluacionMantenimientoState({
    this.ticket,
    this.carga = CargaEvaluacionMantenimiento.cargando,
    this.catalogo = const [],
    this.planPreventivo = const [],
    this.inventario = const [],
    this.actividades = const [],
    this.fichas = const {},
    this.necesitaCompras = true,
    this.motivoNoCompras = '',
    this.envio = EnvioEvaluacionMantenimiento.editando,
    this.mensaje = '',
    this.errores = const [],
    this.versionFormulario = 0,
    this.borradorRecuperado = false,
  });

  EvaluacionMantenimientoState copyWith({
    TicketEntity? ticket,
    CargaEvaluacionMantenimiento? carga,
    List<ActividadCatalogoEntity>? catalogo,
    List<ActividadPreventivaEntity>? planPreventivo,
    List<ItemInventarioEntity>? inventario,
    List<ActividadMantenimiento>? actividades,
    Map<String, FichaCreacionRepuestoEntity>? fichas,
    bool? necesitaCompras,
    String? motivoNoCompras,
    EnvioEvaluacionMantenimiento? envio,
    String? mensaje,
    List<String>? errores,
    int? versionFormulario,
    bool? borradorRecuperado,
  }) {
    return EvaluacionMantenimientoState(
      ticket: ticket ?? this.ticket,
      carga: carga ?? this.carga,
      catalogo: catalogo ?? this.catalogo,
      planPreventivo: planPreventivo ?? this.planPreventivo,
      inventario: inventario ?? this.inventario,
      actividades: actividades ?? this.actividades,
      fichas: fichas ?? this.fichas,
      necesitaCompras: necesitaCompras ?? this.necesitaCompras,
      motivoNoCompras: motivoNoCompras ?? this.motivoNoCompras,
      envio: envio ?? this.envio,
      mensaje: mensaje ?? this.mensaje,
      errores: errores ?? this.errores,
      versionFormulario: versionFormulario ?? this.versionFormulario,
      borradorRecuperado: borradorRecuperado ?? this.borradorRecuperado,
    );
  }

  @override
  List<Object?> get props => [ticket?.id, carga, catalogo, planPreventivo, inventario.length, actividades, fichas, necesitaCompras,
        motivoNoCompras, envio, mensaje, errores, versionFormulario, borradorRecuperado];
}

class EvaluacionMantenimientoCubit extends Cubit<EvaluacionMantenimientoState> {
  final ObtenerActividadesPorEquipoUseCase obtenerActividades;
  final ObtenerStockInventarioUseCase obtenerInventario;
  final SubirArchivoAdjuntoUseCase subirArchivo;
  final GuardarEvaluacionMantenimientoUseCase guardarEvaluacion;
  final ObtenerPlanPreventivoUseCase obtenerPlanPreventivo;
  final GuardarBorradorUseCase guardarBorrador;
  final ObtenerBorradorUseCase obtenerBorrador;
  final EliminarBorradorUseCase eliminarBorrador;

  /// Pausa antes de guardar el borrador (se guarda una vez, no en cada tecla).
  static const Duration pausaBorrador = Duration(seconds: 2);

  Timer? _timerBorrador;
  // Guardados en fila: uno espera al anterior, y borrar espera a ambos.
  Future<void> _guardando = Future.value();
  bool _borradorActivo = true; // false desde que se guarda la evaluación

  EvaluacionMantenimientoCubit({
    required this.obtenerActividades,
    required this.obtenerInventario,
    required this.subirArchivo,
    required this.guardarEvaluacion,
    required this.obtenerPlanPreventivo,
    required this.guardarBorrador,
    required this.obtenerBorrador,
    required this.eliminarBorrador,
  }) : super(const EvaluacionMantenimientoState());

  // ------------------------------------------------------------ Borrador
  String? get _clave => state.ticket == null ? null : BorradorMantenimientoService.claveEvaluacion(state.ticket!.id);

  @override
  void onChange(Change<EvaluacionMantenimientoState> change) {
    super.onChange(change);
    final a = change.currentState, b = change.nextState;
    final cambio = a.actividades != b.actividades ||
        a.fichas != b.fichas ||
        a.necesitaCompras != b.necesitaCompras ||
        a.motivoNoCompras != b.motivoNoCompras;
    final editando = b.carga != CargaEvaluacionMantenimiento.cargando &&
        b.envio != EnvioEvaluacionMantenimiento.enviando &&
        b.envio != EnvioEvaluacionMantenimiento.guardada;
    if (cambio && editando) {
      _timerBorrador?.cancel();
      _timerBorrador = Timer(pausaBorrador, guardarBorradorAhora);
    }
  }

  /// Guarda lo avanzado (o borra el borrador si no hay nada).
  Future<void> guardarBorradorAhora() {
    _timerBorrador?.cancel();
    return _guardando = _guardando.then((_) => _guardar()).catchError((_) {});
  }

  Future<void> _guardar() async {
    final clave = _clave;
    final s = state;
    if (clave == null || !_borradorActivo) return;
    if (BorradorMantenimientoService.evaluacionVacia(
      actividades: s.actividades,
      fichas: s.fichas,
      necesitaCompras: s.necesitaCompras,
      motivoNoCompras: s.motivoNoCompras,
    )) {
      await eliminarBorrador(clave);
      return;
    }
    await guardarBorrador(
      clave,
      BorradorMantenimientoService.evaluacionABorrador(
        actividades: s.actividades,
        fichas: s.fichas,
        necesitaCompras: s.necesitaCompras,
        motivoNoCompras: s.motivoNoCompras,
      ),
    );
  }

  /// Empieza de cero: borra el borrador y quita lo recuperado.
  Future<void> descartarBorrador() async {
    _timerBorrador?.cancel();
    await _guardando;
    final clave = _clave;
    if (clave != null) await eliminarBorrador(clave);
    if (isClosed) return;
    emit(state.copyWith(
      actividades: const [],
      fichas: const {},
      necesitaCompras: true,
      motivoNoCompras: '',
      errores: const [],
      borradorRecuperado: false,
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

  /// Carga el Plan Maestro del equipo, el Plan Preventivo de la máquina y
  /// el inventario registrado.
  Future<void> cargar(TicketEntity ticket) async {
    emit(state.copyWith(ticket: ticket, carga: CargaEvaluacionMantenimiento.cargando));
    final equipo = _S.equipoCatalogo(ticket);
    final tipo = ticket.mantenimientoInterno?.tipoActivo;
    final catalogo = equipo == null ? null : await obtenerActividades(equipo);
    final preventivo = tipo == null ? null : await obtenerPlanPreventivo(tipo);
    final inventario = await obtenerInventario();
    // Lo avanzado la última vez en esta OT (si quedó algo sin enviar).
    final guardado = await obtenerBorrador(BorradorMantenimientoService.claveEvaluacion(ticket.id));
    final borrador = guardado == null ? null : BorradorMantenimientoService.evaluacionDesdeBorrador(guardado);
    final fallo = [
      if (catalogo != null) catalogo.fold((f) => 'Plan Maestro: ${f.message}', (_) => null),
      if (preventivo != null) preventivo.fold((f) => 'Plan Preventivo: ${f.message}', (_) => null),
      inventario.fold((f) => 'Inventario: ${f.message}', (_) => null),
    ].whereType<String>();
    emit(state.copyWith(
      carga: fallo.isEmpty ? CargaEvaluacionMantenimiento.lista : CargaEvaluacionMantenimiento.error,
      mensaje: fallo.join('\n'),
      catalogo: catalogo?.getOrElse(() => const []) ?? const [],
      planPreventivo: preventivo?.getOrElse(() => const []) ?? const [],
      inventario: inventario.getOrElse(() => const []),
      actividades: borrador?.actividades,
      fichas: borrador?.fichas,
      necesitaCompras: borrador?.necesitaCompras,
      motivoNoCompras: borrador?.motivoNoCompras,
      borradorRecuperado: borrador != null,
      versionFormulario: borrador == null ? null : state.versionFormulario + 1,
    ));
  }

  void _actividades(List<ActividadMantenimiento> lista) => emit(state.copyWith(actividades: lista, errores: const []));

  void _cambiar(int i, ActividadMantenimiento Function(ActividadMantenimiento a) f) =>
      _actividades([...state.actividades]..[i] = f(state.actividades[i]));

  // ------------------------------------------------------------ Actividades
  void agregarActividad(ActividadCatalogoEntity a) => _actividades([...state.actividades, _S.desdeCatalogo(a)]);
  void agregarActividadPreventiva(ActividadPreventivaEntity a) =>
      _actividades([...state.actividades, _S.desdePreventivo(a)]);
  void agregarActividadNueva(String nombre, double? horas) =>
      _actividades([...state.actividades, _S.actividadNueva(state.actividades, nombre: nombre, horasHombre: horas)]);
  void quitarActividad(int i) => _actividades([...state.actividades]..removeAt(i));
  /// El nombre se puede editar; el código no cambia.
  void cambiarNombre(int i, String nombre) => _cambiar(i, (a) => a.copyWith(nombre: nombre));
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

  /// Ficha de creación de código de un repuesto sin código.
  void ponerFicha(String descripcion, FichaCreacionRepuestoEntity ficha) => emit(state.copyWith(
        fichas: {...state.fichas, CreacionCodigosMantenimientoService.claveFicha(descripcion): ficha},
        errores: const [],
      ));

  // ------------------------------------------------------------ Compras
  void cambiarNecesitaCompras(bool v) => emit(state.copyWith(necesitaCompras: v));
  void cambiarMotivoNoCompras(String texto) => emit(state.copyWith(motivoNoCompras: texto));

  /// Antes de generar el informe: true si la evaluación está completa; si
  /// no, deja los errores a la vista.
  bool validarParaInforme() {
    final errores = _S.validar(state.actividades, fichas: state.fichas);
    emit(state.copyWith(errores: errores, envio: EnvioEvaluacionMantenimiento.editando));
    return errores.isEmpty;
  }

  /// Desde la revisión del informe: sube las fotos que faltan, el informe
  /// PDF y la Solicitud de materiales, y guarda la evaluación.
  bool _confirmando = false;

  /// Un solo envío a la vez: un doble toque no guarda la evaluación dos veces.
  Future<void> confirmar({
    required Uint8List informePdf,
    required Uint8List solicitudExcel,
    required String usuarioNombre,
    required RolUsuario rol,
  }) async {
    if (_confirmando) return;
    _confirmando = true;
    try {
      await _confirmar(informePdf: informePdf, solicitudExcel: solicitudExcel, usuarioNombre: usuarioNombre, rol: rol);
    } finally {
      _confirmando = false;
    }
  }

  Future<void> _confirmar({
    required Uint8List informePdf,
    required Uint8List solicitudExcel,
    required String usuarioNombre,
    required RolUsuario rol,
  }) async {
    final ticket = state.ticket;
    if (ticket == null || !validarParaInforme()) return;
    // Lo último editado queda en el borrador (si la subida falla, no se pierde).
    await guardarBorradorAhora();
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
      fichas: state.fichas,
      necesitaCompras: state.necesitaCompras,
      motivoNoCompras: state.motivoNoCompras,
      usuarioNombre: usuarioNombre,
      rol: rol,
      urlInformePdf: urlPdf,
      urlSolicitudExcel: urlExcel,
    );
    final guardado = r.fold((_) => null, (t) => t);
    if (guardado == null) {
      emit(state.copyWith(
        envio: EnvioEvaluacionMantenimiento.error,
        mensaje: 'No se pudo guardar la evaluación: ${r.fold((f) => f.message, (_) => '')}',
      ));
      guardarBorradorAhora(); // conserva las fotos ya subidas (no se vuelven a subir)
      return;
    }
    // Evaluación enviada: el borrador ya no sirve. Se borra después del
    // guardado en curso, para que no reviva.
    _borradorActivo = false;
    _timerBorrador?.cancel();
    await _guardando;
    await eliminarBorrador(BorradorMantenimientoService.claveEvaluacion(ticket.id));
    if (isClosed) return;
    emit(state.copyWith(
      envio: EnvioEvaluacionMantenimiento.guardada,
      mensaje: 'Evaluación de ${ticket.id} guardada. ${_destino(guardado)}',
    ));
  }

  static String _destino(TicketEntity t) {
    final n = CreacionCodigosMantenimientoService.indicesPendientes(t).length;
    if (t.estadoActual == EstadoTicket.procesoTrabajo) return 'Sin repuestos: pasa directo a Proceso de Trabajo.';
    if (t.estadoActual == EstadoTicket.bodega) return 'Pasa directo a Despacho Bodega (picking).';
    if (n == 0) return 'Pasa a Compras.';
    if (CreacionCodigosMantenimientoService.esperaSoloCodigos(t)) return 'Pasa a Costos para crear $n código(s).';
    return 'Pasa a Compras; $n repuesto(s) sin código esperan en Costos.';
  }

  /// Sube un archivo; si falla deja el error a la vista y devuelve null.
  Future<String?> _subir(ArchivoAdjunto archivo, String ticketId, String carpeta) async {
    final r = await subirArchivo(archivo, ticketId, carpeta: carpeta);
    return r.fold((f) {
      emit(state.copyWith(
        envio: EnvioEvaluacionMantenimiento.error,
        mensaje: 'No se pudo subir "${archivo.nombre}": ${f.message}',
      ));
      guardarBorradorAhora(); // conserva las fotos ya subidas (no se vuelven a subir)
      return null;
    }, (u) => u);
  }
}
