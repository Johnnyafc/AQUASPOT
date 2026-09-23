// lib/features/inventario/domain/entities/item_inventario_entity.dart
import 'package:equatable/equatable.dart';

class ItemInventarioEntity extends Equatable {
  final String codigo;            // SKU o código único en el sistema
  final String descripcion;       // Descripción del repuesto o insumo
  final double stockDisponible;   // Existencias actuales en bodega (espejo del ERP)
  final String unidad;            // UNIDAD, JGO, MTR, etc.
  final String? ubicacion;        // Percha, estante o bodega
  final DateTime fechaActualizacion;
  // NUEVO: cuanto de este codigo esta apartado por tickets Caracol que ya
  // generaron su evaluacion tecnica pero aun no llega a bodega (o no se
  // ha despachado del todo). Es un numero interno de la app -- el ERP no
  // lo conoce y la carga masiva por Excel NUNCA lo toca (ver
  // InventarioRemoteDataSourceImpl.guardarLoteInventario / toFirestore).
  final double stockReservado;

  const ItemInventarioEntity({
    required this.codigo,
    required this.descripcion,
    required this.stockDisponible,
    this.unidad = 'UNIDAD',
    this.ubicacion,
    required this.fechaActualizacion,
    this.stockReservado = 0.0,
  });

  // Lo realmente disponible para prometerle a un ticket nuevo: el fisico
  // (espejo del ERP) menos lo ya apartado por otros tickets Caracol.
  double get stockNetoDisponible => stockDisponible - stockReservado;

  ItemInventarioEntity copyWith({
    String? codigo,
    String? descripcion,
    double? stockDisponible,
    String? unidad,
    String? ubicacion,
    DateTime? fechaActualizacion,
    double? stockReservado,
  }) {
    return ItemInventarioEntity(
      codigo: codigo ?? this.codigo,
      descripcion: descripcion ?? this.descripcion,
      stockDisponible: stockDisponible ?? this.stockDisponible,
      unidad: unidad ?? this.unidad,
      ubicacion: ubicacion ?? this.ubicacion,
      fechaActualizacion: fechaActualizacion ?? this.fechaActualizacion,
      stockReservado: stockReservado ?? this.stockReservado,
    );
  }

  @override
  List<Object?> get props => [
        codigo,
        descripcion,
        stockDisponible,
        unidad,
        ubicacion,
        fechaActualizacion,
        stockReservado,
      ];
}
