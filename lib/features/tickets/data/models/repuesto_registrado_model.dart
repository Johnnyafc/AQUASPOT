// lib/features/tickets/data/models/repuesto_registrado_model.dart
import '../../domain/entities/repuesto_registrado_entity.dart';

class RepuestoRegistradoModel extends RepuestoRegistradoEntity {
  const RepuestoRegistradoModel({
    required super.codigo,
    required super.descripcion,
    super.unidad = 'UNIDAD',
    super.cantidad = 1.0,
  });

  factory RepuestoRegistradoModel.fromJson(Map<String, dynamic> json) {
    return RepuestoRegistradoModel(
      codigo: json['codigo'] as String? ?? '',
      descripcion: json['descripcion'] as String? ?? '',
      unidad: json['unidad'] as String? ?? 'UNIDAD',
      cantidad: (json['cantidad'] as num?)?.toDouble() ?? 1.0,
    );
  }

  factory RepuestoRegistradoModel.fromEntity(RepuestoRegistradoEntity entity) {
    return RepuestoRegistradoModel(
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
