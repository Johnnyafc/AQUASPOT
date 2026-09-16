import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/registro_despacho_entity.dart';

class DetalleItemDespachadoModel extends DetalleItemDespachadoEntity {
  const DetalleItemDespachadoModel({
    required super.codigo,
    required super.descripcion,
    required super.unidad,
    required super.cantidad,
  });

  factory DetalleItemDespachadoModel.fromJson(Map<String, dynamic> json) {
    return DetalleItemDespachadoModel(
      codigo: json['codigo']?.toString() ?? '',
      descripcion: json['descripcion']?.toString() ?? '',
      unidad: json['unidad']?.toString() ?? 'UND',
      cantidad: (json['cantidad'] as num?)?.toDouble() ?? 0.0,
    );
  }

  factory DetalleItemDespachadoModel.fromEntity(DetalleItemDespachadoEntity entity) {
    return DetalleItemDespachadoModel(
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

class RegistroDespachoModel extends RegistroDespachoEntity {
  const RegistroDespachoModel({
    required super.id,
    required super.fecha,
    required super.usuarioNombre,
    required super.usuarioId,
    required super.items,
    super.notas,
  });

  factory RegistroDespachoModel.fromJson(Map<String, dynamic> json) {
    DateTime fecha = DateTime.now();
    if (json['fecha'] != null) {
      if (json['fecha'] is Timestamp) {
        fecha = (json['fecha'] as Timestamp).toDate();
      } else if (json['fecha'] is String) {
        fecha = DateTime.tryParse(json['fecha'] as String) ?? DateTime.now();
      }
    }

    final rawItems = json['items'] as List<dynamic>? ?? [];
    final items = rawItems
        .map((e) => DetalleItemDespachadoModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();

    return RegistroDespachoModel(
      id: json['id']?.toString() ?? '',
      fecha: fecha,
      usuarioNombre: json['usuarioNombre']?.toString() ?? '',
      usuarioId: json['usuarioId']?.toString() ?? '',
      items: items,
      notas: json['notas']?.toString(),
    );
  }

  factory RegistroDespachoModel.fromEntity(RegistroDespachoEntity entity) {
    return RegistroDespachoModel(
      id: entity.id,
      fecha: entity.fecha,
      usuarioNombre: entity.usuarioNombre,
      usuarioId: entity.usuarioId,
      items: entity.items
          .map((e) => DetalleItemDespachadoModel.fromEntity(e))
          .toList(),
      notas: entity.notas,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fecha': Timestamp.fromDate(fecha),
      'usuarioNombre': usuarioNombre,
      'usuarioId': usuarioId,
      'items': items.map((e) {
        if (e is DetalleItemDespachadoModel) return e.toJson();
        return DetalleItemDespachadoModel.fromEntity(e).toJson();
      }).toList(),
      'notas': notas,
    };
  }
}
