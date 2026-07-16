import '../../domain/entities/item_compra_entity.dart';

class ItemCompraModel extends ItemCompraEntity {
  const ItemCompraModel({
    required super.sku,
    required super.descripcion,
    required super.cantidad,
    super.consumidoPorBodega = false,
  });

  factory ItemCompraModel.fromJson(Map<String, dynamic> json) {
    return ItemCompraModel(
      sku: json['sku']?.toString() ?? 'SIN-SKU',
      descripcion: json['descripcion']?.toString() ?? 'Repuesto no especificado',
      cantidad: (json['cantidad'] as num?)?.toInt() ?? 1, 
      consumidoPorBodega: json['consumidoPorBodega'] as bool? ?? false,
    );
  }

  factory ItemCompraModel.fromEntity(ItemCompraEntity entity) {
    return ItemCompraModel(
      sku: entity.sku,
      descripcion: entity.descripcion,
      cantidad: entity.cantidad,
      consumidoPorBodega: entity.consumidoPorBodega,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sku': sku,
      'descripcion': descripcion,
      'cantidad': cantidad,
      'consumidoPorBodega': consumidoPorBodega,
    };
  }
}