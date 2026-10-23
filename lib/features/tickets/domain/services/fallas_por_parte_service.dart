// lib/features/tickets/domain/services/fallas_por_parte_service.dart
//
// 🧩 Dashboard → "Fallas por parte": agrupa las fallas diagnosticadas por
// la parte del equipo (nivel intermedio del catálogo de Métricas de
// Fallas: Categoría → Parte → Falla; en los datos es `subcategoria`).
// Solo cálculo, sin Flutter ni Firebase; probado en
// test/fallas_por_parte_test.dart.
//
// - La parte se identifica junto con su categoría (la misma parte puede
//   existir en dos categorías), sin distinguir mayúsculas ni espacios.
// - Fallas guardadas sin parte (tickets anteriores) se agrupan como
//   "Sin parte" dentro de su categoría.
// - Fallas sin categoría se ignoran (igual que "Fallas por categoría").

/// Una falla diagnosticada en un ticket, con lo necesario para agruparla.
class FallaParaParte {
  final String categoria;
  final String parte;
  final String falla;
  final String ticketId;
  final String equipo;

  const FallaParaParte({
    required this.categoria,
    required this.parte,
    required this.falla,
    required this.ticketId,
    required this.equipo,
  });
}

/// Resumen de una parte: cuántas fallas tiene, en qué tickets y cuáles.
class ResumenParte {
  final String clave;
  final String claveCategoria;
  final String categoria;
  final String parte;
  final int fallas;
  final Map<String, Set<String>> ticketsPorEquipo;
  final Map<String, int> conteoPorFalla;

  const ResumenParte({
    required this.clave,
    required this.claveCategoria,
    required this.categoria,
    required this.parte,
    required this.fallas,
    required this.ticketsPorEquipo,
    required this.conteoPorFalla,
  });

  bool get esSinParte => parte == FallasPorParteService.sinParte;

  /// Fallas más repetidas de esta parte (de mayor a menor).
  List<MapEntry<String, int>> masComunes([int n = 3]) =>
      (conteoPorFalla.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).take(n).toList();
}

class FallasPorParteService {
  static const String sinParte = 'Sin parte';

  static String normalizar(String texto) => texto.trim().toLowerCase();

  /// Clave única de una parte dentro de su categoría.
  static String clave(String categoria, String parte) {
    final p = normalizar(parte);
    return '${normalizar(categoria)}|${p.isEmpty ? normalizar(sinParte) : p}';
  }

  /// Agrupa las fallas por parte, de la que tiene más fallas a la que menos.
  /// Con [claveCategoria] solo se consideran las fallas de esa categoría.
  static List<ResumenParte> agrupar(Iterable<FallaParaParte> fallas, {String? claveCategoria}) {
    final etiquetas = <String, ({String claveCategoria, String categoria, String parte})>{};
    final conteo = <String, int>{};
    final tickets = <String, Map<String, Set<String>>>{};
    final porFalla = <String, Map<String, int>>{};

    for (final f in fallas) {
      final cat = normalizar(f.categoria);
      if (cat.isEmpty) continue;
      if (claveCategoria != null && cat != claveCategoria) continue;
      final k = clave(f.categoria, f.parte);
      final parte = f.parte.trim();
      etiquetas.putIfAbsent(
        k,
        () => (claveCategoria: cat, categoria: f.categoria.trim(), parte: parte.isEmpty ? sinParte : parte),
      );
      conteo[k] = (conteo[k] ?? 0) + 1;
      tickets.putIfAbsent(k, () => {}).putIfAbsent(f.equipo, () => <String>{}).add(f.ticketId);
      final m = porFalla.putIfAbsent(k, () => <String, int>{});
      final falla = f.falla.trim();
      m[falla] = (m[falla] ?? 0) + 1;
    }

    final resumen = [
      for (final k in conteo.keys)
        ResumenParte(
          clave: k,
          claveCategoria: etiquetas[k]!.claveCategoria,
          categoria: etiquetas[k]!.categoria,
          parte: etiquetas[k]!.parte,
          fallas: conteo[k]!,
          ticketsPorEquipo: tickets[k]!,
          conteoPorFalla: porFalla[k]!,
        ),
    ];
    // Más fallas primero; a igual cantidad, orden alfabético y "Sin parte" al final.
    resumen.sort((a, b) {
      final porCantidad = b.fallas.compareTo(a.fallas);
      if (porCantidad != 0) return porCantidad;
      if (a.esSinParte != b.esSinParte) return a.esSinParte ? 1 : -1;
      return a.parte.toLowerCase().compareTo(b.parte.toLowerCase());
    });
    return resumen;
  }
}
