// lib/features/catalogo/domain/services/codigo_actividad_service.dart
//
// 🔢 Código sugerido para una actividad NUEVA del Plan Maestro de un equipo
// (botón "Agregar actividad al Plan Maestro" de la Evaluación Técnica):
// sigue el prefijo más usado del equipo (ej. MO010 → MO011, con el mismo
// ancho) y nunca repite uno existente. Solo reglas puras; probado en
// test/codigo_actividad_test.dart.

import '../entities/actividad_catalogo_entity.dart';

class CodigoActividadService {
  static const String porDefecto = 'MO001';
  static final RegExp _patron = RegExp(r'^([A-Za-z\-]*)(\d+)$');

  /// Códigos ya usados (en MAYÚSCULAS, sin espacios).
  static Set<String> ocupados(List<ActividadCatalogoEntity> actividades) =>
      {for (final a in actividades) a.codigo.trim().toUpperCase()};

  static String siguiente(List<ActividadCatalogoEntity> actividades) {
    final porPrefijo = <String, List<RegExpMatch>>{};
    for (final a in actividades) {
      final m = _patron.firstMatch(a.codigo.trim().toUpperCase());
      if (m != null) porPrefijo.putIfAbsent(m.group(1)!, () => []).add(m);
    }
    if (porPrefijo.isEmpty) return porDefecto;
    final prefijo = porPrefijo.entries.reduce((a, b) => b.value.length > a.value.length ? b : a).key;
    final numeros = porPrefijo[prefijo]!;
    final ancho = numeros.map((m) => m.group(2)!.length).reduce((a, b) => a > b ? a : b);
    var n = numeros.map((m) => int.parse(m.group(2)!)).reduce((a, b) => a > b ? a : b) + 1;
    final usados = ocupados(actividades);
    String codigo() => '$prefijo${n.toString().padLeft(ancho, '0')}';
    while (usados.contains(codigo())) {
      n++;
    }
    return codigo();
  }
}
