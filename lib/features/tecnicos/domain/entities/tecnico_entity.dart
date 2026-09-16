// lib/features/tecnicos/domain/entities/tecnico_entity.dart

import 'package:equatable/equatable.dart';

class TecnicoEntity extends Equatable {
  final String id;
  final String nombre;
  final String rol;
  final bool activo;
  final DateTime fechaRegistro;

  const TecnicoEntity({
    required this.id,
    required this.nombre,
    required this.rol,
    this.activo = true,
    required this.fechaRegistro,
  });

  TecnicoEntity copyWith({
    String? id,
    String? nombre,
    String? rol,
    bool? activo,
    DateTime? fechaRegistro,
  }) {
    return TecnicoEntity(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      rol: rol ?? this.rol,
      activo: activo ?? this.activo,
      fechaRegistro: fechaRegistro ?? this.fechaRegistro,
    );
  }

  @override
  List<Object?> get props => [id, nombre, rol, activo, fechaRegistro];
}
