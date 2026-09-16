// lib/features/tickets/data/models/gestion_compras_model.dart

import '../../domain/entities/gestion_compras_entity.dart';

class GestionComprasModel extends GestionComprasEntity {
  const GestionComprasModel({
    super.urlsOrdenCompra = const [],
    super.observacion = '',
  });

  factory GestionComprasModel.fromJson(Map<String, dynamic> json) {
    // 🛡️ SENSOR DE RETROCOMPATIBILIDAD (Evita que tickets viejos colapsen)
    List<String> urlsDecodificadas = [];

    // 1. Buscamos el arreglo nuevo (Si es un ticket procesado con el nuevo sistema)
    if (json['urlsOrdenCompra'] != null) {
      urlsDecodificadas = List<String>.from(json['urlsOrdenCompra'].map((x) => x.toString()));
    } 
    // 2. Fallback: Si no existe el arreglo, buscamos el string viejo de la versión anterior
    else if (json['urlOrdenCompra'] != null && json['urlOrdenCompra'].toString().trim().isNotEmpty) {
      urlsDecodificadas.add(json['urlOrdenCompra'].toString());
    }

    return GestionComprasModel(
      urlsOrdenCompra: urlsDecodificadas,
      observacion: json['observacion'] as String? ?? '',
    );
  }

  factory GestionComprasModel.fromEntity(GestionComprasEntity entity) {
    return GestionComprasModel(
      urlsOrdenCompra: entity.urlsOrdenCompra,
      observacion: entity.observacion,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      // Escribimos directamente con el nuevo estándar de Matriz
      'urlsOrdenCompra': urlsOrdenCompra,
      'observacion': observacion,
    };
  }
}