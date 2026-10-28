// lib/features/tickets/domain/entities/actividad_mantenimiento.dart
//
// 🛠️ Actividad de la EVALUACIÓN TÉCNICA de un mantenimiento interno, tal
// como se va armando en pantalla: viene del Plan Maestro, del Plan
// preventivo o es una actividad NUEVA (código NUEVA-01…, solo en este
// ticket) y es modificable: horas hombre, observación, fotos y UNA sola
// lista de repuestos (no hay propuesta comercial).

import 'package:equatable/equatable.dart';
import 'archivo_adjunto.dart';
import 'repuesto_registrado_entity.dart';

class ActividadMantenimiento extends Equatable {
  final String codigo;
  final String nombre;
  final double horasHombre;
  final String observacion;
  final List<RepuestoRegistradoEntity> repuestos;
  final List<ArchivoAdjunto> fotos; // todas (los bytes van al informe)
  final List<String> fotosUrls; // las ya subidas, en el mismo orden que fotos

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
    String? nombre,
    double? horasHombre,
    String? observacion,
    List<RepuestoRegistradoEntity>? repuestos,
    List<ArchivoAdjunto>? fotos,
    List<String>? fotosUrls,
  }) {
    return ActividadMantenimiento(
      codigo: codigo,
      nombre: nombre ?? this.nombre,
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
