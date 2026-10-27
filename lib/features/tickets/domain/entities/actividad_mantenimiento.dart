// lib/features/tickets/domain/entities/actividad_mantenimiento.dart
//
// 🛠️ Actividad de la EVALUACIÓN TÉCNICA de un mantenimiento interno, tal
// como se va armando en pantalla: viene del Plan Maestro (o, más adelante,
// del Plan preventivo) y es modificable: horas hombre, observación, fotos
// y UNA sola lista de repuestos (no hay propuesta comercial).

import 'package:equatable/equatable.dart';
import 'archivo_adjunto.dart';
import 'repuesto_registrado_entity.dart';

class ActividadMantenimiento extends Equatable {
  final String codigo;
  final String nombre;
  final double horasHombre;
  final String observacion;
  final List<RepuestoRegistradoEntity> repuestos;
  final List<ArchivoAdjunto> fotos; // por subir
  final List<String> fotosUrls; // ya subidas

  const ActividadMantenimiento({
    required this.codigo,
    required this.nombre,
    this.horasHombre = 0,
    this.observacion = '',
    this.repuestos = const [],
    this.fotos = const [],
    this.fotosUrls = const [],
  });

  ActividadMantenimiento copyWith({
    double? horasHombre,
    String? observacion,
    List<RepuestoRegistradoEntity>? repuestos,
    List<ArchivoAdjunto>? fotos,
    List<String>? fotosUrls,
  }) {
    return ActividadMantenimiento(
      codigo: codigo,
      nombre: nombre,
      horasHombre: horasHombre ?? this.horasHombre,
      observacion: observacion ?? this.observacion,
      repuestos: repuestos ?? this.repuestos,
      fotos: fotos ?? this.fotos,
      fotosUrls: fotosUrls ?? this.fotosUrls,
    );
  }

  @override
  List<Object?> get props => [codigo, nombre, horasHombre, observacion, repuestos, fotos, fotosUrls];
}
