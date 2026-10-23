// lib/features/tickets/domain/entities/orden_recepcion_repuestos_entity.dart

import 'package:equatable/equatable.dart';

enum EstadoOrdenRecepcion {
  pendienteRecoger,
  recibidoTotal,
  recibidoParcial,
}

class ItemRecepcionRepuestoEntity extends Equatable {
  final String codigo;
  final String descripcion;
  final String unidad;
  final double cantidadDespachadaBodega;
  final double cantidadRecibidaTecnico;
  final bool validado;

  const ItemRecepcionRepuestoEntity({
    required this.codigo,
    required this.descripcion,
    required this.unidad,
    required this.cantidadDespachadaBodega,
    required this.cantidadRecibidaTecnico,
    this.validado = false,
  });

  ItemRecepcionRepuestoEntity copyWith({
    String? codigo,
    String? descripcion,
    String? unidad,
    double? cantidadDespachadaBodega,
    double? cantidadRecibidaTecnico,
    bool? validado,
  }) {
    return ItemRecepcionRepuestoEntity(
      codigo: codigo ?? this.codigo,
      descripcion: descripcion ?? this.descripcion,
      unidad: unidad ?? this.unidad,
      cantidadDespachadaBodega:
          cantidadDespachadaBodega ?? this.cantidadDespachadaBodega,
      cantidadRecibidaTecnico:
          cantidadRecibidaTecnico ?? this.cantidadRecibidaTecnico,
      validado: validado ?? this.validado,
    );
  }

  bool get esConforme =>
      validado && cantidadRecibidaTecnico == cantidadDespachadaBodega;

  bool get excedeMaximo =>
      cantidadRecibidaTecnico > cantidadDespachadaBodega;

  bool get esValida =>
      cantidadRecibidaTecnico >= 0 &&
      cantidadRecibidaTecnico <= cantidadDespachadaBodega;

  @override
  List<Object?> get props => [
        codigo,
        descripcion,
        unidad,
        cantidadDespachadaBodega,
        cantidadRecibidaTecnico,
        validado,
      ];
}

class OrdenRecepcionRepuestosEntity extends Equatable {
  final String id;
  final String ticketId;
  final String tecnicoId;
  final String tecnicoNombre;
  final String supervisorAsigna;
  final DateTime fechaAsignacion;
  final DateTime? fechaRecepcion;
  final EstadoOrdenRecepcion estado;
  final List<ItemRecepcionRepuestoEntity> items;
  final String? observacion;

  // 🛡️ Certificación de consumo en taller por el supervisor
  final bool validadoSupervisor;
  final DateTime? fechaValidadoSupervisor;
  final String? supervisorValida;

  const OrdenRecepcionRepuestosEntity({
    required this.id,
    required this.ticketId,
    required this.tecnicoId,
    required this.tecnicoNombre,
    required this.supervisorAsigna,
    required this.fechaAsignacion,
    this.fechaRecepcion,
    this.estado = EstadoOrdenRecepcion.pendienteRecoger,
    this.items = const [],
    this.observacion,
    this.validadoSupervisor = false,
    this.fechaValidadoSupervisor,
    this.supervisorValida,
  });

  OrdenRecepcionRepuestosEntity copyWith({
    String? id,
    String? ticketId,
    String? tecnicoId,
    String? tecnicoNombre,
    String? supervisorAsigna,
    DateTime? fechaAsignacion,
    DateTime? fechaRecepcion,
    EstadoOrdenRecepcion? estado,
    List<ItemRecepcionRepuestoEntity>? items,
    String? observacion,
    bool? validadoSupervisor,
    DateTime? fechaValidadoSupervisor,
    String? supervisorValida,
  }) {
    return OrdenRecepcionRepuestosEntity(
      id: id ?? this.id,
      ticketId: ticketId ?? this.ticketId,
      tecnicoId: tecnicoId ?? this.tecnicoId,
      tecnicoNombre: tecnicoNombre ?? this.tecnicoNombre,
      supervisorAsigna: supervisorAsigna ?? this.supervisorAsigna,
      fechaAsignacion: fechaAsignacion ?? this.fechaAsignacion,
      fechaRecepcion: fechaRecepcion ?? this.fechaRecepcion,
      estado: estado ?? this.estado,
      items: items ?? this.items,
      observacion: observacion ?? this.observacion,
      validadoSupervisor: validadoSupervisor ?? this.validadoSupervisor,
      fechaValidadoSupervisor:
          fechaValidadoSupervisor ?? this.fechaValidadoSupervisor,
      supervisorValida: supervisorValida ?? this.supervisorValida,
    );
  }

  bool get estaCompletada =>
      estado == EstadoOrdenRecepcion.recibidoTotal ||
      estado == EstadoOrdenRecepcion.recibidoParcial;

  double cantidadRecibidaDeItem(String codigo) {
    final cod = codigo.trim().toUpperCase();
    final match = items.where((i) => i.codigo.trim().toUpperCase() == cod);
    if (match.isEmpty) return 0.0;
    return match.fold(0.0, (acc, item) => acc + item.cantidadRecibidaTecnico);
  }

  @override
  List<Object?> get props => [
        id,
        ticketId,
        tecnicoId,
        tecnicoNombre,
        supervisorAsigna,
        fechaAsignacion,
        fechaRecepcion,
        estado,
        items,
        observacion,
        validadoSupervisor,
        fechaValidadoSupervisor,
        supervisorValida,
      ];
}
