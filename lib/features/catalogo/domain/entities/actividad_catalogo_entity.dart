// lib/features/catalogo/domain/entities/actividad_catalogo_entity.dart
import 'package:equatable/equatable.dart';
import 'item_catalogo_entity.dart';

class ActividadCatalogoEntity extends Equatable {
  final String id;
  final String codigo;
  final String nombre;
  final String equipo; // 'caracol', 'contador', 'cosechadora'
  final double? horasHombre; // Si es null, es variable
  final bool esVariable;
  final String descripcionTrabajo;
  final String incluye;
  final List<ItemCatalogoEntity> itemsInternos;
  final List<ItemCatalogoEntity> itemsComerciales;
  final bool activo;

  const ActividadCatalogoEntity({
    required this.id,
    required this.codigo,
    required this.nombre,
    required this.equipo,
    this.horasHombre,
    required this.esVariable,
    this.descripcionTrabajo = '',
    this.incluye = '',
    this.itemsInternos = const [],
    this.itemsComerciales = const [],
    this.activo = true,
  });

  ActividadCatalogoEntity copyWith({
    String? id,
    String? codigo,
    String? nombre,
    String? equipo,
    double? horasHombre,
    bool? esVariable,
    String? descripcionTrabajo,
    String? incluye,
    List<ItemCatalogoEntity>? itemsInternos,
    List<ItemCatalogoEntity>? itemsComerciales,
    bool? activo,
  }) {
    return ActividadCatalogoEntity(
      id: id ?? this.id,
      codigo: codigo ?? this.codigo,
      nombre: nombre ?? this.nombre,
      equipo: equipo ?? this.equipo,
      horasHombre: horasHombre ?? this.horasHombre,
      esVariable: esVariable ?? this.esVariable,
      descripcionTrabajo: descripcionTrabajo ?? this.descripcionTrabajo,
      incluye: incluye ?? this.incluye,
      itemsInternos: itemsInternos ?? this.itemsInternos,
      itemsComerciales: itemsComerciales ?? this.itemsComerciales,
      activo: activo ?? this.activo,
    );
  }

  @override
  List<Object?> get props => [
        id,
        codigo,
        nombre,
        equipo,
        horasHombre,
        esVariable,
        descripcionTrabajo,
        incluye,
        itemsInternos,
        itemsComerciales,
        activo,
      ];
}
