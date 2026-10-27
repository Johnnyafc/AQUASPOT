// lib/features/tickets/domain/entities/mantenimiento_interno_entity.dart
//
// 🛠️ Datos propios de un requerimiento de MANTENIMIENTO INTERNO (máquinas y
// vehículos de Aquaspot). La serie, el horómetro, el detalle de la falla y
// las evidencias van en los campos de siempre del ticket (numeroSerie,
// horometro, fallaReportada, fotosUrls); aquí solo lo que no existe:
// placa, kilometraje, fecha y hora, la foto del horómetro / kilometraje y
// los videos de evidencia.

import 'package:equatable/equatable.dart';

enum TipoMantenimiento { correctivo, preventivo }

enum TipoActivoMantenimiento { cosechadora, contador, caracol, vehiculo }

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
      };
}

class MantenimientoInternoEntity extends Equatable {
  final TipoMantenimiento tipoMantenimiento;
  final TipoActivoMantenimiento tipoActivo;
  final String? placa; // solo vehículos
  final double? kilometraje; // solo vehículos
  final DateTime? fechaHoraFalla; // contador / caracol (en preventivo: fecha programada)
  final String? urlFotoLectura; // foto del horómetro (cosechadora) o del kilometraje (vehículo)
  final List<String> videosUrls; // videos de evidencia

  const MantenimientoInternoEntity({
    required this.tipoMantenimiento,
    required this.tipoActivo,
    this.placa,
    this.kilometraje,
    this.fechaHoraFalla,
    this.urlFotoLectura,
    this.videosUrls = const [],
  });

  MantenimientoInternoEntity copyWith({String? urlFotoLectura, List<String>? videosUrls}) {
    return MantenimientoInternoEntity(
      tipoMantenimiento: tipoMantenimiento,
      tipoActivo: tipoActivo,
      placa: placa,
      kilometraje: kilometraje,
      fechaHoraFalla: fechaHoraFalla,
      urlFotoLectura: urlFotoLectura ?? this.urlFotoLectura,
      videosUrls: videosUrls ?? this.videosUrls,
    );
  }

  @override
  List<Object?> get props =>
      [tipoMantenimiento, tipoActivo, placa, kilometraje, fechaHoraFalla, urlFotoLectura, videosUrls];
}
