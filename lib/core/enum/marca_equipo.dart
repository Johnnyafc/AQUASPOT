enum MarcaEquipo {
  aquaspot,
  seinmex,
  iosa,
  aqualife,
  valei,
  otros,
}

extension MarcaEquipoExtension on MarcaEquipo {
  // Para mostrar en la UI y guardar en Firestore
  String get valor {
    switch (this) {
      case MarcaEquipo.aquaspot: return 'AQUASPOT';
      case MarcaEquipo.seinmex: return 'SEINMEX';
      case MarcaEquipo.iosa: return 'IOSA';
      case MarcaEquipo.aqualife: return 'AQUALIFE';
      case MarcaEquipo.valei: return 'VALEI';
      case MarcaEquipo.otros: return 'OTROS';
    }
  }

  // Factory para deserializar desde Firestore
  static MarcaEquipo fromString(String marca) {
    return MarcaEquipo.values.firstWhere(
      (e) => e.valor == marca.toUpperCase(),
      orElse: () => MarcaEquipo.otros, // Fallback seguro
    );
  }
}