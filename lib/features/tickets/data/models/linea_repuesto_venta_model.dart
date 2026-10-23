import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/ficha_creacion_repuesto_entity.dart';
import '../../domain/entities/linea_repuesto_venta_entity.dart';

class LineaRepuestoVentaModel extends LineaRepuestoVentaEntity {
  const LineaRepuestoVentaModel({
    required super.codigo,
    required super.descripcion,
    required super.unidad,
    required super.cantidad,
    super.stockDisponibleAlEvaluar,
    super.porDeterminar,
    super.descripcionCliente,
    super.urlsEvidencia,
    super.urlsAudios,
    super.existeEnSistema,
    super.urlsCotizacionProveedor,
    super.definidoPor,
    super.definidoEn,
    super.cotizadaPorCompras,
    super.cotizadaPor,
    super.cotizadaEn,
    super.fichaCreacion,
    super.codigoCreadoPorCostos,
    super.codigoCreadoPor,
    super.codigoCreadoEn,
  });

  static FichaCreacionRepuestoEntity? _fichaDesdeJson(dynamic v) {
    if (v is! Map) return null;
    final m = Map<String, dynamic>.from(v);
    String t(String k, [String d = '']) => m[k]?.toString() ?? d;
    bool b(String k, bool d) => m[k] is bool ? m[k] as bool : d;
    return FichaCreacionRepuestoEntity(
      nombre: t('nombre'),
      familiaPieza: t('familiaPieza'),
      tipo: t('tipo'),
      atributoAcabado: t('atributoAcabado'),
      metrica: t('metrica'),
      equivalencia: t('equivalencia'),
      categoria: t('categoria'),
      udm: t('udm', 'UNIDAD'),
      tipoProducto: t('tipoProducto', 'ARTÍCULO'),
      linkImagen: t('linkImagen'),
      linkDescripcion: t('linkDescripcion'),
      comprado: b('comprado', true),
      vendido: b('vendido', true),
      activo: b('activo', false),
      almacenado: b('almacenado', true),
      gravaIva: b('gravaIva', true),
      fabricado: b('fabricado', false),
    );
  }

  static Map<String, dynamic>? _fichaAJson(FichaCreacionRepuestoEntity? f) => f == null
      ? null
      : {
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

  static DateTime? _fecha(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is String && v.trim().isNotEmpty) return DateTime.tryParse(v);
    return null;
  }

  static List<String> _lista(dynamic v) => (v as List?)?.map((e) => e.toString()).toList() ?? const [];

  factory LineaRepuestoVentaModel.fromJson(Map<String, dynamic> json) {
    return LineaRepuestoVentaModel(
      codigo: json['codigo']?.toString() ?? '',
      descripcion: json['descripcion']?.toString() ?? '',
      unidad: json['unidad']?.toString() ?? '',
      cantidad: (json['cantidad'] as num?)?.toDouble() ?? 0,
      stockDisponibleAlEvaluar: (json['stockDisponibleAlEvaluar'] as num?)?.toDouble(),
      // Campos nuevos: las líneas antiguas no los tienen (valores por defecto).
      porDeterminar: json['porDeterminar'] as bool? ?? false,
      descripcionCliente: json['descripcionCliente']?.toString() ?? '',
      urlsEvidencia: _lista(json['urlsEvidencia']),
      urlsAudios: _lista(json['urlsAudios']),
      existeEnSistema: json['existeEnSistema'] as bool? ?? true,
      urlsCotizacionProveedor: _lista(json['urlsCotizacionProveedor']),
      definidoPor: json['definidoPor']?.toString(),
      definidoEn: _fecha(json['definidoEn']),
      cotizadaPorCompras: json['cotizadaPorCompras'] as bool? ?? false,
      cotizadaPor: json['cotizadaPor']?.toString(),
      cotizadaEn: _fecha(json['cotizadaEn']),
      fichaCreacion: _fichaDesdeJson(json['fichaCreacion']),
      codigoCreadoPorCostos: json['codigoCreadoPorCostos'] as bool? ?? false,
      codigoCreadoPor: json['codigoCreadoPor']?.toString(),
      codigoCreadoEn: _fecha(json['codigoCreadoEn']),
    );
  }

  factory LineaRepuestoVentaModel.fromEntity(LineaRepuestoVentaEntity entity) {
    return LineaRepuestoVentaModel(
      codigo: entity.codigo,
      descripcion: entity.descripcion,
      unidad: entity.unidad,
      cantidad: entity.cantidad,
      stockDisponibleAlEvaluar: entity.stockDisponibleAlEvaluar,
      porDeterminar: entity.porDeterminar,
      descripcionCliente: entity.descripcionCliente,
      urlsEvidencia: entity.urlsEvidencia,
      urlsAudios: entity.urlsAudios,
      existeEnSistema: entity.existeEnSistema,
      urlsCotizacionProveedor: entity.urlsCotizacionProveedor,
      definidoPor: entity.definidoPor,
      definidoEn: entity.definidoEn,
      cotizadaPorCompras: entity.cotizadaPorCompras,
      cotizadaPor: entity.cotizadaPor,
      cotizadaEn: entity.cotizadaEn,
      fichaCreacion: entity.fichaCreacion,
      codigoCreadoPorCostos: entity.codigoCreadoPorCostos,
      codigoCreadoPor: entity.codigoCreadoPor,
      codigoCreadoEn: entity.codigoCreadoEn,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'codigo': codigo,
      'descripcion': descripcion,
      'unidad': unidad,
      'cantidad': cantidad,
      'stockDisponibleAlEvaluar': stockDisponibleAlEvaluar,
      'porDeterminar': porDeterminar,
      'descripcionCliente': descripcionCliente,
      'urlsEvidencia': urlsEvidencia,
      'urlsAudios': urlsAudios,
      'existeEnSistema': existeEnSistema,
      'urlsCotizacionProveedor': urlsCotizacionProveedor,
      'definidoPor': definidoPor,
      'definidoEn': definidoEn != null ? Timestamp.fromDate(definidoEn!) : null,
      'cotizadaPorCompras': cotizadaPorCompras,
      'cotizadaPor': cotizadaPor,
      'cotizadaEn': cotizadaEn != null ? Timestamp.fromDate(cotizadaEn!) : null,
      'fichaCreacion': _fichaAJson(fichaCreacion),
      'codigoCreadoPorCostos': codigoCreadoPorCostos,
      'codigoCreadoPor': codigoCreadoPor,
      'codigoCreadoEn': codigoCreadoEn != null ? Timestamp.fromDate(codigoCreadoEn!) : null,
    };
  }
}
