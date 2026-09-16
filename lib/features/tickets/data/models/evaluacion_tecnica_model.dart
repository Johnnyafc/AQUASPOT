import '../../domain/entities/evaluacion_tecnica_entity.dart';
import 'actividad_registrada_model.dart';
import 'repuesto_registrado_model.dart';

class EvaluacionTecnicaModel extends EvaluacionTecnicaEntity {
  const EvaluacionTecnicaModel({
    super.urlProformaExcel,
    required super.urlsAdjuntosPdf,
    super.observacion = '',
    super.numeroOVGarantia,
    super.urlsAdjuntosPdfGarantia,
    super.urlPdfRevisionTecnicaAntigua,
    super.totalHorasHombre,
    super.actividades = const [],
    super.repuestosTaller = const [],
    super.repuestosComercial = const [],
  });

  factory EvaluacionTecnicaModel.fromJson(Map<String, dynamic> json) {
    final rawActividades = json['actividades'] as List<dynamic>? ?? [];
    final rawTaller = json['repuestosTaller'] as List<dynamic>? ?? [];
    final rawComercial = json['repuestosComercial'] as List<dynamic>? ?? [];

    return EvaluacionTecnicaModel(
      // ⚙️ CASTEO SEGURO: El Excel puede no existir, aceptamos null
      urlProformaExcel: json['urlProformaExcel'] as String?,
      
      // ⚙️ CASTEO ESTRICTO: Prevenimos fallos si Firestore no devuelve la lista
      urlsAdjuntosPdf: List<String>.from(json['urlsAdjuntosPdf'] ?? []),
      
      observacion: json['observacion'] ?? '',
      numeroOVGarantia: json['numeroOVGarantia'] ?? '',
      urlsAdjuntosPdfGarantia: List<String>.from(json['urlsAdjuntosPdfGarantia'] ?? []),
      urlPdfRevisionTecnicaAntigua: json['urlPdfRevisionTecnicaAntigua'] as String?,
      totalHorasHombre: (json['totalHorasHombre'] as num?)?.toDouble(),
      
      actividades: rawActividades
          .map((e) => ActividadRegistradaModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      repuestosTaller: rawTaller
          .map((e) => RepuestoRegistradoModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      repuestosComercial: rawComercial
          .map((e) => RepuestoRegistradoModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }

  factory EvaluacionTecnicaModel.fromEntity(EvaluacionTecnicaEntity entity) {
    return EvaluacionTecnicaModel(
      urlProformaExcel: entity.urlProformaExcel,
      urlsAdjuntosPdf: entity.urlsAdjuntosPdf,
      observacion: entity.observacion,
      numeroOVGarantia: entity.numeroOVGarantia,
      urlsAdjuntosPdfGarantia: entity.urlsAdjuntosPdfGarantia,
      urlPdfRevisionTecnicaAntigua: entity.urlPdfRevisionTecnicaAntigua,
      totalHorasHombre: entity.totalHorasHombre,
      actividades: entity.actividades,
      repuestosTaller: entity.repuestosTaller,
      repuestosComercial: entity.repuestosComercial,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'urlProformaExcel': urlProformaExcel,
      'urlsAdjuntosPdf': urlsAdjuntosPdf,
      'observacion': observacion,
      'numeroOVGarantia': numeroOVGarantia,
      'urlsAdjuntosPdfGarantia': urlsAdjuntosPdfGarantia,
      'urlPdfRevisionTecnicaAntigua': urlPdfRevisionTecnicaAntigua,
      'totalHorasHombre': totalHorasHombre,
      'actividades': actividades
          .map((e) => ActividadRegistradaModel.fromEntity(e).toJson())
          .toList(),
      'repuestosTaller': repuestosTaller
          .map((e) => RepuestoRegistradoModel.fromEntity(e).toJson())
          .toList(),
      'repuestosComercial': repuestosComercial
          .map((e) => RepuestoRegistradoModel.fromEntity(e).toJson())
          .toList(),
    };
  }
}
