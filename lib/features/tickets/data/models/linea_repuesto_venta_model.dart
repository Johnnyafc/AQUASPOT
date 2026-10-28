import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/ficha_creacion_repuesto_entity.dart';
import '../../domain/entities/linea_repuesto_venta_entity.dart';
import 'ficha_creacion_repuesto_model.dart';

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

  static FichaCreacionRepuestoEntity? _fichaDesdeJson(dynamic v) => FichaCreacionRepuestoModel.fromJson(v);

  static Map<String, dynamic>? _fichaAJson(FichaCreacionRepuestoEntity? f) => FichaCreacionRepuestoModel.toJson(f);

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
