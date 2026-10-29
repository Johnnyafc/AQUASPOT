// lib/features/tickets/domain/services/borrador_mantenimiento_service.dart
//
// 💾 Borradores de MANTENIMIENTO INTERNO (OT): convierte el formulario de
// creación y la Evaluación Técnica a un BorradorLocal (datos simples +
// archivos aparte) y de vuelta, para que no se pierda lo llenado si se
// cierra o recarga la página. Solo reglas puras; probado en
// test/borrador_mantenimiento_test.dart.
//
// - Creación: uno por usuario en cada dispositivo (claveCreacion).
// - Evaluación: uno por OT (claveEvaluacion).
// Los archivos se identifican por nombre, tamaño y una huella del contenido
// (idArchivo): el mismo archivo conserva su id y no se vuelve a escribir en
// cada guardado. Las fotos de las actividades se guardan junto con su URL
// (si ya se subió), para que no se desalineen si alguna no se recupera.

import '../entities/actividad_mantenimiento.dart';
import '../entities/archivo_adjunto.dart';
import '../entities/ficha_creacion_repuesto_entity.dart';
import '../entities/mantenimiento_interno_entity.dart';
import '../entities/repuesto_registrado_entity.dart';
import '../repositories/borrador_repository.dart';
import 'formulario_mantenimiento_service.dart';

typedef BorradorCreacionMantenimiento = ({
  DatosMantenimientoInterno datos,
  List<ArchivoAdjunto> fotos,
  List<ArchivoAdjunto> videos,
  ArchivoAdjunto? fotoLectura,
});

typedef BorradorEvaluacionMantenimiento = ({
  List<ActividadMantenimiento> actividades,
  Map<String, FichaCreacionRepuestoEntity> fichas,
  bool necesitaCompras,
  String motivoNoCompras,
});

class BorradorMantenimientoService {
  static const String prefijoClaves = 'draft_ot_';
  static String claveCreacion(String usuario) => '${prefijoClaves}creacion_$usuario';
  static String claveEvaluacion(String ticketId) => '${prefijoClaves}evaluacion_$ticketId';

  /// Huella rápida del contenido (FNV-1a sobre hasta ~4000 bytes repartidos):
  /// distingue dos archivos con el mismo nombre y tamaño.
  static String _huella(List<int> bytes) {
    var h = 0x811c9dc5;
    final paso = bytes.length > 4096 ? bytes.length ~/ 4096 : 1;
    for (var i = 0; i < bytes.length; i += paso) {
      h = ((h ^ bytes[i]) * 0x01000193) & 0xffffffff;
    }
    return h.toRadixString(16);
  }

  /// Id estable de un archivo dentro de su borrador.
  static String idArchivo(String grupo, ArchivoAdjunto a) =>
      '$grupo-${a.bytes.length}-${_huella(a.bytes)}-${a.nombre}'.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');

  static List<String> _agregar(Map<String, ArchivoAdjunto> archivos, String grupo, List<ArchivoAdjunto> lista) => [
        for (final a in lista) _agregarUno(archivos, grupo, a),
      ];

  static String _agregarUno(Map<String, ArchivoAdjunto> archivos, String grupo, ArchivoAdjunto a) {
    var id = idArchivo(grupo, a);
    // Dos archivos distintos con el mismo nombre y tamaño: se numeran.
    for (var n = 2; archivos.containsKey(id) && !identical(archivos[id], a); n++) {
      id = '${idArchivo(grupo, a)}-$n';
    }
    archivos[id] = a;
    return id;
  }

  static List<ArchivoAdjunto> _archivosDe(BorradorLocal b, dynamic ids) => [
        for (final id in (ids as List? ?? const [])) ?b.archivos[id.toString()],
      ];

  static T? _enum<T extends Enum>(List<T> valores, dynamic nombre) =>
      valores.where((v) => v.name == nombre).firstOrNull;

  static double? _numero(dynamic v) => v is num ? v.toDouble() : null;

  // ------------------------------------------------------------ Creación
  /// Nada que guardar todavía (formulario recién abierto).
  static bool creacionVacia(DatosMantenimientoInterno d, {int archivos = 0}) =>
      d.tipoActivo == null && d.detalle.trim().isEmpty && d.marca.trim().isEmpty && archivos == 0;

  static BorradorLocal creacionABorrador(
    DatosMantenimientoInterno d, {
    List<ArchivoAdjunto> fotos = const [],
    List<ArchivoAdjunto> videos = const [],
    ArchivoAdjunto? fotoLectura,
  }) {
    final archivos = <String, ArchivoAdjunto>{};
    return BorradorLocal(
      datos: {
        'tipoMantenimiento': d.tipoMantenimiento.name,
        'tipoActivo': d.tipoActivo?.name,
        'serieOPlaca': d.serieOPlaca,
        'horometro': d.horometro,
        'kilometraje': d.kilometraje,
        'fechaHora': d.fechaHora?.toIso8601String(),
        'marca': d.marca,
        'especificacion': d.especificacion,
        'detalle': d.detalle,
        'fotos': _agregar(archivos, 'foto', fotos),
        'videos': _agregar(archivos, 'video', videos),
        'fotoLectura': fotoLectura == null ? null : _agregarUno(archivos, 'lectura', fotoLectura),
      },
      archivos: archivos,
    );
  }

  /// null si el borrador está dañado. Los archivos que ya no estén se omiten.
  static BorradorCreacionMantenimiento? creacionDesdeBorrador(BorradorLocal b) {
    try {
      final m = b.datos;
      final fotos = _archivosDe(b, m['fotos']);
      final videos = _archivosDe(b, m['videos']);
      final lectura = m['fotoLectura'] == null ? null : b.archivos[m['fotoLectura'].toString()];
      final fecha = m['fechaHora'] is String ? DateTime.tryParse(m['fechaHora'] as String) : null;
      return (
        datos: DatosMantenimientoInterno(
          tipoMantenimiento: _enum(TipoMantenimiento.values, m['tipoMantenimiento']) ?? TipoMantenimiento.correctivo,
          tipoActivo: _enum(TipoActivoMantenimiento.values, m['tipoActivo']),
          serieOPlaca: m['serieOPlaca'] as String?,
          horometro: _numero(m['horometro']),
          kilometraje: _numero(m['kilometraje']),
          fechaHora: fecha,
          marca: m['marca'] as String? ?? '',
          especificacion: m['especificacion'] as String? ?? '',
          detalle: m['detalle'] as String? ?? '',
          cantidadFotos: fotos.length,
          cantidadVideos: videos.length,
          tieneFotoLectura: lectura != null,
        ),
        fotos: fotos,
        videos: videos,
        fotoLectura: lectura,
      );
    } catch (_) {
      return null;
    }
  }

  // ------------------------------------------------------------ Evaluación
  static bool evaluacionVacia({
    required List<ActividadMantenimiento> actividades,
    required Map<String, FichaCreacionRepuestoEntity> fichas,
    required bool necesitaCompras,
    required String motivoNoCompras,
  }) =>
      actividades.isEmpty && fichas.isEmpty && necesitaCompras && motivoNoCompras.trim().isEmpty;

  static BorradorLocal evaluacionABorrador({
    required List<ActividadMantenimiento> actividades,
    required Map<String, FichaCreacionRepuestoEntity> fichas,
    required bool necesitaCompras,
    required String motivoNoCompras,
  }) {
    final archivos = <String, ArchivoAdjunto>{};
    return BorradorLocal(
      datos: {
        'actividades': [
          for (final a in actividades)
            {
              'codigo': a.codigo,
              'nombre': a.nombre,
              'horasHombre': a.horasHombre,
              'observacion': a.observacion,
              'repuestos': [
                for (final r in a.repuestos)
                  {'codigo': r.codigo, 'descripcion': r.descripcion, 'unidad': r.unidad, 'cantidad': r.cantidad},
              ],
              // Cada foto con su URL si ya se subió (las subidas van primero).
              'fotos': [
                for (var i = 0; i < a.fotos.length; i++)
                  {'id': _agregarUno(archivos, 'act', a.fotos[i]), 'url': i < a.fotosUrls.length ? a.fotosUrls[i] : null},
              ],
            },
        ],
        'fichas': {for (final e in fichas.entries) e.key: _fichaAJson(e.value)},
        'necesitaCompras': necesitaCompras,
        'motivoNoCompras': motivoNoCompras,
      },
      archivos: archivos,
    );
  }

  /// null si el borrador está dañado. Si una foto no se recupera se quita
  /// junto con su URL: las demás siguen alineadas con sus URLs.
  static BorradorEvaluacionMantenimiento? evaluacionDesdeBorrador(BorradorLocal b) {
    try {
      final m = b.datos;
      final actividades = [
        for (final raw in (m['actividades'] as List? ?? const []))
          () {
            final a = Map<String, dynamic>.from(raw as Map);
            final fotos = <ArchivoAdjunto>[];
            final urls = <String>[];
            for (final par in (a['fotos'] as List? ?? const [])) {
              final foto = b.archivos[(par as Map)['id'].toString()];
              if (foto == null) continue;
              fotos.add(foto);
              if (par['url'] is String) urls.add(par['url'] as String);
            }
            return ActividadMantenimiento(
              codigo: a['codigo'] as String,
              nombre: a['nombre'] as String? ?? '',
              horasHombre: _numero(a['horasHombre']) ?? 0,
              observacion: a['observacion'] as String? ?? '',
              repuestos: [
                for (final r in (a['repuestos'] as List? ?? const []))
                  RepuestoRegistradoEntity(
                    codigo: (r as Map)['codigo'] as String? ?? '',
                    descripcion: r['descripcion'] as String? ?? '',
                    unidad: r['unidad'] as String? ?? 'UNIDAD',
                    cantidad: _numero(r['cantidad']) ?? 1,
                  ),
              ],
              fotos: fotos,
              fotosUrls: urls,
            );
          }(),
      ];
      return (
        actividades: actividades,
        fichas: {
          for (final e in Map<String, dynamic>.from(m['fichas'] as Map? ?? const {}).entries)
            e.key: _fichaDesdeJson(Map<String, dynamic>.from(e.value as Map)),
        },
        necesitaCompras: m['necesitaCompras'] as bool? ?? true,
        motivoNoCompras: m['motivoNoCompras'] as String? ?? '',
      );
    } catch (_) {
      return null;
    }
  }

  static Map<String, dynamic> _fichaAJson(FichaCreacionRepuestoEntity f) => {
        'nombre': f.nombre,
        'familiaPieza': f.familiaPieza,
        'tipo': f.tipo,
        'atributoAcabado': f.atributoAcabado,
        'metrica': f.metrica,
        'equivalencia': f.equivalencia,
        'categoria': f.categoria,
        'udm': f.udm,
        'tipoProducto': f.tipoProducto,
        'linkImagen': f.linkImagen,
        'linkDescripcion': f.linkDescripcion,
        'comprado': f.comprado,
        'vendido': f.vendido,
        'activo': f.activo,
        'almacenado': f.almacenado,
        'gravaIva': f.gravaIva,
        'fabricado': f.fabricado,
      };

  static FichaCreacionRepuestoEntity _fichaDesdeJson(Map<String, dynamic> j) {
    const d = FichaCreacionRepuestoEntity();
    return FichaCreacionRepuestoEntity(
      nombre: j['nombre'] as String? ?? d.nombre,
      familiaPieza: j['familiaPieza'] as String? ?? d.familiaPieza,
      tipo: j['tipo'] as String? ?? d.tipo,
      atributoAcabado: j['atributoAcabado'] as String? ?? d.atributoAcabado,
      metrica: j['metrica'] as String? ?? d.metrica,
      equivalencia: j['equivalencia'] as String? ?? d.equivalencia,
      categoria: j['categoria'] as String? ?? d.categoria,
      udm: j['udm'] as String? ?? d.udm,
      tipoProducto: j['tipoProducto'] as String? ?? d.tipoProducto,
      linkImagen: j['linkImagen'] as String? ?? d.linkImagen,
      linkDescripcion: j['linkDescripcion'] as String? ?? d.linkDescripcion,
      comprado: j['comprado'] as bool? ?? d.comprado,
      vendido: j['vendido'] as bool? ?? d.vendido,
      activo: j['activo'] as bool? ?? d.activo,
      almacenado: j['almacenado'] as bool? ?? d.almacenado,
      gravaIva: j['gravaIva'] as bool? ?? d.gravaIva,
      fabricado: j['fabricado'] as bool? ?? d.fabricado,
    );
  }
}
