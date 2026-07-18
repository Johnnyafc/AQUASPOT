import 'package:aquaspot_postventa/features/tickets/domain/entities/proforma_entity.dart';

class ProformaModel extends ProformaEntity {
  const ProformaModel({
    super.pdfUrls = const [],
    super.excelUrls = const [],
    required super.observacion,
  });

  factory ProformaModel.fromJson(Map<String, dynamic> json) {
    return ProformaModel(
      // 📥 Transformamos las listas genéricas de JSON a List<String> de Dart
      pdfUrls: List<String>.from(json['pdfUrls'] ?? []),
      excelUrls: List<String>.from(json['excelUrls'] ?? []),
      observacion: json['observacion'] ?? 'Sin observaciones',
    );
  }

factory ProformaModel.fromEntity(ProformaEntity entity) {
    return ProformaModel(
      pdfUrls: entity.pdfUrls,
      excelUrls: entity.excelUrls,
      observacion: entity.observacion,
    );
  }
  Map<String, dynamic> toJson() {
    return {
      'pdfUrls': pdfUrls,
      'excelUrls': excelUrls,
      'observacion': observacion,
    };
  }
}