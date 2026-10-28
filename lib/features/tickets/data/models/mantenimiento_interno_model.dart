// lib/features/tickets/data/models/mantenimiento_interno_model.dart
//
// Conversión Firestore ↔ MantenimientoInternoEntity (mapa "mantenimientoInterno"
// dentro del ticket).

import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/mantenimiento_interno_entity.dart';
import '../../domain/entities/repuesto_por_codificar_entity.dart';
import 'ficha_creacion_repuesto_model.dart';

class MantenimientoInternoModel {
  static Map<String, dynamic> toJson(MantenimientoInternoEntity e) => {
        'tipoMantenimiento': e.tipoMantenimiento.name,
        'tipoActivo': e.tipoActivo.name,
        if (e.placa != null) 'placa': e.placa,
        if (e.kilometraje != null) 'kilometraje': e.kilometraje,
        if (e.fechaHoraFalla != null) 'fechaHoraFalla': Timestamp.fromDate(e.fechaHoraFalla!),
        if (e.urlFotoLectura != null) 'urlFotoLectura': e.urlFotoLectura,
        if (e.videosUrls.isNotEmpty) 'videosUrls': e.videosUrls,
        if (e.repuestosPorCodificar.isNotEmpty)
          'repuestosPorCodificar': [for (final r in e.repuestosPorCodificar) _porCodificarAJson(r)],
      };

  static Map<String, dynamic> _porCodificarAJson(RepuestoPorCodificarEntity r) => {
        'descripcion': r.descripcion,
        'unidad': r.unidad,
        'cantidad': r.cantidad,
        'ficha': FichaCreacionRepuestoModel.toJson(r.ficha),
        'codigoCreado': r.codigoCreado,
        'descripcionCreada': r.descripcionCreada,
        if (r.creadoPor != null) 'creadoPor': r.creadoPor,
        if (r.creadoEn != null) 'creadoEn': Timestamp.fromDate(r.creadoEn!),
      };

  static RepuestoPorCodificarEntity? _porCodificarDesdeJson(dynamic json) {
    if (json is! Map) return null;
    final ficha = FichaCreacionRepuestoModel.fromJson(json['ficha']);
    if (ficha == null) return null;
    final creadoEn = json['creadoEn'];
    return RepuestoPorCodificarEntity(
      descripcion: json['descripcion']?.toString() ?? '',
      unidad: json['unidad']?.toString() ?? 'UNIDAD',
      cantidad: (json['cantidad'] as num?)?.toDouble() ?? 0,
      ficha: ficha,
      codigoCreado: json['codigoCreado']?.toString() ?? '',
      descripcionCreada: json['descripcionCreada']?.toString() ?? '',
      creadoPor: json['creadoPor']?.toString(),
      creadoEn: creadoEn is Timestamp ? creadoEn.toDate() : (creadoEn is String ? DateTime.tryParse(creadoEn) : null),
    );
  }

  /// null si el mapa no existe o no trae un tipo de máquina reconocible.
  static MantenimientoInternoEntity? fromJson(dynamic json) {
    if (json is! Map) return null;
    final tipoActivo = TipoActivoMantenimiento.values.where((t) => t.name == json['tipoActivo']).firstOrNull;
    if (tipoActivo == null) return null;
    final fecha = json['fechaHoraFalla'];
    return MantenimientoInternoEntity(
      tipoMantenimiento: TipoMantenimiento.values.where((t) => t.name == json['tipoMantenimiento']).firstOrNull ??
          TipoMantenimiento.correctivo,
      tipoActivo: tipoActivo,
      placa: json['placa']?.toString(),
      kilometraje: (json['kilometraje'] as num?)?.toDouble(),
      fechaHoraFalla: fecha is Timestamp
          ? fecha.toDate()
          : (fecha is String ? DateTime.tryParse(fecha) : null),
      urlFotoLectura: json['urlFotoLectura']?.toString(),
      videosUrls: [for (final u in (json['videosUrls'] as List?) ?? const []) u.toString()],
      repuestosPorCodificar: [
        for (final r in (json['repuestosPorCodificar'] as List?) ?? const []) ?_porCodificarDesdeJson(r),
      ],
    );
  }
}
