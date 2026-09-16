// lib/features/tickets/domain/entities/repuesto_registrado_entity.dart
import 'package:equatable/equatable.dart';

class RepuestoRegistradoEntity extends Equatable {
  final String codigo;
  final String descripcion;
  final String unidad;
  final double cantidad;

  const RepuestoRegistradoEntity({
    required this.codigo,
    required this.descripcion,
    this.unidad = 'UNIDAD',
    this.cantidad = 1.0,
  });

  RepuestoRegistradoEntity copyWith({
    String? codigo,
    String? descripcion,
    String? unidad,
    double? cantidad,
  }) {
    return RepuestoRegistradoEntity(
      codigo: codigo ?? this.codigo,
      descripcion: descripcion ?? this.descripcion,
      unidad: unidad ?? this.unidad,
      cantidad: cantidad ?? this.cantidad,
    );
  }

  @override
  List<Object?> get props => [codigo, descripcion, unidad, cantidad];
}
