// lib/features/tickets/domain/entities/gestion_compras_entity.dart

import 'package:equatable/equatable.dart';

class GestionComprasEntity extends Equatable {
  final String urlOrdenCompra; // 📄 El PDF de la orden de compra
  final String observacion;    // 📝 Notas del operador de compras

  const GestionComprasEntity({
    required this.urlOrdenCompra,
    this.observacion = '',
  });

  @override
  List<Object?> get props => [urlOrdenCompra, observacion];
}