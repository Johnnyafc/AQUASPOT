import 'package:equatable/equatable.dart';
import 'actividad_registrada_entity.dart';
import 'repuesto_registrado_entity.dart';

class EvaluacionTecnicaEntity extends Equatable {
  final String? urlProformaExcel;     // 🎯 Canal exclusivo para Compras
  final List<String> urlsAdjuntosPdf; // 📂 Canal de respaldo técnico
  final String observacion;
  final String? numeroOVGarantia;
  final List<String>? urlsAdjuntosPdfGarantia;
  final String? urlPdfRevisionTecnicaAntigua;
  
  // 🚀 CAMPOS ESTRUCTURADOS (Plan Maestro y Repuestos Consolidados)
  final double? totalHorasHombre;
  final List<ActividadRegistradaEntity> actividades;
  final List<RepuestoRegistradoEntity> repuestosTaller;
  final List<RepuestoRegistradoEntity> repuestosComercial;

  const EvaluacionTecnicaEntity({
    this.urlProformaExcel,
    required this.urlsAdjuntosPdf,
    this.observacion = '',
    this.numeroOVGarantia,
    this.urlsAdjuntosPdfGarantia,
    this.urlPdfRevisionTecnicaAntigua,
    this.totalHorasHombre,
    this.actividades = const [],
    this.repuestosTaller = const [],
    this.repuestosComercial = const [],
  });

  EvaluacionTecnicaEntity copyWith({
    String? urlProformaExcel,
    List<String>? urlsAdjuntosPdf,
    String? observacion,
    String? numeroOVGarantia,
    List<String>? urlsAdjuntosPdfGarantia,
    String? urlPdfRevisionTecnicaAntigua,
    double? totalHorasHombre,
    List<ActividadRegistradaEntity>? actividades,
    List<RepuestoRegistradoEntity>? repuestosTaller,
    List<RepuestoRegistradoEntity>? repuestosComercial,
  }) {
    return EvaluacionTecnicaEntity(
      urlProformaExcel: urlProformaExcel ?? this.urlProformaExcel,
      urlsAdjuntosPdf: urlsAdjuntosPdf ?? this.urlsAdjuntosPdf,
      observacion: observacion ?? this.observacion,
      numeroOVGarantia: numeroOVGarantia ?? this.numeroOVGarantia,
      urlsAdjuntosPdfGarantia: urlsAdjuntosPdfGarantia ?? this.urlsAdjuntosPdfGarantia,
      urlPdfRevisionTecnicaAntigua: urlPdfRevisionTecnicaAntigua ?? this.urlPdfRevisionTecnicaAntigua,
      totalHorasHombre: totalHorasHombre ?? this.totalHorasHombre,
      actividades: actividades ?? this.actividades,
      repuestosTaller: repuestosTaller ?? this.repuestosTaller,
      repuestosComercial: repuestosComercial ?? this.repuestosComercial,
    );
  }

  @override
  List<Object?> get props => [
        urlProformaExcel,
        urlsAdjuntosPdf,
        observacion,
        numeroOVGarantia,
        urlsAdjuntosPdfGarantia,
        urlPdfRevisionTecnicaAntigua,
        totalHorasHombre,
        actividades,
        repuestosTaller,
        repuestosComercial,
      ];
}
