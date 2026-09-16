// lib/features/inventario/domain/entities/item_inventario_entity.dart
import 'package:equatable/equatable.dart';

class ItemInventarioEntity extends Equatable {
  final String codigo;            // SKU o código único en el sistema
  final String descripcion;       // Descripción del repuesto o insumo
  final double stockDisponible;   // Existencias actuales en bodega
  final String unidad;            // UNIDAD, JGO, MTR, etc.
  final String? ubicacion;        // Percha, estante o bodega
  final DateTime fechaActualizacion;

  const ItemInventarioEntity({
    required this.codigo,
    required this.descripcion,
    required this.stockDisponible,
    this.unidad = 'UNIDAD',
    this.ubicacion,
    required this.fechaActualizacion,
  });

  ItemInventarioEntity copyWith({
    String? codigo,
    String? descripcion,
    double? stockDisponible,
    String? unidad,
    String? ubicacion,
    DateTime? fechaActualizacion,
  }) {
    return ItemInventarioEntity(
      codigo: codigo ?? this.codigo,
      descripcion: descripcion ?? this.descripcion,
      stockDisponible: stockDisponible ?? this.stockDisponible,
      unidad: unidad ?? this.unidad,
      ubicacion: ubicacion ?? this.ubicacion,
      fechaActualizacion: fechaActualizacion ?? this.fechaActualizacion,
    );
  }

  @override
  List<Object?> get props => [
        codigo,
        descripcion,
        stockDisponible,
        unidad,
        ubicacion,
        fechaActualizacion,
      ];
}
