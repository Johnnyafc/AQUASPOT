// lib/features/tickets/domain/entities/tiempos_operativos_entity.dart

import 'package:equatable/equatable.dart';

/// Semáforos o sub-estados operativos que corren concurrentemente por estación.
class SubEstadosEntity extends Equatable {
  final String compras; // PENDIENTE, EN_RECEPCION_PARCIAL, COMPLETADO
  final String bodega; // EN_ESPERA, DISPONIBLE_DESPACHO, DESPACHO_PARCIAL, DESPACHO_TOTAL
  final String taller; // EN_ESPERA_MATERIAL, TRABAJO_PARCIAL, TRABAJO_EN_CURSO, FINALIZADO

  const SubEstadosEntity({
    this.compras = 'PENDIENTE',
    this.bodega = 'EN_ESPERA',
    this.taller = 'EN_ESPERA_MATERIAL',
  });

  SubEstadosEntity copyWith({
    String? compras,
    String? bodega,
    String? taller,
  }) {
    return SubEstadosEntity(
      compras: compras ?? this.compras,
      bodega: bodega ?? this.bodega,
      taller: taller ?? this.taller,
    );
  }

  @override
  List<Object?> get props => [compras, bodega, taller];
}

/// Métricas de ciclo y gestión para el área de Compras.
class MetricaComprasEntity extends Equatable {
  final DateTime? fechaInicio;
  final DateTime? fechaFin;
  final double tiempoGestionHoras;
  final int totalRepuestos;
  final int repuestosValidados;

  const MetricaComprasEntity({
    this.fechaInicio,
    this.fechaFin,
    this.tiempoGestionHoras = 0.0,
    this.totalRepuestos = 0,
    this.repuestosValidados = 0,
  });

  MetricaComprasEntity copyWith({
    DateTime? fechaInicio,
    DateTime? fechaFin,
    double? tiempoGestionHoras,
    int? totalRepuestos,
    int? repuestosValidados,
  }) {
    return MetricaComprasEntity(
      fechaInicio: fechaInicio ?? this.fechaInicio,
      fechaFin: fechaFin ?? this.fechaFin,
      tiempoGestionHoras: tiempoGestionHoras ?? this.tiempoGestionHoras,
      totalRepuestos: totalRepuestos ?? this.totalRepuestos,
      repuestosValidados: repuestosValidados ?? this.repuestosValidados,
    );
  }

  @override
  List<Object?> get props => [
        fechaInicio,
        fechaFin,
        tiempoGestionHoras,
        totalRepuestos,
        repuestosValidados,
      ];
}

/// Métricas de ciclo para Despacho / Bodega (discriminando tiempo neto vs espera de compras).
class MetricaBodegaEntity extends Equatable {
  final DateTime? fechaPrimerDespacho;
  final DateTime? fechaUltimoDespacho;
  final double tiempoNetoDespachoHoras;
  final double tiempoEsperaPorComprasHoras;
  final int totalLotesDespachados;

  const MetricaBodegaEntity({
    this.fechaPrimerDespacho,
    this.fechaUltimoDespacho,
    this.tiempoNetoDespachoHoras = 0.0,
    this.tiempoEsperaPorComprasHoras = 0.0,
    this.totalLotesDespachados = 0,
  });

  MetricaBodegaEntity copyWith({
    DateTime? fechaPrimerDespacho,
    DateTime? fechaUltimoDespacho,
    double? tiempoNetoDespachoHoras,
    double? tiempoEsperaPorComprasHoras,
    int? totalLotesDespachados,
  }) {
    return MetricaBodegaEntity(
      fechaPrimerDespacho: fechaPrimerDespacho ?? this.fechaPrimerDespacho,
      fechaUltimoDespacho: fechaUltimoDespacho ?? this.fechaUltimoDespacho,
      tiempoNetoDespachoHoras:
          tiempoNetoDespachoHoras ?? this.tiempoNetoDespachoHoras,
      tiempoEsperaPorComprasHoras:
          tiempoEsperaPorComprasHoras ?? this.tiempoEsperaPorComprasHoras,
      totalLotesDespachados:
          totalLotesDespachados ?? this.totalLotesDespachados,
    );
  }

  @override
  List<Object?> get props => [
        fechaPrimerDespacho,
        fechaUltimoDespacho,
        tiempoNetoDespachoHoras,
        tiempoEsperaPorComprasHoras,
        totalLotesDespachados,
      ];
}

/// Métricas de ciclo para Taller / Proceso de Trabajo (discriminando mano de obra neta vs espera de repuestos).
class MetricaTallerEntity extends Equatable {
  final DateTime? fechaInicioTrabajo;
  final DateTime? fechaFinTrabajo;
  final double tiempoNetoTrabajoHoras;
  final double tiempoEsperaMaterialHoras;

  const MetricaTallerEntity({
    this.fechaInicioTrabajo,
    this.fechaFinTrabajo,
    this.tiempoNetoTrabajoHoras = 0.0,
    this.tiempoEsperaMaterialHoras = 0.0,
  });

  MetricaTallerEntity copyWith({
    DateTime? fechaInicioTrabajo,
    DateTime? fechaFinTrabajo,
    double? tiempoNetoTrabajoHoras,
    double? tiempoEsperaMaterialHoras,
  }) {
    return MetricaTallerEntity(
      fechaInicioTrabajo: fechaInicioTrabajo ?? this.fechaInicioTrabajo,
      fechaFinTrabajo: fechaFinTrabajo ?? this.fechaFinTrabajo,
      tiempoNetoTrabajoHoras:
          tiempoNetoTrabajoHoras ?? this.tiempoNetoTrabajoHoras,
      tiempoEsperaMaterialHoras:
          tiempoEsperaMaterialHoras ?? this.tiempoEsperaMaterialHoras,
    );
  }

  @override
  List<Object?> get props => [
        fechaInicioTrabajo,
        fechaFinTrabajo,
        tiempoNetoTrabajoHoras,
        tiempoEsperaMaterialHoras,
      ];
}

/// Contenedor unificado de telemetría de tiempos concurrentes para el Ticket.
class TiemposOperativosEntity extends Equatable {
  final double leadTimeTotalHoras;
  final SubEstadosEntity subEstados;
  final MetricaComprasEntity compras;
  final MetricaBodegaEntity bodega;
  final MetricaTallerEntity taller;

  const TiemposOperativosEntity({
    this.leadTimeTotalHoras = 0.0,
    this.subEstados = const SubEstadosEntity(),
    this.compras = const MetricaComprasEntity(),
    this.bodega = const MetricaBodegaEntity(),
    this.taller = const MetricaTallerEntity(),
  });

  TiemposOperativosEntity copyWith({
    double? leadTimeTotalHoras,
    SubEstadosEntity? subEstados,
    MetricaComprasEntity? compras,
    MetricaBodegaEntity? bodega,
    MetricaTallerEntity? taller,
  }) {
    return TiemposOperativosEntity(
      leadTimeTotalHoras: leadTimeTotalHoras ?? this.leadTimeTotalHoras,
      subEstados: subEstados ?? this.subEstados,
      compras: compras ?? this.compras,
      bodega: bodega ?? this.bodega,
      taller: taller ?? this.taller,
    );
  }

  @override
  List<Object?> get props => [
        leadTimeTotalHoras,
        subEstados,
        compras,
        bodega,
        taller,
      ];
}
