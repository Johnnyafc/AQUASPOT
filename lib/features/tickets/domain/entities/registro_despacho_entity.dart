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
  // NUEVO: candado de idempotencia para el descuento automatico de stock.
  // Se pone en true la primera (y unica) vez que este despacho puntual
  // resta stock en inventario_bodega, dentro de una transaccion de
  // Firestore. Si llegan mas evidencias despues para el mismo despacho
  // (subida en varias tandas), este flag evita que se descuente dos veces.
  // Default false para no romper despachos ya guardados antes de este campo.
  final bool stockDescontado;

  const RegistroDespachoEntity({
    required this.id,
    required this.fecha,
    required this.usuarioNombre,
    required this.usuarioId,
    required this.items,
    this.notas,
    this.fotosEvidenciasUrls = const [],
    this.stockDescontado = false,
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
    bool? stockDescontado,
  }) {
    return RegistroDespachoEntity(
      id: id ?? this.id,
      fecha: fecha ?? this.fecha,
      usuarioNombre: usuarioNombre ?? this.usuarioNombre,
      usuarioId: usuarioId ?? this.usuarioId,
      items: items ?? this.items,
      notas: notas ?? this.notas,
      fotosEvidenciasUrls: fotosEvidenciasUrls ?? this.fotosEvidenciasUrls,
      stockDescontado: stockDescontado ?? this.stockDescontado,
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
        stockDescontado,
      ];
}
