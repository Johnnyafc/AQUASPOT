// lib/features/tickets/domain/entities/item_despacho_bodega_entity.dart

import 'package:equatable/equatable.dart';

class ItemDespachoBodegaEntity extends Equatable {
  final String codigo;
  final String descripcion;
  final String unidad;
  final double cantidadSolicitada;
  final double stockDisponibleAlEvaluar;
  final bool validadoPorCompras;
  final double cantidadDespachada;
  final DateTime? fechaUltimoDespacho;
  final String? despachadoPor;

  // 🕒 Trazabilidad y Lead Time individual del repuesto (Evaluación de Proveedores)
  final DateTime? fechaSolicitud;
  final DateTime? fechaValidadoCompras;
  final double? tiempoAbastecimientoHoras;

  const ItemDespachoBodegaEntity({
    required this.codigo,
    required this.descripcion,
    required this.unidad,
    required this.cantidadSolicitada,
    required this.stockDisponibleAlEvaluar,
    this.validadoPorCompras = false,
    this.cantidadDespachada = 0.0,
    this.fechaUltimoDespacho,
    this.despachadoPor,
    this.fechaSolicitud,
    this.fechaValidadoCompras,
    this.tiempoAbastecimientoHoras,
  });

  double get cantidadFaltante {
    final diff = cantidadSolicitada - cantidadDespachada;
    return diff > 0 ? diff : 0.0;
  }

  bool get despachadoCompletamente => cantidadDespachada >= cantidadSolicitada;
  bool get tieneDespachoParcial => cantidadDespachada > 0;
  bool get tieneStockSuficiente => stockDisponibleAlEvaluar >= cantidadSolicitada;

  /// Horas reales transcurridas desde que se solicitó el repuesto hasta que Compras lo validó
  double? get tiempoAbastecimientoCalculadoHoras {
    if (tiempoAbastecimientoHoras != null) return tiempoAbastecimientoHoras;
    if (fechaSolicitud != null && fechaValidadoCompras != null) {
      final diff = fechaValidadoCompras!.difference(fechaSolicitud!).inMinutes / 60.0;
      return double.parse(diff.toStringAsFixed(2));
    }
    return null;
  }

  /// Horas reales transcurridas desde que Compras habilitó el repuesto hasta que Bodega lo despachó
  double? get tiempoReaccionBodegaCalculadoHoras {
    if (fechaValidadoCompras != null && fechaUltimoDespacho != null) {
      final diff = fechaUltimoDespacho!.difference(fechaValidadoCompras!).inMinutes / 60.0;
      return double.parse(diff.toStringAsFixed(2));
    }
    return null;
  }

  ItemDespachoBodegaEntity copyWith({
    String? codigo,
    String? descripcion,
    String? unidad,
    double? cantidadSolicitada,
    double? stockDisponibleAlEvaluar,
    bool? validadoPorCompras,
    double? cantidadDespachada,
    DateTime? fechaUltimoDespacho,
    String? despachadoPor,
    DateTime? fechaSolicitud,
    DateTime? fechaValidadoCompras,
    double? tiempoAbastecimientoHoras,
  }) {
    return ItemDespachoBodegaEntity(
      codigo: codigo ?? this.codigo,
      descripcion: descripcion ?? this.descripcion,
      unidad: unidad ?? this.unidad,
      cantidadSolicitada: cantidadSolicitada ?? this.cantidadSolicitada,
      stockDisponibleAlEvaluar:
          stockDisponibleAlEvaluar ?? this.stockDisponibleAlEvaluar,
      validadoPorCompras: validadoPorCompras ?? this.validadoPorCompras,
      cantidadDespachada: cantidadDespachada ?? this.cantidadDespachada,
      fechaUltimoDespacho: fechaUltimoDespacho ?? this.fechaUltimoDespacho,
      despachadoPor: despachadoPor ?? this.despachadoPor,
      fechaSolicitud: fechaSolicitud ?? this.fechaSolicitud,
      fechaValidadoCompras: fechaValidadoCompras ?? this.fechaValidadoCompras,
      tiempoAbastecimientoHoras:
          tiempoAbastecimientoHoras ?? this.tiempoAbastecimientoHoras,
    );
  }

  @override
  List<Object?> get props => [
        codigo,
        descripcion,
        unidad,
        cantidadSolicitada,
        stockDisponibleAlEvaluar,
        validadoPorCompras,
        cantidadDespachada,
        fechaUltimoDespacho,
        despachadoPor,
        fechaSolicitud,
        fechaValidadoCompras,
        tiempoAbastecimientoHoras,
      ];
}
