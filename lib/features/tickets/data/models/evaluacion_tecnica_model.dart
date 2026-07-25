import '../../domain/entities/evaluacion_tecnica_entity.dart';

class EvaluacionTecnicaModel extends EvaluacionTecnicaEntity {
  const EvaluacionTecnicaModel({
    super.urlProformaExcel,
    required super.urlsAdjuntosPdf,
    super.observacion = '',
    super.numeroOVGarantia,
    super.urlsAdjuntosPdfGarantia,
  });

  factory EvaluacionTecnicaModel.fromJson(Map<String, dynamic> json) {
    return EvaluacionTecnicaModel(
      // ⚙️ CASTEO SEGURO: El Excel puede no existir, aceptamos null
      urlProformaExcel: json['urlProformaExcel'] as String?,
      
      // ⚙️ CASTEO ESTRICTO: Prevenimos fallos si Firestore no devuelve la lista
      urlsAdjuntosPdf: List<String>.from(json['urlsAdjuntosPdf'] ?? []),
      
      observacion: json['observacion'] ?? '',
      numeroOVGarantia: json['numeroOVGarantia'] ?? '',
      urlsAdjuntosPdfGarantia: List<String>.from(json['urlsAdjuntosPdfGarantia'] ?? []),
    );
  }

  factory EvaluacionTecnicaModel.fromEntity(EvaluacionTecnicaEntity entity) {
    return EvaluacionTecnicaModel(
      urlProformaExcel: entity.urlProformaExcel,
      urlsAdjuntosPdf: entity.urlsAdjuntosPdf,
      observacion: entity.observacion,
      numeroOVGarantia: entity.numeroOVGarantia,
      urlsAdjuntosPdfGarantia: entity.urlsAdjuntosPdfGarantia,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'urlProformaExcel': urlProformaExcel, // Si es null, Firestore no lo crea o lo guarda como null
      'urlsAdjuntosPdf': urlsAdjuntosPdf,
      'observacion': observacion,
      'numeroOVGarantia':numeroOVGarantia,
      'urlsAdjuntosPdfGarantia':urlsAdjuntosPdf,
    };
  }
}