// lib/features/tickets/domain/entities/mantenimiento_interno_entity.dart
//
// 🛠️ Datos propios de un requerimiento de MANTENIMIENTO INTERNO (máquinas y
// vehículos de Aquaspot). La serie, el horómetro, el detalle de la falla y
// las evidencias van en los campos de siempre del ticket (numeroSerie,
// horometro, fallaReportada, fotosUrls); aquí solo lo que no existe:
// placa, kilometraje, fecha y hora, la foto del horómetro / kilometraje y
// los videos de evidencia; y los repuestos SIN CÓDIGO que esperan a Costos.

import 'package:equatable/equatable.dart';
import 'repuesto_por_codificar_entity.dart';

enum TipoMantenimiento { correctivo, preventivo }

enum TipoActivoMantenimiento { cosechadora, contador, caracol, vehiculo, aireAcondicionado, herramientas }

extension TipoMantenimientoX on TipoMantenimiento {
  String get etiqueta => switch (this) {
        TipoMantenimiento.correctivo => 'Correctivo',
        TipoMantenimiento.preventivo => 'Preventivo',
      };
}

extension TipoActivoMantenimientoX on TipoActivoMantenimiento {
  String get etiqueta => switch (this) {
        TipoActivoMantenimiento.cosechadora => 'Cosechadora',
        TipoActivoMantenimiento.contador => 'Contador',
        TipoActivoMantenimiento.caracol => 'Caracol',
        TipoActivoMantenimiento.vehiculo => 'Vehículo',
        TipoActivoMantenimiento.aireAcondicionado => 'Aire acondicionado',
        TipoActivoMantenimiento.herramientas => 'Herramientas',
      };
}

class MantenimientoInternoEntity extends Equatable {
  final TipoMantenimiento tipoMantenimiento;
  final TipoActivoMantenimiento tipoActivo;
  final String? placa; // solo vehículos
  final double? kilometraje; // solo vehículos
  final DateTime? fechaHoraFalla; // contador / caracol; solo fecha en aire acondicionado / herramientas (en preventivo: la programada)
  final String? urlFotoLectura; // foto del horómetro (cosechadora) o del kilometraje (vehículo)
  final List<String> videosUrls; // videos de evidencia
  final List<RepuestoPorCodificarEntity> repuestosPorCodificar; // sin código: Costos los crea

  const MantenimientoInternoEntity({
    required this.tipoMantenimiento,
    required this.tipoActivo,
    this.placa,
    this.kilometraje,
    this.fechaHoraFalla,
    this.urlFotoLectura,
    this.videosUrls = const [],
    this.repuestosPorCodificar = const [],
  });

  MantenimientoInternoEntity copyWith({
    String? urlFotoLectura,
    List<String>? videosUrls,
    List<RepuestoPorCodificarEntity>? repuestosPorCodificar,
  }) {
    return MantenimientoInternoEntity(
      tipoMantenimiento: tipoMantenimiento,
      tipoActivo: tipoActivo,
      placa: placa,
      kilometraje: kilometraje,
      fechaHoraFalla: fechaHoraFalla,
      urlFotoLectura: urlFotoLectura ?? this.urlFotoLectura,
      videosUrls: videosUrls ?? this.videosUrls,
      repuestosPorCodificar: repuestosPorCodificar ?? this.repuestosPorCodificar,
    );
  }

  @override
  List<Object?> get props =>
      [tipoMantenimiento, tipoActivo, placa, kilometraje, fechaHoraFalla, urlFotoLectura, videosUrls, repuestosPorCodificar];
}
