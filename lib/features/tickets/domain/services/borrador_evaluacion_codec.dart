// lib/features/tickets/domain/services/borrador_evaluacion_codec.dart
//
// 💾 Convierte las actividades de Caracol de la Evaluación Técnica a JSON
// para el borrador local, y de vuelta. Guarda la actividad COMPLETA (no
// solo su código) para que se restaure igual aunque el catálogo cambie
// después. Las fotos no van aquí: la página guarda sus referencias aparte
// (IndexedDB en web; base64 + ruta en el celular).

import '../../../catalogo/data/models/actividad_catalogo_model.dart';
import '../../../catalogo/data/models/item_catalogo_model.dart';
import '../entities/actividad_evaluacion_seleccionada.dart';

class BorradorEvaluacionCodec {
  static Map<String, dynamic> actividadToJson(
    ActividadEvaluacionSeleccionada a, {
    List<Map<String, dynamic>> fotos = const [],
  }) {
    return {
      'actividad': ActividadCatalogoModel.fromEntity(a.actividad).toJson(),
      'horasHombre': a.horasHombre,
      'observacion': a.observacion,
      'itemsInternos': a.itemsInternos.map((i) => ItemCatalogoModel.fromEntity(i).toJson()).toList(),
      'itemsComerciales': a.itemsComerciales.map((i) => ItemCatalogoModel.fromEntity(i).toJson()).toList(),
      'fotos': fotos,
    };
  }

  /// Reconstruye la actividad SIN fotos (la página las agrega después).
  /// Devuelve null si el JSON está dañado.
  static ActividadEvaluacionSeleccionada? actividadFromJson(dynamic json) {
    if (json is! Map) return null;
    try {
      final map = Map<String, dynamic>.from(json);
      final actJson = Map<String, dynamic>.from(map['actividad'] as Map);
      final actividad = ActividadCatalogoModel.fromJson(actJson, actJson['id'] as String? ?? '');
      List<ItemCatalogoModel> items(dynamic raw) => (raw as List<dynamic>? ?? [])
          .map((e) => ItemCatalogoModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      return ActividadEvaluacionSeleccionada(
        actividad: actividad,
        horasHombre: (map['horasHombre'] as num?)?.toDouble() ?? actividad.horasHombre ?? 0.0,
        observacion: map['observacion'] as String? ?? '',
        itemsInternos: items(map['itemsInternos']),
        itemsComerciales: items(map['itemsComerciales']),
      );
    } catch (_) {
      return null;
    }
  }

  /// Referencias de fotos guardadas en el JSON de una actividad.
  static List<Map<String, dynamic>> fotosDeJson(dynamic json) {
    if (json is! Map) return const [];
    final fotos = json['fotos'];
    if (fotos is! List) return const [];
    return fotos
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }
}
