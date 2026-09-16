// lib/features/tickets/data/models/item_despacho_bodega_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/item_despacho_bodega_entity.dart';

DateTime? _parseFecha(dynamic val) {
  if (val == null) return null;
  if (val is Timestamp) return val.toDate();
  if (val is String && val.trim().isNotEmpty) return DateTime.tryParse(val);
  return null;
}

dynamic _toFirestoreFecha(DateTime? dt) {
  if (dt == null) return null;
  return Timestamp.fromDate(dt);
}

class ItemDespachoBodegaModel extends ItemDespachoBodegaEntity {
  const ItemDespachoBodegaModel({
    required super.codigo,
    required super.descripcion,
    required super.unidad,
    required super.cantidadSolicitada,
    required super.stockDisponibleAlEvaluar,
    super.validadoPorCompras = false,
    super.cantidadDespachada = 0.0,
    super.fechaUltimoDespacho,
    super.despachadoPor,
    super.fechaSolicitud,
    super.fechaValidadoCompras,
    super.tiempoAbastecimientoHoras,
  });

  factory ItemDespachoBodegaModel.fromJson(Map<String, dynamic> json) {
    return ItemDespachoBodegaModel(
      codigo: json['codigo']?.toString() ?? '',
      descripcion: json['descripcion']?.toString() ?? '',
      unidad: json['unidad']?.toString() ?? 'UND',
      cantidadSolicitada: (json['cantidadSolicitada'] as num?)?.toDouble() ?? 0.0,
      stockDisponibleAlEvaluar:
          (json['stockDisponibleAlEvaluar'] as num?)?.toDouble() ?? 0.0,
      validadoPorCompras: json['validadoPorCompras'] as bool? ?? false,
      cantidadDespachada:
          (json['cantidadDespachada'] as num?)?.toDouble() ?? 0.0,
      fechaUltimoDespacho: _parseFecha(json['fechaUltimoDespacho']),
      despachadoPor: json['despachadoPor']?.toString(),
      fechaSolicitud: _parseFecha(json['fechaSolicitud']),
      fechaValidadoCompras: _parseFecha(json['fechaValidadoCompras']),
      tiempoAbastecimientoHoras:
          (json['tiempoAbastecimientoHoras'] as num?)?.toDouble(),
    );
  }

  factory ItemDespachoBodegaModel.fromEntity(ItemDespachoBodegaEntity entity) {
    return ItemDespachoBodegaModel(
      codigo: entity.codigo,
      descripcion: entity.descripcion,
      unidad: entity.unidad,
      cantidadSolicitada: entity.cantidadSolicitada,
      stockDisponibleAlEvaluar: entity.stockDisponibleAlEvaluar,
      validadoPorCompras: entity.validadoPorCompras,
      cantidadDespachada: entity.cantidadDespachada,
      fechaUltimoDespacho: entity.fechaUltimoDespacho,
      despachadoPor: entity.despachadoPor,
      fechaSolicitud: entity.fechaSolicitud,
      fechaValidadoCompras: entity.fechaValidadoCompras,
      tiempoAbastecimientoHoras: entity.tiempoAbastecimientoHoras,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'codigo': codigo,
      'descripcion': descripcion,
      'unidad': unidad,
      'cantidadSolicitada': cantidadSolicitada,
      'stockDisponibleAlEvaluar': stockDisponibleAlEvaluar,
      'validadoPorCompras': validadoPorCompras,
      'cantidadDespachada': cantidadDespachada,
      'fechaUltimoDespacho': _toFirestoreFecha(fechaUltimoDespacho),
      'despachadoPor': despachadoPor,
      'fechaSolicitud': _toFirestoreFecha(fechaSolicitud),
      'fechaValidadoCompras': _toFirestoreFecha(fechaValidadoCompras),
      'tiempoAbastecimientoHoras': tiempoAbastecimientoHoras ?? tiempoAbastecimientoCalculadoHoras,
    };
  }
}
