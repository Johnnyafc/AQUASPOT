import 'package:equatable/equatable.dart';

class DetalleItemDespachadoEntity extends Equatable {
  final String codigo;
  final String descripcion;
  final String unidad;
  final double cantidad;

  const DetalleItemDespachadoEntity({
    required this.codigo,
    required this.descripcion,
    required this.unidad,
    required this.cantidad,
  });

  @override
  List<Object?> get props => [codigo, descripcion, unidad, cantidad];
}

class RegistroDespachoEntity extends Equatable {
  final String id;
  final DateTime fecha;
  final String usuarioNombre;
  final String usuarioId;
  final List<DetalleItemDespachadoEntity> items;
  final String? notas;
  final List<String> fotosEvidenciasUrls;

  const RegistroDespachoEntity({
    required this.id,
    required this.fecha,
    required this.usuarioNombre,
    required this.usuarioId,
    required this.items,
    this.notas,
    this.fotosEvidenciasUrls = const [],
  });

  bool get tieneEvidencia => fotosEvidenciasUrls.isNotEmpty;

  RegistroDespachoEntity copyWith({
    String? id,
    DateTime? fecha,
    String? usuarioNombre,
    String? usuarioId,
    List<DetalleItemDespachadoEntity>? items,
    String? notas,
    List<String>? fotosEvidenciasUrls,
  }) {
    return RegistroDespachoEntity(
      id: id ?? this.id,
      fecha: fecha ?? this.fecha,
      usuarioNombre: usuarioNombre ?? this.usuarioNombre,
      usuarioId: usuarioId ?? this.usuarioId,
      items: items ?? this.items,
      notas: notas ?? this.notas,
      fotosEvidenciasUrls: fotosEvidenciasUrls ?? this.fotosEvidenciasUrls,
    );
  }

  @override
  List<Object?> get props => [
        id,
        fecha,
        usuarioNombre,
        usuarioId,
        items,
        notas,
        fotosEvidenciasUrls,
      ];
}
