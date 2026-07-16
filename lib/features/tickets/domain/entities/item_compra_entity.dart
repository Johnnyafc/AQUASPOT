import 'package:equatable/equatable.dart';

class ItemCompraEntity extends Equatable {
  final String sku;
  final String descripcion;
  final int cantidad;
  final bool consumidoPorBodega;

  const ItemCompraEntity({
    required this.sku,
    required this.descripcion,
    required this.cantidad,
    this.consumidoPorBodega = false, 
  });

  ItemCompraEntity copyWith({
    String? sku,
    String? descripcion,
    int? cantidad,
    bool? consumidoPorBodega,
  }) {
    return ItemCompraEntity(
      sku: sku ?? this.sku,
      descripcion: descripcion ?? this.descripcion,
      cantidad: cantidad ?? this.cantidad,
      consumidoPorBodega: consumidoPorBodega ?? this.consumidoPorBodega,
    );
  }

  @override
  List<Object?> get props => [sku, descripcion, cantidad, consumidoPorBodega];
}