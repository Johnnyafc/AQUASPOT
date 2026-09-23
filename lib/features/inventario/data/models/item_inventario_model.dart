// lib/features/inventario/data/models/item_inventario_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/item_inventario_entity.dart';

class ItemInventarioModel extends ItemInventarioEntity {
  const ItemInventarioModel({
    required super.codigo,
    required super.descripcion,
    required super.stockDisponible,
    super.unidad = 'UNIDAD',
    super.ubicacion,
    required super.fechaActualizacion,
    super.stockReservado,
  });

  factory ItemInventarioModel.fromFirestore(Map<String, dynamic> json) {
    DateTime parseFecha(dynamic f) {
      if (f is Timestamp) return f.toDate();
      if (f is String) return DateTime.tryParse(f) ?? DateTime.now();
      return DateTime.now();
    }

    return ItemInventarioModel(
      codigo: json['codigo'] as String? ?? '',
      descripcion: json['descripcion'] as String? ?? '',
      stockDisponible: (json['stockDisponible'] as num?)?.toDouble() ?? 0.0,
      unidad: json['unidad'] as String? ?? 'UNIDAD',
      ubicacion: json['ubicacion'] as String?,
      fechaActualizacion: parseFecha(json['fechaActualizacion']),
      // Si el documento no trae el campo (aun no se reservo nada, o es
      // un item que solo vino del Excel), se toma como 0.0.
      stockReservado: (json['stockReservado'] as num?)?.toDouble() ?? 0.0,
    );
  }

  // OJO: a proposito NO incluye 'stockReservado'. Este metodo lo usa
  // unicamente la carga masiva por Excel (guardarLoteInventario) con
  // SetOptions(merge: true) -- si stockReservado viniera aca, cada carga
  // pisaria a 0 lo que los tickets Caracol tienen apartado. La reserva
  // solo se toca via FieldValue.increment() desde las transacciones de
  // tickets (ver ticket_remote_datasource_impl.dart).
  Map<String, dynamic> toFirestore() {
    return {
      'codigo': codigo,
      'descripcion': descripcion,
      'stockDisponible': stockDisponible,
      'unidad': unidad,
      'ubicacion': ubicacion,
      'fechaActualizacion': Timestamp.fromDate(fechaActualizacion),
    };
  }

  factory ItemInventarioModel.fromEntity(ItemInventarioEntity entity) {
    return ItemInventarioModel(
      codigo: entity.codigo,
      descripcion: entity.descripcion,
      stockDisponible: entity.stockDisponible,
      unidad: entity.unidad,
      ubicacion: entity.ubicacion,
      fechaActualizacion: entity.fechaActualizacion,
      stockReservado: entity.stockReservado,
    );
  }
}
