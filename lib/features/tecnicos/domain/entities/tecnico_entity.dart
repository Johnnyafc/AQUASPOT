// lib/features/tecnicos/domain/entities/tecnico_entity.dart

import 'package:equatable/equatable.dart';

class TecnicoEntity extends Equatable {
  final String id;
  final String nombre;
  final String rol;
  final bool activo;
  final DateTime fechaRegistro;
  final bool esExterno;
  final String? usuarioUid;

  const TecnicoEntity({
    required this.id,
    required this.nombre,
    required this.rol,
    this.activo = true,
    required this.fechaRegistro,
    this.esExterno = false,
    this.usuarioUid,
  });

  TecnicoEntity copyWith({
    String? id,
    String? nombre,
    String? rol,
    bool? activo,
    DateTime? fechaRegistro,
    bool? esExterno,
    String? usuarioUid,
  }) {
    return TecnicoEntity(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      rol: rol ?? this.rol,
      activo: activo ?? this.activo,
      fechaRegistro: fechaRegistro ?? this.fechaRegistro,
      esExterno: esExterno ?? this.esExterno,
      usuarioUid: usuarioUid ?? this.usuarioUid,
    );
  }

  @override
  List<Object?> get props => [id, nombre, rol, activo, fechaRegistro, esExterno, usuarioUid];
}
