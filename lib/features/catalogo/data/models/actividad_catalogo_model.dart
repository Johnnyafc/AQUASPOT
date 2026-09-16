// lib/features/catalogo/data/models/actividad_catalogo_model.dart
import '../../domain/entities/actividad_catalogo_entity.dart';
import 'item_catalogo_model.dart';

class ActividadCatalogoModel extends ActividadCatalogoEntity {
  const ActividadCatalogoModel({
    required super.id,
    required super.codigo,
    required super.nombre,
    required super.equipo,
    super.horasHombre,
    required super.esVariable,
    super.descripcionTrabajo = '',
    super.incluye = '',
    super.itemsInternos = const [],
    super.itemsComerciales = const [],
    super.activo = true,
  });

  factory ActividadCatalogoModel.fromJson(Map<String, dynamic> json, String docId) {
    final List<dynamic> rawInternos = json['itemsInternos'] as List<dynamic>? ?? [];
    final List<dynamic> rawComerciales = json['itemsComerciales'] as List<dynamic>? ?? [];

    final internos = rawInternos
        .map((e) => ItemCatalogoModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();

    final comerciales = rawComerciales
        .map((e) => ItemCatalogoModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();

    return ActividadCatalogoModel(
      id: docId,
      codigo: json['codigo'] as String? ?? '',
      nombre: json['nombre'] as String? ?? '',
      equipo: json['equipo'] as String? ?? 'caracol',
      horasHombre: (json['horasHombre'] as num?)?.toDouble(),
      esVariable: json['esVariable'] as bool? ?? (json['horasHombre'] == null),
      descripcionTrabajo: json['descripcionTrabajo'] as String? ?? '',
      incluye: json['incluye'] as String? ?? '',
      itemsInternos: internos,
      itemsComerciales: comerciales,
      activo: json['activo'] as bool? ?? true,
    );
  }

  factory ActividadCatalogoModel.fromEntity(ActividadCatalogoEntity entity) {
    return ActividadCatalogoModel(
      id: entity.id,
      codigo: entity.codigo,
      nombre: entity.nombre,
      equipo: entity.equipo,
      horasHombre: entity.horasHombre,
      esVariable: entity.esVariable,
      descripcionTrabajo: entity.descripcionTrabajo,
      incluye: entity.incluye,
      itemsInternos: entity.itemsInternos,
      itemsComerciales: entity.itemsComerciales,
      activo: entity.activo,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'codigo': codigo,
      'nombre': nombre,
      'equipo': equipo,
      'horasHombre': horasHombre,
      'esVariable': esVariable,
      'descripcionTrabajo': descripcionTrabajo,
      'incluye': incluye,
      'itemsInternos': itemsInternos
          .map((e) => ItemCatalogoModel.fromEntity(e).toJson())
          .toList(),
      'itemsComerciales': itemsComerciales
          .map((e) => ItemCatalogoModel.fromEntity(e).toJson())
          .toList(),
      'activo': activo,
    };
  }
}
