import 'package:equatable/equatable.dart';
import '../../domain/entities/item_inventario_entity.dart';

abstract class InventarioState extends Equatable {
  const InventarioState();

  @override
  List<Object?> get props => [];
}

class InventarioInitial extends InventarioState {
  const InventarioInitial();
}

class InventarioLoading extends InventarioState {
  final String mensaje;
  const InventarioLoading(this.mensaje);

  @override
  List<Object?> get props => [mensaje];
}

class InventarioLoaded extends InventarioState {
  final List<ItemInventarioEntity> items;
  final List<ItemInventarioEntity> itemsFiltrados;
  final Map<String, ItemInventarioEntity> mapaPorCodigo;

  const InventarioLoaded({
    required this.items,
    required this.itemsFiltrados,
    required this.mapaPorCodigo,
  });

  InventarioLoaded copyWith({
    List<ItemInventarioEntity>? items,
    List<ItemInventarioEntity>? itemsFiltrados,
    Map<String, ItemInventarioEntity>? mapaPorCodigo,
  }) {
    return InventarioLoaded(
      items: items ?? this.items,
      itemsFiltrados: itemsFiltrados ?? this.itemsFiltrados,
      mapaPorCodigo: mapaPorCodigo ?? this.mapaPorCodigo,
    );
  }

  @override
  List<Object?> get props => [items, itemsFiltrados, mapaPorCodigo];
}

class InventarioOperacionSuccess extends InventarioState {
  final String mensaje;
  final int totalProcesados;

  const InventarioOperacionSuccess({
    required this.mensaje,
    required this.totalProcesados,
  });

  @override
  List<Object?> get props => [mensaje, totalProcesados];
}

class InventarioError extends InventarioState {
  final String mensaje;
  const InventarioError(this.mensaje);

  @override
  List<Object?> get props => [mensaje];
}
