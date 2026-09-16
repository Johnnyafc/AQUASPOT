// lib/features/catalogo/data/models/item_catalogo_model.dart
import '../../domain/entities/item_catalogo_entity.dart';

class ItemCatalogoModel extends ItemCatalogoEntity {
  const ItemCatalogoModel({
    required super.codigo,
    required super.descripcion,
    super.unidad = 'UNIDAD',
    super.cantidad = 1.0,
  });

  factory ItemCatalogoModel.fromJson(Map<String, dynamic> json) {
    return ItemCatalogoModel(
      codigo: json['codigo'] as String? ?? '',
      descripcion: json['descripcion'] as String? ?? '',
      unidad: json['unidad'] as String? ?? 'UNIDAD',
      cantidad: (json['cantidad'] as num?)?.toDouble() ?? 1.0,
    );
  }

  factory ItemCatalogoModel.fromEntity(ItemCatalogoEntity entity) {
    return ItemCatalogoModel(
      codigo: entity.codigo,
      descripcion: entity.descripcion,
      unidad: entity.unidad,
      cantidad: entity.cantidad,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'codigo': codigo,
      'descripcion': descripcion,
      'unidad': unidad,
      'cantidad': cantidad,
    };
  }
}
