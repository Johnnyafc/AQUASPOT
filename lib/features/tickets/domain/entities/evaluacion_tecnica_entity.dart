class EvaluacionTecnicaEntity {
  final List<String> documentosUrls;
  final String observacion; // 🔌 Nuevo pin de datos

  const EvaluacionTecnicaEntity({
    required this.documentosUrls,
    this.observacion = '', // Inicializado en vacío por si no escriben nada
  });
}