import '../../domain/entities/evidencia_trabajo_entity.dart'; // Ajuste la ruta según su proyecto

class EvidenciaTrabajoModel extends EvidenciaTrabajoEntity {
  const EvidenciaTrabajoModel({
    required super.fotosUrls,
    required super.videosUrls,
    super.notasTecnicas,
  });

  /// 📥 LECTURA: Desempaqueta los datos que llegan desde la base de datos (Firestore)
  factory EvidenciaTrabajoModel.fromJson(Map<String, dynamic> json) {
    return EvidenciaTrabajoModel(
      // Mapeo defensivo: Si el campo no existe o es null, inicializa una lista vacía
      fotosUrls: List<String>.from(json['fotosUrls'] ?? []),
      videosUrls: List<String>.from(json['videosUrls'] ?? []),
      notasTecnicas: json['notasTecnicas'] as String?,
    );
  }

  /// 🔄 CONVERSIÓN: Convierte la entidad abstracta de dominio en este modelo concreto de datos
  factory EvidenciaTrabajoModel.fromEntity(EvidenciaTrabajoEntity entity) {
    return EvidenciaTrabajoModel(
      fotosUrls: entity.fotosUrls,
      videosUrls: entity.videosUrls,
      notasTecnicas: entity.notasTecnicas,
    );
  }

  /// 📤 ESCRITURA: Empaqueta los datos en un mapa (JSON) listo para inyectarse en Firestore
  Map<String, dynamic> toJson() {
    return {
      'fotosUrls': fotosUrls,
      'videosUrls': videosUrls,
      'notasTecnicas': notasTecnicas,
    };
  }
}