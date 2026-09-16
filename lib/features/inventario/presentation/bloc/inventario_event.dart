import 'dart:typed_data';
import 'package:equatable/equatable.dart';

abstract class InventarioEvent extends Equatable {
  const InventarioEvent();

  @override
  List<Object?> get props => [];
}

class CargarInventarioEvent extends InventarioEvent {
  const CargarInventarioEvent();
}

class CargarStockExcelEvent extends InventarioEvent {
  final Uint8List bytes;
  const CargarStockExcelEvent(this.bytes);

  @override
  List<Object?> get props => [bytes];
}

class FiltrarInventarioEvent extends InventarioEvent {
  final String query;
  const FiltrarInventarioEvent(this.query);

  @override
  List<Object?> get props => [query];
}
