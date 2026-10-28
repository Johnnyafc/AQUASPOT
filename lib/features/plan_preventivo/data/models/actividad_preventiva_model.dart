// lib/features/plan_preventivo/data/models/actividad_preventiva_model.dart
//
// Conversión Firestore ↔ ActividadPreventivaEntity (colección
// "plan_preventivo").

import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../tickets/data/models/repuesto_registrado_model.dart';
import '../../../tickets/domain/entities/mantenimiento_interno_entity.dart';
import '../../../tickets/domain/entities/repuesto_registrado_entity.dart';
import '../../domain/entities/actividad_preventiva_entity.dart';
import '../../domain/services/plan_preventivo_service.dart';

class ActividadPreventivaModel {
  /// Id del documento: máquina + código (ej. "cosechadora_prev-01").
  static String idDe(ActividadPreventivaEntity a) => '${a.tipoActivo.name}_${a.codigo.toLowerCase()}';

  /// [incluirActivo] solo al crear: al editar no se toca "activo", así una
  /// edición no reactiva lo que otro usuario desactivó.
  static Map<String, dynamic> toJson(ActividadPreventivaEntity a, {bool incluirActivo = true}) => {
        'codigo': a.codigo,
        'tipoActivo': a.tipoActivo.name,
        'nombre': a.nombre,
        'descripcion': a.descripcion,
        'horasHombre': a.horasHombre,
        'frecuencia': a.frecuencia,
        'unidadFrecuencia': PlanPreventivoService.unidadDe(a.tipoActivo).name, // informativo
        'repuestos': [for (final r in a.repuestos) RepuestoRegistradoModel.fromEntity(r).toJson()],
        if (incluirActivo) 'activo': a.activo,
        'actualizadoPor': a.actualizadoPor,
        'fechaActualizacion': FieldValue.serverTimestamp(),
      };

  // Entidad pura (no el modelo) para que compare igual en el dominio.
  static RepuestoRegistradoEntity _repuesto(RepuestoRegistradoModel m) =>
      RepuestoRegistradoEntity(codigo: m.codigo, descripcion: m.descripcion, unidad: m.unidad, cantidad: m.cantidad);

  /// null si no trae una máquina reconocible.
  static ActividadPreventivaEntity? fromJson(Map<String, dynamic> json, String id) {
    final tipo = TipoActivoMantenimiento.values.where((t) => t.name == json['tipoActivo']).firstOrNull;
    if (tipo == null) return null;
    return ActividadPreventivaEntity(
      id: id,
      codigo: json['codigo']?.toString() ?? '',
      tipoActivo: tipo,
      nombre: json['nombre']?.toString() ?? '',
      descripcion: json['descripcion']?.toString() ?? '',
      horasHombre: (json['horasHombre'] as num?)?.toDouble() ?? 0,
      frecuencia: (json['frecuencia'] as num?)?.toDouble() ?? 0,
      repuestos: [
        for (final r in (json['repuestos'] as List?) ?? const [])
          if (r is Map) _repuesto(RepuestoRegistradoModel.fromJson(Map<String, dynamic>.from(r))),
      ],
      activo: json['activo'] as bool? ?? true,
      actualizadoPor: json['actualizadoPor']?.toString(),
    );
  }
}
