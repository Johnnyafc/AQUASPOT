// lib/features/tickets/data/models/gestion_compras_model.dart

import '../../domain/entities/gestion_compras_entity.dart';

class GestionComprasModel extends GestionComprasEntity {
  const GestionComprasModel({
    required super.urlOrdenCompra,
    super.observacion = '',
  });

  factory GestionComprasModel.fromJson(Map<String, dynamic> json) {
    return GestionComprasModel(
      // ⚙️ CASTEO ESTRICTO para evitar fallos de lectura desde Firestore
      urlOrdenCompra: json['urlOrdenCompra'] as String? ?? '',
      observacion: json['observacion'] as String? ?? '',
    );
  }

  factory GestionComprasModel.fromEntity(GestionComprasEntity entity) {
    return GestionComprasModel(
      urlOrdenCompra: entity.urlOrdenCompra,
      observacion: entity.observacion,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'urlOrdenCompra': urlOrdenCompra,
      'observacion': observacion,
    };
  }

  
}