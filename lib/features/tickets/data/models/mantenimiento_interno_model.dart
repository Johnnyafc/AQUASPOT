// lib/features/tickets/data/models/mantenimiento_interno_model.dart
//
// Conversión Firestore ↔ MantenimientoInternoEntity (mapa "mantenimientoInterno"
// dentro del ticket).

import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/mantenimiento_interno_entity.dart';

class MantenimientoInternoModel {
  static Map<String, dynamic> toJson(MantenimientoInternoEntity e) => {
        'tipoMantenimiento': e.tipoMantenimiento.name,
        'tipoActivo': e.tipoActivo.name,
        if (e.placa != null) 'placa': e.placa,
        if (e.kilometraje != null) 'kilometraje': e.kilometraje,
        if (e.fechaHoraFalla != null) 'fechaHoraFalla': Timestamp.fromDate(e.fechaHoraFalla!),
      };

  /// null si el mapa no existe o no trae un tipo de máquina reconocible.
  static MantenimientoInternoEntity? fromJson(dynamic json) {
    if (json is! Map) return null;
    final tipoActivo = TipoActivoMantenimiento.values.where((t) => t.name == json['tipoActivo']).firstOrNull;
    if (tipoActivo == null) return null;
    final fecha = json['fechaHoraFalla'];
    return MantenimientoInternoEntity(
      tipoMantenimiento: TipoMantenimiento.values.where((t) => t.name == json['tipoMantenimiento']).firstOrNull ??
          TipoMantenimiento.correctivo,
      tipoActivo: tipoActivo,
      placa: json['placa']?.toString(),
      kilometraje: (json['kilometraje'] as num?)?.toDouble(),
      fechaHoraFalla: fecha is Timestamp
          ? fecha.toDate()
          : (fecha is String ? DateTime.tryParse(fecha) : null),
    );
  }
}
