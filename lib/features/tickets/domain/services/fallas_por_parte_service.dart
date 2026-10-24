// lib/features/tickets/domain/services/fallas_por_parte_service.dart
//
// 🧩 Dashboard → "Diagnóstico de fallas": agrupa las fallas diagnosticadas
// por categoría, por parte del equipo (nivel intermedio del catálogo de
// Métricas de Fallas: Categoría → Parte → Falla; en los datos es
// `subcategoria`) y por razón del problema, para el pastel General y uno
// por equipo. Solo cálculo, sin Flutter ni Firebase; probado en
// test/fallas_por_parte_test.dart.
//
// - La parte se identifica junto con su categoría (la misma parte puede
//   existir en dos categorías), sin distinguir mayúsculas ni espacios.
// - Fallas guardadas sin parte (tickets anteriores) se agrupan como
//   "Sin parte" dentro de su categoría.
// - Fallas sin categoría se ignoran.
// - Razones: las del catálogo estándar con su nombre; el resto como
//   "Otras (texto libre)". Una falla puede tener varias razones.
// - "Fallas más frecuentes": cada falla con la categoría y la parte de las
//   que deriva (la misma falla en dos partes son dos filas).
// - La categoría / parte elegidas en los pasteles también filtran Garantías
//   y Detalle: cuentan los tickets con al menos una falla de esa categoría /
//   parte (seleccionVigente + ticketsCon).

import '../../../../core/utils/constants.dart' show razonesProblemaEstandar;

/// Una falla diagnosticada en un ticket, con lo necesario para agruparla.
class FallaParaParte {
  final String categoria;
  final String parte;
  final String falla;
  final List<String> razones;
  final String ticketId;
  final String equipo;

  const FallaParaParte({
    required this.categoria,
    required this.parte,
    required this.falla,
    this.razones = const [],
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
  List<MapEntry<String, int>> masComunes([int n = 3]) => FallasPorParteService._top(conteoPorFalla, n);
}

/// Resumen de una categoría o de una razón del problema.
/// - Categoría: [valor] = fallas; [conteoDetalle] = fallas por nombre.
/// - Razón: [valor] = veces marcada; [fallas] = fallas que la tienen;
///   [conteoDetalle] = en qué categorías aparece.
class ResumenGrupo {
  final String clave;
  final String etiqueta;
  final int valor;
  final int fallas;
  final Map<String, Set<String>> ticketsPorEquipo;
  final Map<String, int> conteoDetalle;

  const ResumenGrupo({
    required this.clave,
    required this.etiqueta,
    required this.valor,
    required this.fallas,
    required this.ticketsPorEquipo,
    required this.conteoDetalle,
  });

  List<MapEntry<String, int>> masComunes([int n = 3]) => FallasPorParteService._top(conteoDetalle, n);
}

/// Una falla con la categoría y la parte de las que deriva, y cuántas veces
/// se diagnosticó.
class ResumenFalla {
  final String clave;
  final String categoria;
  final String parte;
  final String falla;
  final int veces;

  const ResumenFalla({
    required this.clave,
    required this.categoria,
    required this.parte,
    required this.falla,
    required this.veces,
  });

  bool get esSinParte => parte == FallasPorParteService.sinParte;
}

class FallasPorParteService {
  static const String sinParte = 'Sin parte';
  static const String otrasRazones = 'Otras (texto libre)';
  // Orden fijo de los pasteles por equipo; otro equipo con datos va al final.
  static const List<String> equiposBase = ['Cosechadora', 'Contador', 'Caracol'];

  static String normalizar(String texto) => texto.trim().toLowerCase();

  /// Clave única de una parte dentro de su categoría.
  static String clave(String categoria, String parte) {
    final p = normalizar(parte);
    return '${normalizar(categoria)}|${p.isEmpty ? normalizar(sinParte) : p}';
  }

  static List<MapEntry<String, int>> _top(Map<String, int> conteo, int n) =>
      (conteo.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).take(n).toList();

  /// Equipos para los pasteles: los 3 base siempre y, al final, cualquier
  /// otro que tenga fallas (ej. "Otros").
  static List<String> equiposDe(Iterable<FallaParaParte> fallas) {
    final extra = fallas.map((f) => f.equipo).where((e) => e.isNotEmpty && !equiposBase.contains(e)).toSet().toList()
      ..sort();
    return [...equiposBase, ...extra];
  }

  /// Fallas de un equipo (null = todos), de una categoría y de una parte
  /// (claves de [normalizar] y [clave]; null = sin filtro).
  static List<FallaParaParte> filtrar(
    Iterable<FallaParaParte> fallas, {
    String? equipo,
    String? claveCategoria,
    String? claveParte,
  }) {
    return fallas.where((f) {
      if (equipo != null && f.equipo != equipo) return false;
      if (claveCategoria != null && normalizar(f.categoria) != claveCategoria) return false;
      if (claveParte != null && clave(f.categoria, f.parte) != claveParte) return false;
      return true;
    }).toList();
  }

  /// Categoría y parte elegidas que siguen existiendo en [fallas] (las que ya
  /// no existen con los filtros actuales se ignoran), con su etiqueta
  /// "Categoría" o "Categoría › Parte". Sin nada vigente: todo null.
  static ({String? claveCategoria, String? claveParte, String? etiqueta}) seleccionVigente(
    Iterable<FallaParaParte> fallas, {
    String? claveCategoria,
    String? claveParte,
  }) {
    const ninguna = (claveCategoria: null, claveParte: null, etiqueta: null);
    if (claveCategoria == null) return ninguna;
    final categoria = agruparCategorias(fallas).where((c) => c.clave == claveCategoria).firstOrNull;
    if (categoria == null) return ninguna;
    final parte = claveParte == null
        ? null
        : agrupar(fallas, claveCategoria: claveCategoria).where((p) => p.clave == claveParte).firstOrNull;
    return (
      claveCategoria: claveCategoria,
      claveParte: parte?.clave,
      etiqueta: parte == null ? categoria.etiqueta : '${parte.categoria} › ${parte.parte}',
    );
  }

  /// Tickets con al menos una falla de esa categoría (y parte, si se da).
  static Set<String> ticketsCon(Iterable<FallaParaParte> fallas, {required String claveCategoria, String? claveParte}) =>
      filtrar(fallas, claveCategoria: claveCategoria, claveParte: claveParte).map((f) => f.ticketId).toSet();

  /// Agrupa las fallas por categoría, de la que tiene más fallas a la que menos.
  static List<ResumenGrupo> agruparCategorias(Iterable<FallaParaParte> fallas) {
    final etiquetas = <String, String>{};
    final conteo = <String, int>{};
    final tickets = <String, Map<String, Set<String>>>{};
    final porFalla = <String, Map<String, int>>{};
    for (final f in fallas) {
      final k = normalizar(f.categoria);
      if (k.isEmpty) continue;
      etiquetas.putIfAbsent(k, () => f.categoria.trim());
      conteo[k] = (conteo[k] ?? 0) + 1;
      tickets.putIfAbsent(k, () => {}).putIfAbsent(f.equipo, () => <String>{}).add(f.ticketId);
      final m = porFalla.putIfAbsent(k, () => <String, int>{});
      m[f.falla.trim()] = (m[f.falla.trim()] ?? 0) + 1;
    }
    final resumen = [
      for (final k in conteo.keys)
        ResumenGrupo(
          clave: k,
          etiqueta: etiquetas[k]!,
          valor: conteo[k]!,
          fallas: conteo[k]!,
          ticketsPorEquipo: tickets[k]!,
          conteoDetalle: porFalla[k]!,
        ),
    ];
    resumen.sort((a, b) {
      final porCantidad = b.valor.compareTo(a.valor);
      return porCantidad != 0 ? porCantidad : a.etiqueta.toLowerCase().compareTo(b.etiqueta.toLowerCase());
    });
    return resumen;
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

  /// Agrupa las fallas por categoría › parte › falla, de la más diagnosticada
  /// a la menos (a igual cantidad, por nombre de la falla).
  static List<ResumenFalla> agruparFallas(Iterable<FallaParaParte> fallas) {
    final primeras = <String, FallaParaParte>{};
    final veces = <String, int>{};
    for (final f in fallas) {
      if (normalizar(f.categoria).isEmpty || f.falla.trim().isEmpty) continue;
      final k = '${clave(f.categoria, f.parte)}|${normalizar(f.falla)}';
      primeras.putIfAbsent(k, () => f);
      veces[k] = (veces[k] ?? 0) + 1;
    }
    final resumen = [
      for (final k in veces.keys)
        ResumenFalla(
          clave: k,
          categoria: primeras[k]!.categoria.trim(),
          parte: primeras[k]!.parte.trim().isEmpty ? sinParte : primeras[k]!.parte.trim(),
          falla: primeras[k]!.falla.trim(),
          veces: veces[k]!,
        ),
    ];
    resumen.sort((a, b) {
      final porCantidad = b.veces.compareTo(a.veces);
      return porCantidad != 0 ? porCantidad : a.falla.toLowerCase().compareTo(b.falla.toLowerCase());
    });
    return resumen;
  }

  /// Agrupa las razones del problema marcadas, de la más marcada a la menos.
  /// La clave es el nombre del catálogo estándar u [otrasRazones].
  static List<ResumenGrupo> agruparRazones(Iterable<FallaParaParte> fallas) {
    final estandar = {for (final r in razonesProblemaEstandar) normalizar(r): r};
    final marcas = <String, int>{};
    final fallasConRazon = <String, int>{};
    final tickets = <String, Map<String, Set<String>>>{};
    final porCategoria = <String, Map<String, int>>{};
    for (final f in fallas) {
      if (normalizar(f.categoria).isEmpty) continue;
      final vistas = <String>{};
      for (final razon in f.razones) {
        if (razon.trim().isEmpty) continue;
        final et = estandar[normalizar(razon)] ?? otrasRazones;
        marcas[et] = (marcas[et] ?? 0) + 1;
        if (vistas.add(et)) {
          fallasConRazon[et] = (fallasConRazon[et] ?? 0) + 1;
          tickets.putIfAbsent(et, () => {}).putIfAbsent(f.equipo, () => <String>{}).add(f.ticketId);
          final c = porCategoria.putIfAbsent(et, () => <String, int>{});
          final cat = f.categoria.trim();
          c[cat] = (c[cat] ?? 0) + 1;
        }
      }
    }
    final resumen = [
      for (final et in marcas.keys)
        ResumenGrupo(
          clave: et,
          etiqueta: et,
          valor: marcas[et]!,
          fallas: fallasConRazon[et]!,
          ticketsPorEquipo: tickets[et]!,
          conteoDetalle: porCategoria[et]!,
        ),
    ];
    resumen.sort((a, b) {
      final porCantidad = b.valor.compareTo(a.valor);
      return porCantidad != 0 ? porCantidad : a.etiqueta.toLowerCase().compareTo(b.etiqueta.toLowerCase());
    });
    return resumen;
  }
}
