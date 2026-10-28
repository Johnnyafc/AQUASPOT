// lib/features/plan_preventivo/domain/entities/actividad_preventiva_entity.dart
//
// 🗓️ Actividad del PLAN PREVENTIVO de una máquina propia (mantenimiento
// interno): código PREV-01…, horas hombre, cada cuánto se hace (frecuencia
// en horas, km o días según la máquina) y los repuestos del inventario que
// lleva. Va en su propia colección (no en el Plan Maestro) para que no
// aparezca en la evaluación de reparación.

import 'package:equatable/equatable.dart';
import '../../../tickets/domain/entities/mantenimiento_interno_entity.dart';
import '../../../tickets/domain/entities/repuesto_registrado_entity.dart';

class ActividadPreventivaEntity extends Equatable {
  final String id; // vacío = nueva
  final String codigo; // PREV-01…, correlativo por máquina
  final TipoActivoMantenimiento tipoActivo;
  final String nombre;
  final String descripcion;
  final double horasHombre;
  final double frecuencia; // en la unidad de la máquina (PlanPreventivoService.unidadDe)
  final List<RepuestoRegistradoEntity> repuestos; // solo del inventario (con código)
  final bool activo;
  final String? actualizadoPor;

  const ActividadPreventivaEntity({
    this.id = '',
    required this.codigo,
    required this.tipoActivo,
    required this.nombre,
    this.descripcion = '',
    this.horasHombre = 0,
    this.frecuencia = 0,
    this.repuestos = const [],
    this.activo = true,
    this.actualizadoPor,
  });

  ActividadPreventivaEntity copyWith({
    String? id,
    String? nombre,
    String? descripcion,
    double? horasHombre,
    double? frecuencia,
    List<RepuestoRegistradoEntity>? repuestos,
    bool? activo,
    String? actualizadoPor,
  }) {
    return ActividadPreventivaEntity(
      id: id ?? this.id,
      codigo: codigo,
      tipoActivo: tipoActivo,
      nombre: nombre ?? this.nombre,
      descripcion: descripcion ?? this.descripcion,
      horasHombre: horasHombre ?? this.horasHombre,
      frecuencia: frecuencia ?? this.frecuencia,
      repuestos: repuestos ?? this.repuestos,
      activo: activo ?? this.activo,
      actualizadoPor: actualizadoPor ?? this.actualizadoPor,
    );
  }

  @override
  List<Object?> get props =>
      [id, codigo, tipoActivo, nombre, descripcion, horasHombre, frecuencia, repuestos, activo, actualizadoPor];
}
