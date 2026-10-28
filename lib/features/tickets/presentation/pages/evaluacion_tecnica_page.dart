import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:aquaspot_postventa/core/services/archivos_borrador_store.dart';
import 'package:aquaspot_postventa/core/services/borrador_storage_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_picker/file_picker.dart' as fp;
import 'package:image_picker/image_picker.dart';

import 'package:aquaspot_postventa/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:aquaspot_postventa/features/auth/presentation/bloc/auth_state.dart';
import 'package:aquaspot_postventa/features/tickets/presentation/bloc/ticket_state.dart';
import '../bloc/ticket_bloc.dart';
import '../bloc/ticket_event.dart';
import '../../../../core/enum/rol_usuario.dart';
import '../../../catalogo/domain/entities/item_catalogo_entity.dart';
import '../../domain/entities/ticket_entity.dart';
import '../../domain/entities/actividad_evaluacion_seleccionada.dart';
import '../../domain/services/borrador_evaluacion_codec.dart';
import '../../domain/services/flujo_reportes_automaticos_service.dart';
import '../../../catalogo/domain/services/codigo_actividad_service.dart';
import '../../../catalogo/presentation/widgets/editar_actividad_dialog.dart';
import '../widgets/copy_icon_button_widget.dart';
import '../widgets/tarjeta_no_requiere_compras_widget.dart';

// 🔌 INTEGRACIÓN CON CATÁLOGO Y GENERADORES AUTOMÁTICOS
import '../../../catalogo/domain/entities/actividad_catalogo_entity.dart';
import '../../../catalogo/presentation/bloc/catalogo_bloc.dart';
import '../../../catalogo/presentation/bloc/catalogo_event.dart';
import '../../../catalogo/presentation/bloc/catalogo_state.dart';
import '../services/generador_excel_evaluacion.dart';
import '../services/generador_pdf_evaluacion.dart';
import 'revision_evaluacion_tecnica_page.dart';

class EvaluacionTecnicaPage extends StatefulWidget {
  final TicketEntity ticket;
  const EvaluacionTecnicaPage({super.key, required this.ticket});

  @override
  State<EvaluacionTecnicaPage> createState() => _EvaluacionTecnicaPageState();
}

class _EvaluacionTecnicaPageState extends State<EvaluacionTecnicaPage> {
  // ⚙️ Memoria volátil base (Para equipos NO Caracol)
  fp.PlatformFile? _proformaExcel;
  final List<fp.PlatformFile> _adjuntosPdf = [];
  final TextEditingController _observacionController = TextEditingController();

  // ⚙️ Memoria volátil EXTENDIDA (Módulo de Garantías)
  fp.PlatformFile? _documentoOVGarantia;
  fp.PlatformFile? _documentoRevisionAntigua;

  // 🛑 Control de requerimiento de compras
  bool _necesitaCompras = true;
  final TextEditingController _motivoNoComprasController = TextEditingController();

  // 🧠 Sensores Lógicos de Estado
  // Evaluación con Plan Maestro e informe automático (antes solo Caracol;
  // ver FlujoReportesAutomaticosService).
  bool get _esCaracol => FlujoReportesAutomaticosService.paraEvaluacion(widget.ticket);

  bool get _esGarantiaServicio => widget.ticket.tipoGarantia == 'servicio';
  bool get _esGarantiaMaquina => widget.ticket.tipoGarantia == 'maquinaNueva';
  bool get _requiereCamposGarantia => _esGarantiaServicio || _esGarantiaMaquina;

  // ⚙️ Memoria volátil para CARACOL (Automatizado)
  final List<ActividadEvaluacionSeleccionada> _actividadesCaracol = [];
  // Actividad recién creada con "Agregar actividad al Plan Maestro": se
  // agrega sola a la evaluación cuando el catálogo se recarga.
  String? _codigoPorAgregar;

  /// Equipo del Plan Maestro de este ticket (caracol, cosechadora, contador).
  String get _equipoPlan => FlujoReportesAutomaticosService.equipoPlanMaestro(widget.ticket.equipo);
  final ImagePicker _imagePicker = ImagePicker();
  bool _generandoDocumentos = false;

  // 💾 BORRADOR LOCAL: todo se guarda solo (tras ~1 s sin cambios) y se
  // restaura al volver: actividades de Caracol (horas, hallazgo, repuestos
  // editados y FOTOS), compras y archivos. Los archivos van a IndexedDB en
  // web (ArchivosBorradorStore, sin el límite de ~5 MB) y en el celular
  // con la lógica de BorradorStorageService (base64 hasta 4 MB + ruta).
  static const Duration _pausaGuardado = Duration(seconds: 1);
  static const Duration _edadMaximaBorrador = Duration(days: 30);
  Timer? _timerGuardado;
  Future<void> _colaGuardado = Future.value();
  bool _borradorCargado = false; // no guardar antes de restaurar
  bool _borradorFinalizado = false; // enviado con éxito: no volver a guardar
  int _contadorArchivos = 0;
  // Referencia ya guardada de cada foto/archivo (por identidad del objeto),
  // para no volver a escribirlo en cada guardado.
  final Expando<Map<String, dynamic>> _refsArchivos = Expando('refsArchivosBorrador');

  String get _claveBorrador => BorradorStorageService.claveDraftEvaluacion(widget.ticket.id);
  String get _prefijoArchivos => 'evaluacion_${widget.ticket.id}/';
  bool get _necesitaComprasInicial => !widget.ticket.noRequiereCompras;
  String get _motivoInicial =>
      widget.ticket.noRequiereCompras ? (widget.ticket.motivoNoRequiereCompras ?? '') : '';

  @override
  void initState() {
    super.initState();
    if (widget.ticket.noRequiereCompras) {
      _necesitaCompras = false;
      if (widget.ticket.motivoNoRequiereCompras != null) {
        _motivoNoComprasController.text = widget.ticket.motivoNoRequiereCompras!;
      }
    }

    _observacionController.addListener(_guardarBorrador);
    _motivoNoComprasController.addListener(_guardarBorrador);
    _cargarBorradorLocal();
    _limpiarBorradoresAntiguos();

    if (_esCaracol) {
      context.read<CatalogoBloc>().add(CargarCatalogoPorEquipoEvent(_equipoPlan));
    }
  }

  /// Cualquier cambio de la pantalla programa el guardado del borrador.
  @override
  void setState(VoidCallback fn) {
    super.setState(fn);
    _guardarBorrador();
  }

  /// Programa el guardado (espera una pausa para no guardar en cada tecla).
  void _guardarBorrador() {
    if (!_borradorCargado || _borradorFinalizado) return;
    _timerGuardado?.cancel();
    _timerGuardado = Timer(_pausaGuardado, _encolarGuardado);
  }

  /// Toma una foto del estado AHORA (sincrónico) y la guarda en cola, un
  /// guardado a la vez.
  void _encolarGuardado() {
    if (_borradorFinalizado) return;
    final vacio = _actividadesCaracol.isEmpty &&
        _observacionController.text.trim().isEmpty &&
        _proformaExcel == null &&
        _adjuntosPdf.isEmpty &&
        _documentoOVGarantia == null &&
        _documentoRevisionAntigua == null &&
        _necesitaCompras == _necesitaComprasInicial &&
        _motivoNoComprasController.text.trim() == _motivoInicial.trim();
    final datos = <String, dynamic>{
      'version': 2,
      'observacion': _observacionController.text,
      'motivoNoCompras': _motivoNoComprasController.text,
      'necesitaCompras': _necesitaCompras,
    };
    final actividades = [
      for (final a in _actividadesCaracol) (BorradorEvaluacionCodec.actividadToJson(a), List<XFile>.from(a.fotos)),
    ];
    final proforma = _proformaExcel;
    final adjuntos = List<fp.PlatformFile>.from(_adjuntosPdf);
    final ov = _documentoOVGarantia;
    final revision = _documentoRevisionAntigua;

    _colaGuardado = _colaGuardado.then((_) async {
      if (_borradorFinalizado) return;
      if (vacio) {
        await BorradorStorageService.eliminarBorrador(_claveBorrador);
        await ArchivosBorradorStore.eliminarPrefijo(_prefijoArchivos);
        return;
      }
      final actividadesJson = <Map<String, dynamic>>[];
      for (final (json, fotos) in actividades) {
        final refs = <Map<String, dynamic>>[];
        for (final f in fotos) {
          final ref = await _refFoto(f);
          if (ref != null) refs.add(ref);
        }
        json['fotos'] = refs;
        actividadesJson.add(json);
      }
      final refsAdjuntos = <Map<String, dynamic>>[];
      for (final f in adjuntos) {
        final ref = await _refArchivo(f);
        if (ref != null) refsAdjuntos.add(ref);
      }
      datos['actividadesCaracol'] = actividadesJson;
      datos['adjuntosPdf'] = refsAdjuntos;
      datos['proformaExcel'] = proforma == null ? null : await _refArchivo(proforma);
      datos['documentoOV'] = ov == null ? null : await _refArchivo(ov);
      datos['documentoRevisionAntigua'] = revision == null ? null : await _refArchivo(revision);
      if (_borradorFinalizado) return;

      await BorradorStorageService.guardarBorrador(clave: _claveBorrador, datos: datos);

      if (ArchivosBorradorStore.disponible) {
        await ArchivosBorradorStore.marcarActividad(_prefijoArchivos);
        // Quitar del almacén las fotos/archivos que ya no están en el borrador.
        final usadas = <String>{
          for (final act in actividadesJson)
            for (final f in act['fotos'] as List) if ((f as Map)['idb'] is String) f['idb'] as String,
          for (final f in [...refsAdjuntos, datos['proformaExcel'], datos['documentoOV'], datos['documentoRevisionAntigua']])
            if (f is Map && f['idb'] is String) f['idb'] as String,
        };
        for (final clave in await ArchivosBorradorStore.listarClaves(_prefijoArchivos)) {
          if (!usadas.contains(clave)) await ArchivosBorradorStore.eliminar(clave);
        }
      }
    }).catchError((_) {});
  }

  Future<Map<String, dynamic>?> _guardarEnAlmacen(Uint8List bytes, String nombre) async {
    final clave = '$_prefijoArchivos${DateTime.now().microsecondsSinceEpoch}-${_contadorArchivos++}';
    if (!await ArchivosBorradorStore.guardar(clave, bytes)) return null;
    return {'name': nombre, 'size': bytes.length, 'idb': clave};
  }

  Future<Map<String, dynamic>?> _refFoto(XFile foto) async {
    final cache = _refsArchivos[foto];
    if (cache != null) return cache;
    Map<String, dynamic>? ref;
    if (ArchivosBorradorStore.disponible) {
      try {
        ref = await _guardarEnAlmacen(await foto.readAsBytes(), foto.name.isNotEmpty ? foto.name : 'foto.jpg');
      } catch (_) {}
    } else {
      ref = await BorradorStorageService.xFileToJson(foto);
    }
    if (ref != null) _refsArchivos[foto] = ref;
    return ref;
  }

  Future<Map<String, dynamic>?> _refArchivo(fp.PlatformFile archivo) async {
    final cache = _refsArchivos[archivo];
    if (cache != null) return cache;
    Map<String, dynamic>? ref;
    if (ArchivosBorradorStore.disponible) {
      final bytes = archivo.bytes;
      if (bytes != null) ref = await _guardarEnAlmacen(bytes, archivo.name);
    } else {
      ref = BorradorStorageService.platformFileToJson(archivo);
    }
    if (ref != null) _refsArchivos[archivo] = ref;
    return ref;
  }

  Future<XFile?> _fotoDesdeRef(Map<String, dynamic> ref) async {
    XFile? foto;
    final idb = ref['idb'] as String?;
    if (idb != null) {
      final bytes = await ArchivosBorradorStore.leer(idb);
      if (bytes != null) foto = XFile.fromData(bytes, name: ref['name'] as String? ?? 'foto.jpg', length: bytes.length);
    } else if (kIsWeb) {
      foto = BorradorStorageService.jsonToXFile(ref);
    } else {
      // Celular: la ruta original si sigue existiendo; si no, se recrea el
      // archivo desde el base64 (la miniatura de la foto lee la ruta).
      final path = ref['path'] as String?;
      final b64 = ref['base64'] as String?;
      if (path != null && path.isNotEmpty && File(path).existsSync()) {
        foto = XFile(path, name: ref['name'] as String?);
      } else if (b64 != null && b64.isNotEmpty) {
        try {
          final nombre = (ref['name'] as String? ?? 'foto.jpg').replaceAll(RegExp(r'[\\/]'), '_');
          final archivo = File('${Directory.systemTemp.path}${Platform.pathSeparator}'
              'borrador_${DateTime.now().microsecondsSinceEpoch}_$nombre');
          await archivo.writeAsBytes(base64Decode(b64));
          foto = XFile(archivo.path, name: ref['name'] as String?);
        } catch (_) {}
      }
    }
    if (foto != null) _refsArchivos[foto] = ref;
    return foto;
  }

  Future<fp.PlatformFile?> _archivoDesdeRef(dynamic json) async {
    if (json is! Map) return null;
    final ref = Map<String, dynamic>.from(json);
    fp.PlatformFile? archivo;
    final idb = ref['idb'] as String?;
    if (idb != null) {
      final bytes = await ArchivosBorradorStore.leer(idb);
      if (bytes != null) {
        archivo = fp.PlatformFile(name: ref['name'] as String? ?? 'archivo', size: bytes.length, bytes: bytes);
      }
    } else {
      archivo = BorradorStorageService.jsonToPlatformFile(ref);
    }
    if (archivo != null) _refsArchivos[archivo] = ref;
    return archivo;
  }

  Future<void> _cargarBorradorLocal() async {
    try {
      final draft = await BorradorStorageService.obtenerBorrador(_claveBorrador);
      if (draft == null || !mounted) return;

      // Se lee todo (incluidas las fotos) antes de pintar.
      var perdidos = 0;
      final actividades = <ActividadEvaluacionSeleccionada>[];
      for (final raw in (draft['actividadesCaracol'] as List<dynamic>? ?? const [])) {
        final act = BorradorEvaluacionCodec.actividadFromJson(raw);
        if (act == null) continue;
        for (final ref in BorradorEvaluacionCodec.fotosDeJson(raw)) {
          final foto = await _fotoDesdeRef(ref);
          if (foto != null) {
            act.fotos.add(foto);
          } else {
            perdidos++;
          }
        }
        actividades.add(act);
      }

      Future<fp.PlatformFile?> archivo(String clave, String claveRutaAntigua) async {
        if (draft.containsKey(clave)) {
          if (draft[clave] == null) return null;
          final a = await _archivoDesdeRef(draft[clave]);
          if (a == null) perdidos++;
          return a;
        }
        return BorradorStorageService.pathToPlatformFile(draft[claveRutaAntigua] as String?);
      }

      final proforma = await archivo('proformaExcel', 'proformaExcelPath');
      final ov = await archivo('documentoOV', 'documentoOVPath');
      final revision = await archivo('documentoRevisionAntigua', 'documentoRevisionAntiguaPath');
      final adjuntos = <fp.PlatformFile>[];
      if (draft['adjuntosPdf'] is List) {
        for (final ref in draft['adjuntosPdf'] as List) {
          final a = await _archivoDesdeRef(ref);
          if (a != null) {
            adjuntos.add(a);
          } else {
            perdidos++;
          }
        }
      } else if (draft['adjuntosPdfPaths'] is List) {
        adjuntos.addAll(BorradorStorageService.pathsToPlatformFiles(draft['adjuntosPdfPaths'] as List));
      }
      if (!mounted) return;

      super.setState(() {
        if (draft['observacion'] != null && (draft['observacion'] as String).isNotEmpty) {
          _observacionController.text = draft['observacion'] as String;
        }
        if (draft['motivoNoCompras'] != null && (draft['motivoNoCompras'] as String).isNotEmpty) {
          _motivoNoComprasController.text = draft['motivoNoCompras'] as String;
        }
        if (draft['necesitaCompras'] != null) {
          _necesitaCompras = draft['necesitaCompras'] as bool;
        }
        if (draft.containsKey('actividadesCaracol')) {
          _actividadesCaracol
            ..clear()
            ..addAll(actividades);
        }
        _proformaExcel = proforma;
        _documentoOVGarantia = ov;
        _documentoRevisionAntigua = revision;
        _adjuntosPdf
          ..clear()
          ..addAll(adjuntos);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(perdidos == 0
              ? '💾 Borrador de evaluación restaurado del almacenamiento local.'
              : '💾 Borrador de evaluación restaurado. ⚠️ $perdidos foto(s)/archivo(s) no se pudieron recuperar.'),
          backgroundColor: const Color(0xFF005A9C),
          duration: Duration(seconds: perdidos == 0 ? 3 : 6),
        ),
      );
    } catch (_) {
      // Un borrador dañado no debe impedir trabajar.
    } finally {
      _borradorCargado = true;
    }
  }

  /// Borra los borradores de evaluación sin tocar hace más de 30 días
  /// (de otros tickets; nunca el que está abierto).
  Future<void> _limpiarBorradoresAntiguos() async {
    try {
      await ArchivosBorradorStore.solicitarPersistencia();
      final prefijoClave = BorradorStorageService.claveDraftEvaluacion('');
      final prefs = await SharedPreferences.getInstance();

      final prefijosWeb = await ArchivosBorradorStore.limpiarAntiguos(
        _edadMaximaBorrador,
        excluirPrefijo: _prefijoArchivos,
      );
      for (final p in prefijosWeb) {
        if (p.startsWith('evaluacion_') && p.endsWith('/')) {
          await prefs.remove('$prefijoClave${p.substring('evaluacion_'.length, p.length - 1)}');
        }
      }

      final limite = DateTime.now().subtract(_edadMaximaBorrador);
      for (final clave in prefs.getKeys().where((k) => k.startsWith(prefijoClave)).toList()) {
        if (clave == _claveBorrador) continue;
        DateTime? fecha;
        try {
          final json = jsonDecode(prefs.getString(clave) ?? '');
          if (json is Map) fecha = DateTime.tryParse(json['timestampUltimaModificacion'] as String? ?? '');
        } catch (_) {}
        if (fecha != null && fecha.isBefore(limite)) {
          await prefs.remove(clave);
          await ArchivosBorradorStore.eliminarPrefijo('evaluacion_${clave.substring(prefijoClave.length)}/');
        }
      }
    } catch (_) {}
  }

  /// Evaluación enviada con éxito: se borra el borrador y sus archivos.
  void _finalizarBorrador() {
    _borradorFinalizado = true;
    _timerGuardado?.cancel();
    _colaGuardado.whenComplete(() {
      BorradorStorageService.eliminarBorrador(_claveBorrador);
      ArchivosBorradorStore.eliminarPrefijo(_prefijoArchivos);
    });
  }

  Future<void> _confirmarDescartarBorrador() async {
    final bool? confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.delete_sweep, color: Colors.red),
            SizedBox(width: 8),
            Text('Descartar Borrador'),
          ],
        ),
        content: const Text(
          '¿Desea eliminar el borrador de esta evaluación guardado en este dispositivo? '
          'Se quitarán las actividades, fotos, repuestos editados, observaciones y archivos.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Descartar'),
          ),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;

    _timerGuardado?.cancel();
    await _colaGuardado;
    await BorradorStorageService.eliminarBorrador(_claveBorrador);
    await ArchivosBorradorStore.eliminarPrefijo(_prefijoArchivos);
    if (!mounted) return;

    _borradorCargado = false; // que el reinicio no vuelva a guardar
    super.setState(() {
      _actividadesCaracol.clear();
      _adjuntosPdf.clear();
      _proformaExcel = null;
      _documentoOVGarantia = null;
      _documentoRevisionAntigua = null;
      _necesitaCompras = _necesitaComprasInicial;
    });
    _observacionController.clear();
    _motivoNoComprasController.text = _motivoInicial;
    _borradorCargado = true;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('🗑️ Borrador de evaluación descartado.')),
    );
  }

  @override
  void dispose() {
    // Si quedó un guardado pendiente (se salió antes de la pausa), se hace ya.
    if (_timerGuardado?.isActive ?? false) {
      _timerGuardado!.cancel();
      _encolarGuardado();
    }
    _observacionController.removeListener(_guardarBorrador);
    _motivoNoComprasController.removeListener(_guardarBorrador);
    _observacionController.dispose();
    _motivoNoComprasController.dispose();
    super.dispose();
  }

  // 🛡️ ENCLAVAMIENTO DE SEGURIDAD RECALIBRADO
  bool _isFormularioValido(bool isProcesando) {
    if (isProcesando || _generandoDocumentos) return false;

    // Si es garantía, el circuito exige estrictamente el documento de la OV
    if (_requiereCamposGarantia) {
      if (_documentoOVGarantia == null) return false;
      if (_esGarantiaServicio && _documentoRevisionAntigua == null) return false;
    }

    if (_esCaracol) {
      if (_actividadesCaracol.isEmpty) return false;
      for (final a in _actividadesCaracol) {
        if (a.observacion.trim().isEmpty) return false;
        if (a.horasHombre <= 0) return false;
      }
      return true;
    } else {
      return _observacionController.text.trim().isNotEmpty ||
          _proformaExcel != null ||
          _adjuntosPdf.isNotEmpty;
    }
  }

  // ==========================================
  // VÁLVULAS TRADICIONALES (Equipos no caracol)
  // ==========================================
  Future<void> _seleccionarExcelCosteo() async {
    fp.FilePickerResult? result = await fp.FilePicker.pickFiles(
      allowMultiple: false,
      type: fp.FileType.custom,
      allowedExtensions: ['xls', 'xlsx'],
      withData: true,
    );
    if (result != null) {
      setState(() => _proformaExcel = result.files.first);
      _guardarBorrador();
    }
  }

  Future<void> _seleccionarAdjuntosPdf() async {
    fp.FilePickerResult? result = await fp.FilePicker.pickFiles(
      allowMultiple: true,
      type: fp.FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true,
    );
    if (result != null) {
      setState(() => _adjuntosPdf.addAll(result.files));
      _guardarBorrador();
    }
  }

  Future<void> _seleccionarDocumentoOV() async {
    fp.FilePickerResult? result = await fp.FilePicker.pickFiles(
      allowMultiple: false,
      type: fp.FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true,
    );
    if (result != null) {
      setState(() => _documentoOVGarantia = result.files.first);
      _guardarBorrador();
    }
  }

  Future<void> _seleccionarDocumentoRevisionAntigua() async {
    fp.FilePickerResult? result = await fp.FilePicker.pickFiles(
      allowMultiple: false,
      type: fp.FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true,
    );
    if (result != null) {
      setState(() => _documentoRevisionAntigua = result.files.first);
      _guardarBorrador();
    }
  }

  // ==========================================
  // ⚙️ GESTIÓN DE ACTIVIDADES (CARACOL)
  // ==========================================
  void _mostrarSelectorActividades(List<ActividadCatalogoEntity> catalogo) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        String filtro = '';
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filtradas = catalogo.where((a) {
              final f = filtro.toLowerCase();
              return a.codigo.toLowerCase().contains(f) ||
                  a.nombre.toLowerCase().contains(f) ||
                  a.incluye.toLowerCase().contains(f);
            }).toList();

            return DraggableScrollableSheet(
              initialChildSize: 0.7,
              maxChildSize: 0.9,
              minChildSize: 0.4,
              expand: false,
              builder: (_, scrollController) {
                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(2)),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Seleccionar Actividad (Plan Maestro ${widget.ticket.equipo.name})',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF005A9C)),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        onChanged: (val) => setModalState(() => filtro = val),
                        decoration: InputDecoration(
                          hintText: 'Buscar por código o nombre de actividad...',
                          prefixIcon: const Icon(Icons.search),
                          isDense: true,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: filtradas.isEmpty
                            ? const Center(child: Text('No hay actividades coincidentes.'))
                            : ListView.builder(
                                controller: scrollController,
                                itemCount: filtradas.length,
                                itemBuilder: (context, index) {
                                  final act = filtradas[index];
                                  final yaAgregada = _actividadesCaracol.any((el) => el.actividad.codigo == act.codigo);

                                  return Card(
                                    color: yaAgregada ? Colors.grey.shade100 : Colors.white,
                                    margin: const EdgeInsets.only(bottom: 8),
                                    child: ListTile(
                                      leading: CircleAvatar(
                                        backgroundColor: yaAgregada ? Colors.grey : const Color(0xFF005A9C),
                                        child: Text(
                                          act.codigo.replaceAll('MO', ''),
                                          style: const TextStyle(color: Colors.white, fontSize: 12),
                                        ),
                                      ),
                                      title: Text(
                                        '${act.codigo} - ${act.nombre}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: yaAgregada ? Colors.grey : Colors.black87,
                                        ),
                                      ),
                                      subtitle: Text(
                                        act.esVariable ? 'HH Variable (A definir)' : '${act.horasHombre} HH',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: act.esVariable ? Colors.orange.shade800 : Colors.blue.shade800,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      trailing: yaAgregada
                                          ? const Icon(Icons.check, color: Colors.green)
                                          : const Icon(Icons.add_circle, color: Color(0xFF005A9C)),
                                      onTap: yaAgregada
                                          ? null
                                          : () {
                                              setState(() {
                                                _actividadesCaracol.add(
                                                  ActividadEvaluacionSeleccionada(
                                                    actividad: act,
                                                    horasHombre: act.horasHombre ?? 0.0,
                                                    observacion: '',
                                                  ),
                                                );
                                              });
                                              Navigator.pop(ctx);
                                            },
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _agregarFoto(int indexActividad, ImageSource source) async {
    try {
      if (source == ImageSource.gallery) {
        final List<XFile> fotos = await _imagePicker.pickMultiImage(imageQuality: 85);
        if (fotos.isNotEmpty) {
          setState(() {
            _actividadesCaracol[indexActividad].fotos.addAll(fotos);
          });
        }
      } else {
        final XFile? foto = await _imagePicker.pickImage(source: ImageSource.camera, imageQuality: 85);
        if (foto != null) {
          setState(() {
            _actividadesCaracol[indexActividad].fotos.add(foto);
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al capturar imagen: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ==========================================
  // ⚡ GENERACIÓN AUTOMÁTICA Y NAVEGACIÓN A REVISIÓN
  // ==========================================
  Future<void> _generarYRevisarInforme() async {
    if (!_isFormularioValido(false)) return;

    setState(() => _generandoDocumentos = true);

    try {
      final authState = context.read<AuthBloc>().state;
      String nombreOperador = 'TECNICO_SERVICIO';
      if (authState is Authenticated) {
        nombreOperador = authState.usuario.nombre;
      }

      // 1. Generar Excel consolidado en memoria
      final Uint8List excelBytes = GeneradorExcelEvaluacion.generarExcel(
        ticket: widget.ticket,
        actividadesSeleccionadas: _actividadesCaracol,
      );

      // 2. Generar PDF institucional en memoria
      final Uint8List pdfBytes = await GeneradorPdfEvaluacion.generarPdf(
        ticket: widget.ticket,
        actividadesSeleccionadas: _actividadesCaracol,
        nombreTecnico: nombreOperador,
      );

      setState(() => _generandoDocumentos = false);

      if (!mounted) return;

      // 3. Abrir Pantalla de Revisión Previa
      final result = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => RevisionEvaluacionTecnicaPage(
            ticket: widget.ticket,
            actividadesSeleccionadas: _actividadesCaracol,
            excelBytes: excelBytes,
            pdfBytes: pdfBytes,
            noRequiereCompras: !_necesitaCompras,
            motivoNoRequiereCompras: !_necesitaCompras ? _motivoNoComprasController.text.trim() : null,
            documentoOVGarantia: _documentoOVGarantia,
            documentoRevisionAntigua: _documentoRevisionAntigua,
          ),
        ),
      );

      // Si el usuario confirmó y subió en la pantalla de revisión, cerramos esta vista
      if (result == true && mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() => _generandoDocumentos = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al generar informe: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ==========================================
  // ⚡ ACTUADOR TRADICIONAL (No Caracol)
  // ==========================================
  void _enviarReporteTradicional() {
    if (!_isFormularioValido(false)) return;

    final authState = context.read<AuthBloc>().state;
    String operador = 'DESCONOCIDO';
    String rol = 'SIN_ROL';

    if (authState is Authenticated) {
      operador = authState.usuario.nombre;
      rol = authState.usuario.rol.name.toUpperCase();
    }

    context.read<TicketBloc>().add(
      ProcesarEvaluacionDocumentalEvent(
        ticket: widget.ticket,
        proformaExcel: _proformaExcel,
        documentosPdf: _adjuntosPdf,
        observacion: _observacionController.text.trim(),
        nombreUsuario: operador,
        rolUsuario: rol,
        numeroOVGarantia: null,
        documentosPdfGarantia: _documentoOVGarantia != null ? [_documentoOVGarantia!] : null,
        documentoRevisionAntigua: _documentoRevisionAntigua,
        noRequiereCompras: !_necesitaCompras,
        motivoNoRequiereCompras: !_necesitaCompras ? _motivoNoComprasController.text.trim() : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Evaluación Técnica: ${widget.ticket.id}"),
        backgroundColor: const Color(0xFF005A9C),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            tooltip: 'Descartar Borrador',
            onPressed: _generandoDocumentos ? null : _confirmarDescartarBorrador,
          ),
        ],
      ),
      body: BlocConsumer<TicketBloc, TicketState>(
        listener: (context, state) {
          if (state.status == TicketStatus.operationSuccess) {
            _finalizarBorrador();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("✅ Evaluación técnica procesada con éxito"), backgroundColor: Colors.green),
            );
            Navigator.of(context).pop();
          } else if (state.status == TicketStatus.error) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message), backgroundColor: Colors.red),
            );
          }
        },
        builder: (context, state) {
          final isProcesando = state.status == TicketStatus.loading;
          final formValido = _isFormularioValido(isProcesando);

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 850),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ALERTA NO REQUIERE COMPRAS SI YA ESTÁ DECLARADA
                      TarjetaNoRequiereComprasWidget(ticket: widget.ticket),

                      // FICHA TÉCNICA DEL EQUIPO
                      Card(
                        elevation: 1.5,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Ficha Técnica del Requerimiento", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              const Divider(height: 24),
                              _buildInfoRow(context, 'Equipo:', widget.ticket.equipo.name.toUpperCase()),
                              _buildInfoRow(context, 'Lugar de recepción:', widget.ticket.lugarAtencion.name.toUpperCase()),
                              const Divider(height: 24),
                              _buildInfoRow(context, 'Cliente:', widget.ticket.clienteId.toUpperCase()),
                              _buildInfoRow(context, 'Campamento:', widget.ticket.campamento.toUpperCase()),
                              _buildInfoRow(context, 'Contacto:', '${widget.ticket.nombreContacto} (${widget.ticket.telefonoContacto})'),
                              const Divider(height: 24),
                              _buildInfoRow(context, 'Número de Serie:', widget.ticket.numeroSerie ?? 'No especificado'),
                              const Divider(height: 24),
                              Row(
                                children: [
                                  const Expanded(child: Text('Falla Reportada e Inspección:', style: TextStyle(fontSize: 13, color: Colors.grey))),
                                  CopyIconButtonWidget(etiqueta: 'Falla Reportada', valor: widget.ticket.fallaReportada),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(widget.ticket.fallaReportada, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // REQUISITOS DE GARANTÍA
                      if (_requiereCamposGarantia) ...[
                        _buildModuloGarantia(isProcesando),
                        const SizedBox(height: 24),
                      ],

                      // =======================================================
                      // 🔄 FLUJO CONDICIONAL: CARACOL AUTOMATIZADO VS TRADICIONAL
                      // =======================================================
                      if (_esCaracol)
                        _buildSeccionCaracolAutomatizado(isProcesando)
                      else
                        _buildSeccionTradicional(isProcesando),

                      const SizedBox(height: 24),

                      // ==========================================
                      // 🛒 CHECK: ¿NECESITA COMPRAS O NO?
                      // ==========================================
                      Card(
                        elevation: 1,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(
                            color: !_necesitaCompras ? Colors.orange.shade800 : Colors.grey.shade300,
                            width: !_necesitaCompras ? 2 : 1,
                          ),
                        ),
                        color: !_necesitaCompras ? const Color(0xFFFFF3E0) : Colors.white,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CheckboxListTile(
                                value: _necesitaCompras,
                                activeColor: const Color(0xFF005A9C),
                                contentPadding: EdgeInsets.zero,
                                title: Row(
                                  children: [
                                    Icon(
                                      _necesitaCompras ? Icons.shopping_cart : Icons.remove_shopping_cart,
                                      color: _necesitaCompras ? const Color(0xFF005A9C) : Colors.orange.shade900,
                                      size: 22,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '¿Necesita compras?',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: !_necesitaCompras ? Colors.orange.shade900 : Colors.black87,
                                      ),
                                    ),
                                  ],
                                ),
                                subtitle: Text(
                                  _necesitaCompras
                                      ? 'Marcado: Sí, este requerimiento necesita compras de repuestos o insumos.'
                                      : 'Desmarcado: NO necesita compras (se alertará al flujo en naranja).',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: _necesitaCompras ? Colors.grey.shade700 : Colors.orange.shade900,
                                    fontWeight: _necesitaCompras ? FontWeight.normal : FontWeight.bold,
                                  ),
                                ),
                                onChanged: isProcesando || _generandoDocumentos
                                    ? null
                                    : (bool? val) {
                                        setState(() => _necesitaCompras = val ?? true);
                                        _guardarBorrador();
                                      },
                              ),
                              if (!_necesitaCompras) ...[
                                const Divider(height: 16),
                                TextField(
                                  controller: _motivoNoComprasController,
                                  enabled: !isProcesando && !_generandoDocumentos,
                                  decoration: InputDecoration(
                                    labelText: 'Motivo por el cual NO requiere compras (Opcional)',
                                    hintText: 'Ej. Stock en taller, solo mantenimiento de mano de obra...',
                                    isDense: true,
                                    filled: true,
                                    fillColor: Colors.white,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                    prefixIcon: const Icon(Icons.info_outline, size: 20),
                                  ),
                                ),
                                const SizedBox(height: 4),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // ==========================================
                      // ⚡ ACTUADOR FINAL
                      // ==========================================
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF005A9C),
                            disabledBackgroundColor: Colors.grey.shade400,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                          ),
                          onPressed: formValido ? (_esCaracol ? _generarYRevisarInforme : _enviarReporteTradicional) : null,
                          child: (isProcesando || _generandoDocumentos)
                              ? Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)),
                                    const SizedBox(width: 12),
                                    Text(
                                      _generandoDocumentos ? "GENERANDO INFORME Y EXCEL..." : "TRANSMITIENDO...",
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                                    ),
                                  ],
                                )
                              : Text(
                                  _esCaracol ? "GENERAR Y REVISAR INFORME TÉCNICO" : "ENVIAR REPORTE TÉCNICO",
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ==========================================
  // WIDGET: SECCIÓN DINÁMICA CARACOL
  // ==========================================
  /// Ventana emergente para crear una actividad (con sus repuestos) en el
  /// Plan Maestro del equipo sin salir de la evaluación; al guardarse se
  /// agrega sola a esta evaluación.
  Future<void> _agregarActividadAlPlanMaestro(List<ActividadCatalogoEntity> catalogo) {
    final bloc = context.read<CatalogoBloc>();
    return EditarActividadDialog.mostrar(
      context,
      equipo: _equipoPlan,
      codigoSugerido: CodigoActividadService.siguiente(catalogo),
      codigosOcupados: CodigoActividadService.ocupados(catalogo),
      onGuardar: (nueva) {
        _codigoPorAgregar = nueva.codigo.trim().toUpperCase();
        bloc.add(GuardarActividadEvent(nueva));
      },
    );
  }

  Widget _buildSeccionCaracolAutomatizado(bool isProcesando) {
    return BlocConsumer<CatalogoBloc, CatalogoState>(
      listener: (context, state) {
        final codigo = _codigoPorAgregar;
        if (codigo == null) return;
        if (state is CatalogoError) {
          _codigoPorAgregar = null;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('No se pudo guardar la actividad: ${state.mensaje}'), backgroundColor: Colors.red),
          );
          // Sin catálogo no se pueden elegir actividades ni sugerir códigos.
          context.read<CatalogoBloc>().add(CargarCatalogoPorEquipoEvent(_equipoPlan));
        } else if (state is CatalogoLoaded && state.equipo == _equipoPlan) {
          _codigoPorAgregar = null;
          final act = state.actividades.where((a) => a.codigo.trim().toUpperCase() == codigo).firstOrNull;
          if (act == null || _actividadesCaracol.any((a) => a.actividad.codigo == act.codigo)) return;
          setState(() => _actividadesCaracol.add(
                ActividadEvaluacionSeleccionada(actividad: act, horasHombre: act.horasHombre ?? 0.0, observacion: ''),
              ));
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('✅ ${act.codigo} agregada al Plan Maestro y a esta evaluación.'), backgroundColor: Colors.green),
          );
        }
      },
      builder: (context, state) {
        List<ActividadCatalogoEntity> catalogo = [];
        if (state is CatalogoLoaded && state.equipo == _equipoPlan) {
          catalogo = state.actividades;
        }

        final authState = context.read<AuthBloc>().state;
        bool esSupervisorOAdmin = false;
        if (authState is Authenticated) {
          esSupervisorOAdmin = authState.usuario.rol == RolUsuario.supervisor ||
              authState.usuario.rol == RolUsuario.admin;
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Plan Maestro de Reparación (${widget.ticket.equipo.name})",
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF005A9C)),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        "Seleccione las actividades a realizar. Los repuestos y el informe se generarán automáticamente.",
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: isProcesando || _generandoDocumentos ? null : () => _mostrarSelectorActividades(catalogo),
                  icon: const Icon(Icons.add_task),
                  label: const Text("AGREGAR ACTIVIDAD"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF005A9C),
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            // ➕ Actividad que no está en el Plan Maestro: se crea aquí mismo
            // (ventana emergente) y queda guardada en el plan del equipo.
            if (esSupervisorOAdmin)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  // Solo con el catálogo del equipo cargado: así el código
                  // sugerido nunca pisa una actividad existente.
                  onPressed: isProcesando || _generandoDocumentos || !(state is CatalogoLoaded && state.equipo == _equipoPlan)
                      ? null
                      : () => _agregarActividadAlPlanMaestro(catalogo),
                  icon: const Icon(Icons.playlist_add),
                  label: const Text('¿No está? Agregar actividad al Plan Maestro'),
                ),
              ),
            const SizedBox(height: 16),

            if (_actividadesCaracol.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.blueGrey.shade50,
                  border: Border.all(color: Colors.blueGrey.shade200, style: BorderStyle.solid),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Icon(Icons.assignment_add, size: 48, color: Colors.blueGrey.shade400),
                    const SizedBox(height: 12),
                    const Text(
                      'No ha seleccionado actividades de reparación.',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Pulse "AGREGAR ACTIVIDAD" para seleccionar los trabajos y registrar hallazgos con evidencia fotográfica.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _actividadesCaracol.length,
                itemBuilder: (context, index) {
                  final actSel = _actividadesCaracol[index];
                  return Card(
                    elevation: 2,
                    margin: const EdgeInsets.only(bottom: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(color: Colors.blueGrey.shade200),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: const Color(0xFF005A9C),
                                foregroundColor: Colors.white,
                                child: Text('${index + 1}'),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${actSel.actividad.codigo} - ${actSel.actividad.nombre}',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                    ),
                                    if (actSel.textoIncluyeDinamico.isNotEmpty)
                                      Text(
                                        actSel.textoIncluyeDinamico,
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.blueGrey),
                                      ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                tooltip: 'Eliminar actividad',
                                onPressed: isProcesando || _generandoDocumentos
                                    ? null
                                    : () => setState(() => _actividadesCaracol.removeAt(index)),
                              ),
                            ],
                          ),
                          const Divider(height: 20),

                          // HORAS HOMBRE (Editable por Supervisor o si es variable)
                          if (esSupervisorOAdmin || actSel.actividad.esVariable) ...[
                            Row(
                              children: [
                                Icon(Icons.schedule, size: 18, color: actSel.actividad.esVariable ? Colors.orange : const Color(0xFF005A9C)),
                                const SizedBox(width: 6),
                                Text(
                                  actSel.actividad.esVariable ? 'Horas Hombre (Variable): ' : 'Horas Hombre: ',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                                const SizedBox(width: 8),
                                SizedBox(
                                  width: 90,
                                  child: TextFormField(
                                    initialValue: actSel.horasHombre > 0
                                        ? (actSel.horasHombre % 1 == 0 ? actSel.horasHombre.toInt().toString() : actSel.horasHombre.toString())
                                        : '',
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    decoration: const InputDecoration(
                                      isDense: true,
                                      hintText: 'HH',
                                      border: OutlineInputBorder(),
                                    ),
                                    onChanged: (val) {
                                      final hh = double.tryParse(val.trim().replaceAll(',', '.')) ?? 0.0;
                                      actSel.horasHombre = hh;
                                      setState(() {});
                                    },
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Text('HH', style: TextStyle(fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const SizedBox(height: 12),
                          ] else ...[
                            Row(
                              children: [
                                const Icon(Icons.schedule, size: 18, color: Colors.blue),
                                const SizedBox(width: 6),
                                Text(
                                  'Horas Hombre fijas: ${actSel.horasHombre} HH',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF005A9C)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                          ],

                          // HALLAZGO / OBSERVACIÓN TÉCNICA
                          TextFormField(
                            initialValue: actSel.observacion,
                            maxLines: 3,
                            enabled: !isProcesando && !_generandoDocumentos,
                            onChanged: (val) {
                              actSel.observacion = val;
                              setState(() {});
                            },
                            decoration: InputDecoration(
                              labelText: 'Hallazgo / Diagnóstico Técnico para el Informe *',
                              hintText: 'Ej. El impulsor presenta una cavidad con contaminación en el aluminio...',
                              isDense: true,
                              border: const OutlineInputBorder(),
                              prefixIcon: const Icon(Icons.find_in_page),
                              errorText: actSel.observacion.trim().isEmpty ? 'La observación de este hallazgo es obligatoria' : null,
                            ),
                          ),
                          const SizedBox(height: 14),

                          // EVIDENCIA FOTOGRÁFICA DE LA ACTIVIDAD
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Fotografías de Hallazgo (${actSel.fotos.length})',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              Row(
                                children: [
                                  IconButton.filledTonal(
                                    icon: const Icon(Icons.camera_alt, size: 18),
                                    tooltip: 'Tomar foto con cámara',
                                    onPressed: isProcesando || _generandoDocumentos ? null : () => _agregarFoto(index, ImageSource.camera),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton.filledTonal(
                                    icon: const Icon(Icons.photo_library, size: 18),
                                    tooltip: 'Seleccionar de galería',
                                    onPressed: isProcesando || _generandoDocumentos ? null : () => _agregarFoto(index, ImageSource.gallery),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          if (actSel.fotos.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            SizedBox(
                              height: 90,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: actSel.fotos.length,
                                itemBuilder: (context, fotoIdx) {
                                  final foto = actSel.fotos[fotoIdx];
                                  return Stack(
                                    children: [
                                      Container(
                                        margin: const EdgeInsets.only(right: 10),
                                        width: 90,
                                        height: 90,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: Colors.grey.shade300),
                                          image: DecorationImage(
                                            image: ResizeImage(
                                              FileImage(File(foto.path)),
                                              width: 200,
                                              height: 200,
                                            ),
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        top: 2,
                                        right: 12,
                                        child: CircleAvatar(
                                          radius: 12,
                                          backgroundColor: Colors.red.withValues(alpha: 0.85),
                                          child: IconButton(
                                            padding: EdgeInsets.zero,
                                            icon: const Icon(Icons.close, size: 14, color: Colors.white),
                                            onPressed: () {
                                              setState(() {
                                                actSel.fotos.removeAt(fotoIdx);
                                              });
                                            },
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                          ],

                          const Divider(height: 20),
                          // 📦 GESTIÓN DE REPUESTOS E INSUMOS (Editable por Supervisor)
                          _buildSeccionRepuestosActividad(actSel, esSupervisorOAdmin, isProcesando),
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        );
      },
    );
  }

  // ==========================================
  // WIDGET: SECCIÓN TRADICIONAL (No Caracol)
  // ==========================================
  Widget _buildSeccionTradicional(bool isProcesando) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Documentación Técnica (Manual)", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        const Text("Proforma de Costos (Excel)", style: TextStyle(fontWeight: FontWeight.w600, color: Colors.blueGrey)),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          icon: const Icon(Icons.table_view, color: Colors.green),
          label: const Text("ADJUNTAR EXCEL (.xls, .xlsx)"),
          onPressed: isProcesando ? null : _seleccionarExcelCosteo,
          style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
        ),
        if (_proformaExcel != null) ...[
          const SizedBox(height: 8),
          Card(
            color: Colors.green.shade50,
            child: ListTile(
              leading: const Icon(Icons.check_circle, color: Colors.green),
              title: Text(_proformaExcel!.name, maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: isProcesando ? null : () => setState(() => _proformaExcel = null),
              ),
            ),
          ),
        ],
        const SizedBox(height: 24),
        const Text("Evidencia Documental (PDF)", style: TextStyle(fontWeight: FontWeight.w600, color: Colors.blueGrey)),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          icon: const Icon(Icons.picture_as_pdf, color: Colors.redAccent),
          label: const Text("ADJUNTAR PDFs"),
          onPressed: isProcesando ? null : _seleccionarAdjuntosPdf,
          style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
        ),
        if (_adjuntosPdf.isNotEmpty) ...[
          const SizedBox(height: 8),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _adjuntosPdf.length,
            itemBuilder: (context, index) {
              final file = _adjuntosPdf[index];
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.picture_as_pdf, color: Colors.blueGrey),
                  title: Text(file.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: isProcesando ? null : () => setState(() => _adjuntosPdf.removeAt(index)),
                  ),
                ),
              );
            },
          ),
        ],
        const SizedBox(height: 24),
        TextField(
          controller: _observacionController,
          maxLines: 4,
          enabled: !isProcesando,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            labelText: 'Observación Técnica (Opcional)',
            hintText: 'Ingrese detalles adicionales...',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.engineering),
          ),
        ),
      ],
    );
  }

  // ==========================================
  // WIDGET: SECCIÓN DE REPUESTOS E INSUMOS POR ACTIVIDAD
  // ==========================================
  Widget _buildSeccionRepuestosActividad(
    ActividadEvaluacionSeleccionada actSel,
    bool esSupervisorOAdmin,
    bool isProcesando,
  ) {
    final totalItems = actSel.itemsInternos.length + actSel.itemsComerciales.length;

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        title: Row(
          children: [
            const Icon(Icons.handyman_outlined, size: 18, color: Color(0xFF005A9C)),
            const SizedBox(width: 8),
            Text(
              'Repuestos e Insumos ($totalItems)',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF005A9C)),
            ),
            const Spacer(),
            if (esSupervisorOAdmin)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.green.shade300),
                ),
                child: const Text('Modo Edición (Supervisor)', style: TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.bold)),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: const Text('Solo Lectura', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
              ),
          ],
        ),
        children: [
          if (actSel.itemsInternos.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('🔧 Taller / Bodega (Materiales Internos):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black87)),
              ),
            ),
            ...actSel.itemsInternos.asMap().entries.map((entry) {
              final idx = entry.key;
              final item = entry.value;
              return _buildFilaRepuestoEditable(
                item: item,
                esSupervisorOAdmin: esSupervisorOAdmin,
                isProcesando: isProcesando,
                onCantidadChanged: (nuevaCant) {
                  setState(() {
                    actSel.itemsInternos[idx] = item.copyWith(cantidad: nuevaCant);
                    // 🔄 Sincronizar automáticamente con itemsComerciales si existe
                    final cod = item.codigo.trim().toUpperCase();
                    final desc = item.descripcion.trim().toUpperCase();
                    final cIdx = actSel.itemsComerciales.indexWhere(
                      (c) => (cod.isNotEmpty && c.codigo.trim().toUpperCase() == cod) ||
                             (c.descripcion.trim().toUpperCase() == desc),
                    );
                    if (cIdx != -1) {
                      actSel.itemsComerciales[cIdx] = actSel.itemsComerciales[cIdx].copyWith(cantidad: nuevaCant);
                    }
                  });
                },
                onEliminar: () {
                  setState(() {
                    actSel.itemsInternos.removeAt(idx);
                    // 🔄 Si también está en itemsComerciales, removerlo
                    final cod = item.codigo.trim().toUpperCase();
                    final desc = item.descripcion.trim().toUpperCase();
                    actSel.itemsComerciales.removeWhere(
                      (c) => (cod.isNotEmpty && c.codigo.trim().toUpperCase() == cod) ||
                             (c.descripcion.trim().toUpperCase() == desc),
                    );
                  });
                },
              );
            }),
          ],
          if (actSel.itemsComerciales.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('💼 Cotización Comercial (Propuesta Cliente):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black87)),
              ),
            ),
            ...actSel.itemsComerciales.asMap().entries.map((entry) {
              final idx = entry.key;
              final item = entry.value;
              return _buildFilaRepuestoEditable(
                item: item,
                esSupervisorOAdmin: esSupervisorOAdmin,
                isProcesando: isProcesando,
                onCantidadChanged: (nuevaCant) {
                  setState(() {
                    actSel.itemsComerciales[idx] = item.copyWith(cantidad: nuevaCant);
                    // 🔄 Sincronizar automáticamente con itemsInternos si existe
                    final cod = item.codigo.trim().toUpperCase();
                    final desc = item.descripcion.trim().toUpperCase();
                    final iIdx = actSel.itemsInternos.indexWhere(
                      (i) => (cod.isNotEmpty && i.codigo.trim().toUpperCase() == cod) ||
                             (i.descripcion.trim().toUpperCase() == desc),
                    );
                    if (iIdx != -1) {
                      actSel.itemsInternos[iIdx] = actSel.itemsInternos[iIdx].copyWith(cantidad: nuevaCant);
                    }
                  });
                },
                onEliminar: () {
                  setState(() {
                    actSel.itemsComerciales.removeAt(idx);
                    // 🔄 Si también está en itemsInternos, removerlo
                    final cod = item.codigo.trim().toUpperCase();
                    final desc = item.descripcion.trim().toUpperCase();
                    actSel.itemsInternos.removeWhere(
                      (i) => (cod.isNotEmpty && i.codigo.trim().toUpperCase() == cod) ||
                             (i.descripcion.trim().toUpperCase() == desc),
                    );
                  });
                },
              );
            }),
          ],
          if (actSel.itemsInternos.isEmpty && actSel.itemsComerciales.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('Esta actividad no requiere repuestos adicionales.', style: TextStyle(fontSize: 12, color: Colors.grey)),
            ),
        ],
      ),
    );
  }

  Widget _buildFilaRepuestoEditable({
    required ItemCatalogoEntity item,
    required bool esSupervisorOAdmin,
    required bool isProcesando,
    required ValueChanged<double> onCantidadChanged,
    required VoidCallback onEliminar,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${item.codigo} - ${item.descripcion}',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Unidad: ${item.unidad}',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
          if (esSupervisorOAdmin) ...[
            IconButton(
              icon: const Icon(Icons.remove_circle_outline, size: 20, color: Colors.red),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: isProcesando || _generandoDocumentos
                  ? null
                  : () {
                      if (item.cantidad > 1.0) {
                        onCantidadChanged(item.cantidad - 1.0);
                      } else if (item.cantidad > 0.5) {
                        onCantidadChanged(0.5);
                      }
                    },
            ),
            InkWell(
              onTap: isProcesando || _generandoDocumentos
                  ? null
                  : () async {
                      final ctrl = TextEditingController(text: item.cantidad.toString());
                      final res = await showDialog<double>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Modificar Cantidad', style: TextStyle(fontSize: 16)),
                          content: TextField(
                            controller: ctrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            autofocus: true,
                            decoration: InputDecoration(
                              labelText: 'Cantidad (${item.unidad})',
                              border: const OutlineInputBorder(),
                            ),
                          ),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
                            FilledButton(
                              onPressed: () {
                                final v = double.tryParse(ctrl.text.trim().replaceAll(',', '.'));
                                if (v != null && v >= 0) Navigator.pop(ctx, v);
                              },
                              child: const Text('Guardar'),
                            ),
                          ],
                        ),
                      );
                      if (res != null) onCantidadChanged(res);
                    },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.grey.shade400),
                ),
                child: Text(
                  (item.cantidad % 1 == 0) ? item.cantidad.toInt().toString() : item.cantidad.toString(),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF005A9C)),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle_outline, size: 20, color: Colors.green),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: isProcesando || _generandoDocumentos
                  ? null
                  : () => onCantidadChanged(item.cantidad + 1.0),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 18, color: Colors.grey),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              tooltip: 'Quitar repuesto de esta actividad',
              onPressed: isProcesando || _generandoDocumentos ? null : onEliminar,
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${item.cantidad} ${item.unidad}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ==========================================
  // WIDGET: MÓDULO DE GARANTÍAS
  // ==========================================
  Widget _buildModuloGarantia(bool isProcesando) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.orange.shade700, width: 2),
        borderRadius: BorderRadius.circular(8),
        color: Colors.orange.shade50,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange.shade800),
              const SizedBox(width: 8),
              const Text("REQUISITOS DE GARANTÍA", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const Divider(),
          const SizedBox(height: 8),
          Text(
            _esGarantiaServicio ? "1. Adjunte documento de OV (Servicio Antiguo) *" : "Adjunte documento de OV (Máquina Nueva) *",
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.receipt_long, color: Colors.orange),
            label: const Text("SELECCIONAR PDF DE ORDEN DE VENTA"),
            onPressed: isProcesando || _generandoDocumentos ? null : _seleccionarDocumentoOV,
            style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 50), backgroundColor: Colors.white),
          ),
          if (_documentoOVGarantia != null) ...[
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: const Icon(Icons.picture_as_pdf, color: Colors.orange),
                title: Text(_documentoOVGarantia!.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: isProcesando || _generandoDocumentos ? null : () => setState(() => _documentoOVGarantia = null),
                ),
              ),
            ),
          ],
          if (_esGarantiaServicio) ...[
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            const Text("2. Adjunte PDF de Revisión Técnica Antigua *", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.history_edu, color: Colors.deepOrange),
              label: const Text("SELECCIONAR PDF DE REVISIÓN TÉCNICA ANTIGUA"),
              onPressed: isProcesando || _generandoDocumentos ? null : _seleccionarDocumentoRevisionAntigua,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                backgroundColor: Colors.white,
                side: BorderSide(color: Colors.deepOrange.shade400),
              ),
            ),
            if (_documentoRevisionAntigua != null) ...[
              const SizedBox(height: 8),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.picture_as_pdf, color: Colors.deepOrange),
                  title: Text(_documentoRevisionAntigua!.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: isProcesando || _generandoDocumentos ? null : () => setState(() => _documentoRevisionAntigua = null),
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 500) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w500))),
                    CopyIconButtonWidget(etiqueta: label, valor: value),
                  ],
                ),
                const SizedBox(height: 4),
                Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87)),
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 180,
                child: Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w500)),
              ),
              Expanded(
                child: Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87)),
              ),
              CopyIconButtonWidget(etiqueta: label, valor: value),
            ],
          );
        },
      ),
    );
  }
}
