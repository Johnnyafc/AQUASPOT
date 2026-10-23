// lib/features/tickets/data/models/orden_recepcion_repuestos_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/orden_recepcion_repuestos_entity.dart';

class ItemRecepcionRepuestoModel extends ItemRecepcionRepuestoEntity {
  const ItemRecepcionRepuestoModel({
    required super.codigo,
    required super.descripcion,
    required super.unidad,
    required super.cantidadDespachadaBodega,
    required super.cantidadRecibidaTecnico,
    super.validado = false,
  });

  factory ItemRecepcionRepuestoModel.fromJson(Map<String, dynamic> json) {
    return ItemRecepcionRepuestoModel(
      codigo: json['codigo'] as String? ?? '',
      descripcion: json['descripcion'] as String? ?? '',
      unidad: json['unidad'] as String? ?? 'UND',
      cantidadDespachadaBodega: (json['cantidadDespachadaBodega'] as num?)?.toDouble() ?? 0.0,
      cantidadRecibidaTecnico: (json['cantidadRecibidaTecnico'] as num?)?.toDouble() ?? 0.0,
      validado: json['validado'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'codigo': codigo,
      'descripcion': descripcion,
      'unidad': unidad,
      'cantidadDespachadaBodega': cantidadDespachadaBodega,
      'cantidadRecibidaTecnico': cantidadRecibidaTecnico,
      'validado': validado,
    };
  }

  factory ItemRecepcionRepuestoModel.fromEntity(ItemRecepcionRepuestoEntity entity) {
    return ItemRecepcionRepuestoModel(
      codigo: entity.codigo,
      descripcion: entity.descripcion,
      unidad: entity.unidad,
      cantidadDespachadaBodega: entity.cantidadDespachadaBodega,
      cantidadRecibidaTecnico: entity.cantidadRecibidaTecnico,
      validado: entity.validado,
    );
  }
}

class OrdenRecepcionRepuestosModel extends OrdenRecepcionRepuestosEntity {
  const OrdenRecepcionRepuestosModel({
    required super.id,
    required super.ticketId,
    required super.tecnicoId,
    required super.tecnicoNombre,
    required super.supervisorAsigna,
    required super.fechaAsignacion,
    super.fechaRecepcion,
    super.estado = EstadoOrdenRecepcion.pendienteRecoger,
    super.items = const [],
    super.observacion,
    super.validadoSupervisor = false,
    super.fechaValidadoSupervisor,
    super.supervisorValida,
  });

  factory OrdenRecepcionRepuestosModel.fromJson(Map<String, dynamic> json) {
    final estadoStr = json['estado'] as String? ?? 'pendienteRecoger';
    final estado = EstadoOrdenRecepcion.values.firstWhere(
      (e) => e.name == estadoStr,
      orElse: () => EstadoOrdenRecepcion.pendienteRecoger,
    );

    final itemsList = (json['items'] as List<dynamic>? ?? [])
        .map((i) => ItemRecepcionRepuestoModel.fromJson(Map<String, dynamic>.from(i as Map)))
        .toList();

    DateTime fechaAsig = DateTime.now();
    if (json['fechaAsignacion'] != null) {
      if (json['fechaAsignacion'] is Timestamp) {
        fechaAsig = (json['fechaAsignacion'] as Timestamp).toDate();
      } else if (json['fechaAsignacion'] is String) {
        fechaAsig = DateTime.tryParse(json['fechaAsignacion'] as String) ?? DateTime.now();
      }
    }

    DateTime? fechaRec;
    if (json['fechaRecepcion'] != null) {
      if (json['fechaRecepcion'] is Timestamp) {
        fechaRec = (json['fechaRecepcion'] as Timestamp).toDate();
      } else if (json['fechaRecepcion'] is String) {
        fechaRec = DateTime.tryParse(json['fechaRecepcion'] as String);
      }
    }

    DateTime? fechaValSup;
    if (json['fechaValidadoSupervisor'] != null) {
      if (json['fechaValidadoSupervisor'] is Timestamp) {
        fechaValSup = (json['fechaValidadoSupervisor'] as Timestamp).toDate();
      } else if (json['fechaValidadoSupervisor'] is String) {
        fechaValSup = DateTime.tryParse(json['fechaValidadoSupervisor'] as String);
      }
    }

    return OrdenRecepcionRepuestosModel(
      id: json['id'] as String? ?? '',
      ticketId: json['ticketId'] as String? ?? '',
      tecnicoId: json['tecnicoId'] as String? ?? '',
      tecnicoNombre: json['tecnicoNombre'] as String? ?? '',
      supervisorAsigna: json['supervisorAsigna'] as String? ?? '',
      fechaAsignacion: fechaAsig,
      fechaRecepcion: fechaRec,
      estado: estado,
      items: itemsList,
      observacion: json['observacion'] as String?,
      validadoSupervisor: json['validadoSupervisor'] as bool? ?? false,
      fechaValidadoSupervisor: fechaValSup,
      supervisorValida: json['supervisorValida'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'ticketId': ticketId,
      'tecnicoId': tecnicoId,
      'tecnicoNombre': tecnicoNombre,
      'supervisorAsigna': supervisorAsigna,
      'fechaAsignacion': fechaAsignacion.toIso8601String(),
      'fechaRecepcion': fechaRecepcion?.toIso8601String(),
      'estado': estado.name,
      'items': items.map((i) {
        if (i is ItemRecepcionRepuestoModel) {
          return i.toJson();
        }
        return ItemRecepcionRepuestoModel.fromEntity(i).toJson();
      }).toList(),
      'observacion': observacion,
      'validadoSupervisor': validadoSupervisor,
      'fechaValidadoSupervisor': fechaValidadoSupervisor?.toIso8601String(),
      'supervisorValida': supervisorValida,
    };
  }

  factory OrdenRecepcionRepuestosModel.fromEntity(OrdenRecepcionRepuestosEntity entity) {
    return OrdenRecepcionRepuestosModel(
      id: entity.id,
      ticketId: entity.ticketId,
      tecnicoId: entity.tecnicoId,
      tecnicoNombre: entity.tecnicoNombre,
      supervisorAsigna: entity.supervisorAsigna,
      fechaAsignacion: entity.fechaAsignacion,
      fechaRecepcion: entity.fechaRecepcion,
      estado: entity.estado,
      items: entity.items
          .map((i) => ItemRecepcionRepuestoModel.fromEntity(i))
          .toList(),
      observacion: entity.observacion,
      validadoSupervisor: entity.validadoSupervisor,
      fechaValidadoSupervisor: entity.fechaValidadoSupervisor,
      supervisorValida: entity.supervisorValida,
    );
  }
}
