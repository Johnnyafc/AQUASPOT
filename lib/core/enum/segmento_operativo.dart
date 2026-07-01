enum SegmentoOperativo {
  contador,
  cosechadora,
  caracol,
  general, 
  ninguno, 
}

// Función helper obligatoria para parsear lo que venga de Firebase
SegmentoOperativo parseSegmento(String? valor) {
  if (valor == null) return SegmentoOperativo.ninguno;
  return SegmentoOperativo.values.firstWhere(
    (e) => e.name.toLowerCase() == valor.toLowerCase(),
    orElse: () => SegmentoOperativo.ninguno,
  );
}