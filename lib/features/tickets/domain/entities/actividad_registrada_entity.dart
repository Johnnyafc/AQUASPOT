// lib/features/tickets/domain/entities/actividad_registrada_entity.dart
import 'package:equatable/equatable.dart';

class ActividadRegistradaEntity extends Equatable {
  final String codigo;
  final String nombre;
  final double horasHombre;
  final String observacion;
  final List<String> fotosUrls;
  final String? incluye;

  const ActividadRegistradaEntity({
    required this.codigo,
    required this.nombre,
    required this.horasHombre,
    required this.observacion,
    this.fotosUrls = const [],
    this.incluye,
  });

  ActividadRegistradaEntity copyWith({
    String? codigo,
    String? nombre,
    double? horasHombre,
    String? observacion,
    List<String>? fotosUrls,
    String? incluye,
  }) {
    return ActividadRegistradaEntity(
      codigo: codigo ?? this.codigo,
      nombre: nombre ?? this.nombre,
      horasHombre: horasHombre ?? this.horasHombre,
      observacion: observacion ?? this.observacion,
      fotosUrls: fotosUrls ?? this.fotosUrls,
      incluye: incluye ?? this.incluye,
    );
  }

  @override
  List<Object?> get props => [codigo, nombre, horasHombre, observacion, fotosUrls, incluye];
}
