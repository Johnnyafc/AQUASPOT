// lib/features/tickets/domain/entities/gestion_compras_entity.dart

import 'package:equatable/equatable.dart';

class GestionComprasEntity extends Equatable {
  // 🔌 CAMBIO DE CALIBRE: De String simple a Matriz (Lista)
  final List<String> urlsOrdenCompra; 
  final String observacion;    // 📝 Notas del operador de compras

  const GestionComprasEntity({
    this.urlsOrdenCompra = const [], // Tolerancia a fallos: inicializa vacío
    this.observacion = '',
  });

  @override
  List<Object?> get props => [urlsOrdenCompra, observacion];
}