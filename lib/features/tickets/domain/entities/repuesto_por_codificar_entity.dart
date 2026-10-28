// lib/features/tickets/domain/entities/repuesto_por_codificar_entity.dart
//
// 🧾 Repuesto SIN CÓDIGO de un mantenimiento interno: el técnico llenó su
// ficha de creación de código en la evaluación y Costos debe crearlo en el
// ERP. Mientras no tiene código no va a Compras ni a Bodega; cuando Costos
// registra el código oficial pasa a la lista de despacho de Bodega.

import 'package:equatable/equatable.dart';
import 'ficha_creacion_repuesto_entity.dart';

class RepuestoPorCodificarEntity extends Equatable {
  final String descripcion; // tal como lo escribió el técnico (MAYÚSCULAS)
  final String unidad;
  final double cantidad; // total de todas las actividades
  final FichaCreacionRepuestoEntity ficha;
  // Lo que registró Costos (vacío = pendiente).
  final String codigoCreado;
  final String descripcionCreada;
  final String? creadoPor;
  final DateTime? creadoEn;

  const RepuestoPorCodificarEntity({
    required this.descripcion,
    required this.unidad,
    required this.cantidad,
    required this.ficha,
    this.codigoCreado = '',
    this.descripcionCreada = '',
    this.creadoPor,
    this.creadoEn,
  });

  bool get pendiente => codigoCreado.trim().isEmpty;

  RepuestoPorCodificarEntity conCodigo({
    required String codigo,
    required String descripcion,
    required String creadoPor,
    required DateTime creadoEn,
  }) {
    return RepuestoPorCodificarEntity(
      descripcion: this.descripcion,
      unidad: unidad,
      cantidad: cantidad,
      ficha: ficha,
      codigoCreado: codigo.trim(),
      descripcionCreada: descripcion.trim(),
      creadoPor: creadoPor,
      creadoEn: creadoEn,
    );
  }

  @override
  List<Object?> get props =>
      [descripcion, unidad, cantidad, ficha, codigoCreado, descripcionCreada, creadoPor, creadoEn];
}
