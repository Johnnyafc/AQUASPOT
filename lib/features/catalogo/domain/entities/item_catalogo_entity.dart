// lib/features/catalogo/domain/entities/item_catalogo_entity.dart
import 'package:equatable/equatable.dart';

class ItemCatalogoEntity extends Equatable {
  final String codigo;
  final String descripcion;
  final String unidad;
  final double cantidad;

  const ItemCatalogoEntity({
    required this.codigo,
    required this.descripcion,
    this.unidad = 'UNIDAD',
    this.cantidad = 1.0,
  });

  ItemCatalogoEntity copyWith({
    String? codigo,
    String? descripcion,
    String? unidad,
    double? cantidad,
  }) {
    return ItemCatalogoEntity(
      codigo: codigo ?? this.codigo,
      descripcion: descripcion ?? this.descripcion,
      unidad: unidad ?? this.unidad,
      cantidad: cantidad ?? this.cantidad,
    );
  }

  @override
  List<Object?> get props => [codigo, descripcion, unidad, cantidad];
}
