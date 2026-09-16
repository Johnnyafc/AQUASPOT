// lib/features/tickets/data/models/tiempos_operativos_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/tiempos_operativos_entity.dart';

DateTime? _parseFecha(dynamic val) {
  if (val == null) return null;
  if (val is Timestamp) return val.toDate();
  if (val is String && val.trim().isNotEmpty) return DateTime.tryParse(val);
  return null;
}

dynamic _toFirestoreFecha(DateTime? dt) {
  if (dt == null) return null;
  return Timestamp.fromDate(dt);
}

class SubEstadosModel extends SubEstadosEntity {
  const SubEstadosModel({
    super.compras,
    super.bodega,
    super.taller,
  });

  factory SubEstadosModel.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const SubEstadosModel();
    return SubEstadosModel(
      compras: json['compras']?.toString() ?? 'PENDIENTE',
      bodega: json['bodega']?.toString() ?? 'EN_ESPERA',
      taller: json['taller']?.toString() ?? 'EN_ESPERA_MATERIAL',
    );
  }

  factory SubEstadosModel.fromEntity(SubEstadosEntity entity) {
    return SubEstadosModel(
      compras: entity.compras,
      bodega: entity.bodega,
      taller: entity.taller,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'compras': compras,
      'bodega': bodega,
      'taller': taller,
    };
  }
}

class MetricaComprasModel extends MetricaComprasEntity {
  const MetricaComprasModel({
    super.fechaInicio,
    super.fechaFin,
    super.tiempoGestionHoras,
    super.totalRepuestos,
    super.repuestosValidados,
  });

  factory MetricaComprasModel.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const MetricaComprasModel();
    return MetricaComprasModel(
      fechaInicio: _parseFecha(json['fechaInicio']),
      fechaFin: _parseFecha(json['fechaFin']),
      tiempoGestionHoras: (json['tiempoGestionHoras'] as num?)?.toDouble() ?? 0.0,
      totalRepuestos: (json['totalRepuestos'] as num?)?.toInt() ?? 0,
      repuestosValidados: (json['repuestosValidados'] as num?)?.toInt() ?? 0,
    );
  }

  factory MetricaComprasModel.fromEntity(MetricaComprasEntity entity) {
    return MetricaComprasModel(
      fechaInicio: entity.fechaInicio,
      fechaFin: entity.fechaFin,
      tiempoGestionHoras: entity.tiempoGestionHoras,
      totalRepuestos: entity.totalRepuestos,
      repuestosValidados: entity.repuestosValidados,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'fechaInicio': _toFirestoreFecha(fechaInicio),
      'fechaFin': _toFirestoreFecha(fechaFin),
      'tiempoGestionHoras': tiempoGestionHoras,
      'totalRepuestos': totalRepuestos,
      'repuestosValidados': repuestosValidados,
    };
  }
}

class MetricaBodegaModel extends MetricaBodegaEntity {
  const MetricaBodegaModel({
    super.fechaPrimerDespacho,
    super.fechaUltimoDespacho,
    super.tiempoNetoDespachoHoras,
    super.tiempoEsperaPorComprasHoras,
    super.totalLotesDespachados,
  });

  factory MetricaBodegaModel.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const MetricaBodegaModel();
    return MetricaBodegaModel(
      fechaPrimerDespacho: _parseFecha(json['fechaPrimerDespacho']),
      fechaUltimoDespacho: _parseFecha(json['fechaUltimoDespacho']),
      tiempoNetoDespachoHoras:
          (json['tiempoNetoDespachoHoras'] as num?)?.toDouble() ?? 0.0,
      tiempoEsperaPorComprasHoras:
          (json['tiempoEsperaPorComprasHoras'] as num?)?.toDouble() ?? 0.0,
      totalLotesDespachados:
          (json['totalLotesDespachados'] as num?)?.toInt() ?? 0,
    );
  }

  factory MetricaBodegaModel.fromEntity(MetricaBodegaEntity entity) {
    return MetricaBodegaModel(
      fechaPrimerDespacho: entity.fechaPrimerDespacho,
      fechaUltimoDespacho: entity.fechaUltimoDespacho,
      tiempoNetoDespachoHoras: entity.tiempoNetoDespachoHoras,
      tiempoEsperaPorComprasHoras: entity.tiempoEsperaPorComprasHoras,
      totalLotesDespachados: entity.totalLotesDespachados,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'fechaPrimerDespacho': _toFirestoreFecha(fechaPrimerDespacho),
      'fechaUltimoDespacho': _toFirestoreFecha(fechaUltimoDespacho),
      'tiempoNetoDespachoHoras': tiempoNetoDespachoHoras,
      'tiempoEsperaPorComprasHoras': tiempoEsperaPorComprasHoras,
      'totalLotesDespachados': totalLotesDespachados,
    };
  }
}

class MetricaTallerModel extends MetricaTallerEntity {
  const MetricaTallerModel({
    super.fechaInicioTrabajo,
    super.fechaFinTrabajo,
    super.tiempoNetoTrabajoHoras,
    super.tiempoEsperaMaterialHoras,
  });

  factory MetricaTallerModel.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const MetricaTallerModel();
    return MetricaTallerModel(
      fechaInicioTrabajo: _parseFecha(json['fechaInicioTrabajo']),
      fechaFinTrabajo: _parseFecha(json['fechaFinTrabajo']),
      tiempoNetoTrabajoHoras:
          (json['tiempoNetoTrabajoHoras'] as num?)?.toDouble() ?? 0.0,
      tiempoEsperaMaterialHoras:
          (json['tiempoEsperaMaterialHoras'] as num?)?.toDouble() ?? 0.0,
    );
  }

  factory MetricaTallerModel.fromEntity(MetricaTallerEntity entity) {
    return MetricaTallerModel(
      fechaInicioTrabajo: entity.fechaInicioTrabajo,
      fechaFinTrabajo: entity.fechaFinTrabajo,
      tiempoNetoTrabajoHoras: entity.tiempoNetoTrabajoHoras,
      tiempoEsperaMaterialHoras: entity.tiempoEsperaMaterialHoras,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'fechaInicioTrabajo': _toFirestoreFecha(fechaInicioTrabajo),
      'fechaFinTrabajo': _toFirestoreFecha(fechaFinTrabajo),
      'tiempoNetoTrabajoHoras': tiempoNetoTrabajoHoras,
      'tiempoEsperaMaterialHoras': tiempoEsperaMaterialHoras,
    };
  }
}

class TiemposOperativosModel extends TiemposOperativosEntity {
  const TiemposOperativosModel({
    super.leadTimeTotalHoras,
    super.subEstados,
    super.compras,
    super.bodega,
    super.taller,
  });

  factory TiemposOperativosModel.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const TiemposOperativosModel();
    return TiemposOperativosModel(
      leadTimeTotalHoras: (json['leadTimeTotalHoras'] as num?)?.toDouble() ?? 0.0,
      subEstados: SubEstadosModel.fromJson(json['subEstados'] as Map<String, dynamic>?),
      compras: MetricaComprasModel.fromJson(json['compras'] as Map<String, dynamic>?),
      bodega: MetricaBodegaModel.fromJson(json['bodega'] as Map<String, dynamic>?),
      taller: MetricaTallerModel.fromJson(json['taller'] as Map<String, dynamic>?),
    );
  }

  factory TiemposOperativosModel.fromEntity(TiemposOperativosEntity entity) {
    return TiemposOperativosModel(
      leadTimeTotalHoras: entity.leadTimeTotalHoras,
      subEstados: entity.subEstados,
      compras: entity.compras,
      bodega: entity.bodega,
      taller: entity.taller,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'leadTimeTotalHoras': leadTimeTotalHoras,
      'subEstados': (subEstados is SubEstadosModel)
          ? (subEstados as SubEstadosModel).toJson()
          : SubEstadosModel.fromEntity(subEstados).toJson(),
      'compras': (compras is MetricaComprasModel)
          ? (compras as MetricaComprasModel).toJson()
          : MetricaComprasModel.fromEntity(compras).toJson(),
      'bodega': (bodega is MetricaBodegaModel)
          ? (bodega as MetricaBodegaModel).toJson()
          : MetricaBodegaModel.fromEntity(bodega).toJson(),
      'taller': (taller is MetricaTallerModel)
          ? (taller as MetricaTallerModel).toJson()
          : MetricaTallerModel.fromEntity(taller).toJson(),
    };
  }
}
