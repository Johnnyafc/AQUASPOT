// lib/features/catalogo/domain/services/revision_codigos_plan_maestro_service.dart
//
// 🔎 "Revisión de Códigos del Plan Maestro": compara los ítems (repuestos e
// insumos, internos y comerciales) de las actividades del catálogo de UN
// equipo contra el inventario de Bodega, y sugiere los códigos del
// inventario más parecidos. Sin Firebase: todo en memoria, probado en
// test/revision_codigos_plan_maestro_test.dart.

import '../../../inventario/domain/entities/item_inventario_entity.dart';
import '../entities/actividad_catalogo_entity.dart';
import '../entities/item_catalogo_entity.dart';

enum EstadoCodigoPlan { noExiste, descripcionDistinta, sinCodigo, coincide }

/// Dónde aparece un ítem del plan: actividad + lista (interna o comercial).
class UsoItemPlan {
  final String actividadId;
  final String actividadCodigo;
  final String actividadNombre;
  final bool esComercial;
  final ItemCatalogoEntity item;

  const UsoItemPlan({
    required this.actividadId,
    required this.actividadCodigo,
    required this.actividadNombre,
    required this.esComercial,
    required this.item,
  });
}

/// Una fila de la revisión: un código del plan (o un ítem sin código,
/// agrupado por descripción) con todas las actividades donde se usa.
class RevisionCodigoPlan {
  final String codigo; // tal como está en el plan ('' si no tiene)
  final EstadoCodigoPlan estado;
  final List<String> descripcionesPlan; // distintas, en orden de aparición
  final String unidadPlan;
  final ItemInventarioEntity? inventario;
  final List<UsoItemPlan> usos;

  const RevisionCodigoPlan({
    required this.codigo,
    required this.estado,
    required this.descripcionesPlan,
    required this.unidadPlan,
    required this.inventario,
    required this.usos,
  });

  String get descripcionPlan => descripcionesPlan.isEmpty ? '' : descripcionesPlan.first;

  /// ⚠️ El mismo código tiene descripciones distintas dentro del equipo.
  bool get descripcionesInconsistentes => descripcionesPlan.length > 1;

  List<String> get actividadIds => usos.map((u) => u.actividadId).toSet().toList();

  int get numActividades => actividadIds.length;
}

class ResultadoRevisionPlan {
  final List<RevisionCodigoPlan> filas;
  final List<UsoItemPlan> excluidos; // servicios / mano de obra

  const ResultadoRevisionPlan({required this.filas, required this.excluidos});

  int contar(EstadoCodigoPlan e) => filas.where((f) => f.estado == e).length;
}

class SugerenciaCodigo {
  final ItemInventarioEntity item;
  final double puntaje; // 0..1

  const SugerenciaCodigo({required this.item, required this.puntaje});
}

class RevisionCodigosPlanMaestroService {
  /// Prefijos de código (letras antes del primer número) que NO son de
  /// bodega. Ajustar aquí si Contador o Cosechadora usan otros.
  static const List<String> prefijosExcluidos = ['SER', 'MO'];

  /// Descripciones que NO son de bodega (se compara el inicio, ya normalizado).
  static const List<String> descripcionesExcluidas = ['SERVICIO', 'MANO DE OBRA'];

  /// Desde este parecido las descripciones del plan y del inventario se
  /// consideran la misma (tolera tildes, orden y palabras sueltas).
  static const double umbralDescripcionCoincide = 0.8;

  static const Set<String> _conectores = {
    'DE', 'DEL', 'LA', 'EL', 'LOS', 'LAS', 'PARA', 'CON', 'Y', 'EN', 'A', 'AL', 'X', 'POR',
  };

  static String normalizarCodigo(String codigo) => codigo.trim().toUpperCase();

  /// Mayúsculas, sin tildes, solo letras/números separados por un espacio.
  static String normalizarTexto(String texto) {
    const conTilde = 'ÁÉÍÓÚÀÈÌÒÙÄËÏÖÜÂÊÎÔÛÑ';
    const sinTilde = 'AEIOUAEIOUAEIOUAEIOUN';
    final buffer = StringBuffer();
    for (final ch in texto.toUpperCase().split('')) {
      final i = conTilde.indexOf(ch);
      final c = i >= 0 ? sinTilde[i] : ch;
      buffer.write(RegExp(r'[A-Z0-9]').hasMatch(c) ? c : ' ');
    }
    return buffer.toString().trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  static String _prefijoLetras(String codigo) =>
      RegExp(r'^[A-Z]+').firstMatch(normalizarCodigo(codigo))?.group(0) ?? '';

  /// Servicios y mano de obra: no se buscan en el inventario.
  static bool esExcluido(ItemCatalogoEntity item) {
    final codigo = normalizarCodigo(item.codigo);
    if (codigo.isNotEmpty && prefijosExcluidos.contains(_prefijoLetras(codigo))) {
      // Solo si después de las letras viene un número o separador (evita
      // excluir p. ej. un "MOT000…").
      final resto = codigo.substring(_prefijoLetras(codigo).length);
      if (resto.isEmpty || RegExp(r'^[0-9\-_ .]').hasMatch(resto)) return true;
    }
    final desc = normalizarTexto(item.descripcion);
    return descripcionesExcluidas.any((d) => desc.startsWith(d));
  }

  static Set<String> _palabras(String texto) =>
      normalizarTexto(texto).split(' ').where((p) => p.isNotEmpty && !_conectores.contains(p)).toSet();

  /// Coeficiente de Dice sobre las palabras (0..1).
  static double similitudDescripcion(String a, String b) {
    final pa = _palabras(a);
    final pb = _palabras(b);
    if (pa.isEmpty || pb.isEmpty) return 0;
    final comunes = pa.intersection(pb).length;
    return 2 * comunes / (pa.length + pb.length);
  }

  static int _levenshtein(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;
    var previa = List<int>.generate(b.length + 1, (i) => i);
    for (var i = 1; i <= a.length; i++) {
      final actual = List<int>.filled(b.length + 1, 0);
      actual[0] = i;
      for (var j = 1; j <= b.length; j++) {
        final costo = a[i - 1] == b[j - 1] ? 0 : 1;
        actual[j] = [previa[j] + 1, actual[j - 1] + 1, previa[j - 1] + costo].reduce((x, y) => x < y ? x : y);
      }
      previa = actual;
    }
    return previa[b.length];
  }

  /// Parecido entre códigos (0..1):
  /// - iguales → 1
  /// - iguales sin guiones/espacios/puntos → 0.97
  /// - mismas letras y mismo número (ceros de más o de menos) → 0.95
  /// - si no, parecido por letras cambiadas, reducido.
  static double similitudCodigo(String a, String b) {
    final ca = normalizarCodigo(a);
    final cb = normalizarCodigo(b);
    if (ca.isEmpty || cb.isEmpty) return 0;
    if (ca == cb) return 1;
    final la = ca.replaceAll(RegExp(r'[^A-Z0-9]'), '');
    final lb = cb.replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (la == lb) return 0.97;
    final ma = RegExp(r'^([A-Z]+)0*([0-9]+)$').firstMatch(la);
    final mb = RegExp(r'^([A-Z]+)0*([0-9]+)$').firstMatch(lb);
    if (ma != null && mb != null && ma.group(1) == mb.group(1) && ma.group(2) == mb.group(2)) {
      return 0.95;
    }
    final largo = la.length > lb.length ? la.length : lb.length;
    final parecido = 1 - _levenshtein(la, lb) / largo;
    return parecido < 0 ? 0 : parecido * 0.6;
  }

  /// Puntaje combinado de una sugerencia (0..1). Si el código es casi el
  /// mismo pesa más el código; si no, manda la descripción.
  static double puntaje({
    required String codigoPlan,
    required String descripcionPlan,
    required ItemInventarioEntity item,
  }) {
    final sc = similitudCodigo(codigoPlan, item.codigo);
    final sd = similitudDescripcion(descripcionPlan, item.descripcion);
    return sc >= 0.9 ? 0.7 * sc + 0.3 * sd : 0.85 * sd + 0.15 * sc;
  }

  /// Los [maximo] ítems del inventario más parecidos al ítem del plan.
  static List<SugerenciaCodigo> sugerir({
    required String codigoPlan,
    required String descripcionPlan,
    required List<ItemInventarioEntity> inventario,
    int maximo = 5,
  }) {
    final propio = normalizarCodigo(codigoPlan);
    final lista = <SugerenciaCodigo>[];
    for (final item in inventario) {
      final cod = normalizarCodigo(item.codigo);
      // El mismo código no se sugiere: para dejarlo y solo corregir la
      // descripción está el botón "Editar".
      if (cod.isEmpty || cod == propio) continue;
      final p = puntaje(codigoPlan: codigoPlan, descripcionPlan: descripcionPlan, item: item);
      if (p <= 0) continue;
      lista.add(SugerenciaCodigo(item: item, puntaje: p));
    }
    lista.sort((a, b) => b.puntaje.compareTo(a.puntaje));
    return lista.take(maximo).toList();
  }

  /// Arma la revisión de las actividades de UN equipo contra el inventario.
  static ResultadoRevisionPlan revisar({
    required List<ActividadCatalogoEntity> actividades,
    required List<ItemInventarioEntity> inventario,
  }) {
    final porCodigo = <String, ItemInventarioEntity>{};
    for (final item in inventario) {
      final cod = normalizarCodigo(item.codigo);
      if (cod.isNotEmpty) porCodigo.putIfAbsent(cod, () => item);
    }

    // Clave de agrupación: el código; los sin código, por descripción.
    final grupos = <String, List<UsoItemPlan>>{};
    final excluidos = <UsoItemPlan>[];
    for (final act in actividades) {
      void agregar(ItemCatalogoEntity item, bool esComercial) {
        final uso = UsoItemPlan(
          actividadId: act.id,
          actividadCodigo: act.codigo,
          actividadNombre: act.nombre,
          esComercial: esComercial,
          item: item,
        );
        if (esExcluido(item)) {
          excluidos.add(uso);
          return;
        }
        final cod = normalizarCodigo(item.codigo);
        final clave = cod.isNotEmpty ? 'C|$cod' : 'S|${normalizarTexto(item.descripcion)}';
        grupos.putIfAbsent(clave, () => []).add(uso);
      }

      for (final i in act.itemsInternos) {
        agregar(i, false);
      }
      for (final i in act.itemsComerciales) {
        agregar(i, true);
      }
    }

    final filas = <RevisionCodigoPlan>[];
    grupos.forEach((clave, usos) {
      final descripciones = <String>[];
      final vistas = <String>{};
      for (final u in usos) {
        final d = u.item.descripcion.trim();
        if (vistas.add(normalizarTexto(d))) descripciones.add(d);
      }
      final codigo = usos.first.item.codigo.trim();
      final inv = codigo.isEmpty ? null : porCodigo[normalizarCodigo(codigo)];

      EstadoCodigoPlan estado;
      if (codigo.isEmpty) {
        estado = EstadoCodigoPlan.sinCodigo;
      } else if (inv == null) {
        estado = EstadoCodigoPlan.noExiste;
      } else {
        final todasCoinciden = descripciones
            .every((d) => similitudDescripcion(d, inv.descripcion) >= umbralDescripcionCoincide);
        estado = todasCoinciden ? EstadoCodigoPlan.coincide : EstadoCodigoPlan.descripcionDistinta;
      }

      filas.add(RevisionCodigoPlan(
        codigo: codigo,
        estado: estado,
        descripcionesPlan: descripciones,
        unidadPlan: usos.first.item.unidad,
        inventario: inv,
        usos: usos,
      ));
    });

    // 🔴 → 🟠 → ⚪ → 🟢; dentro de cada grupo, los más usados primero.
    filas.sort((a, b) {
      final e = a.estado.index.compareTo(b.estado.index);
      if (e != 0) return e;
      final n = b.numActividades.compareTo(a.numActividades);
      if (n != 0) return n;
      return a.codigo.compareTo(b.codigo);
    });

    return ResultadoRevisionPlan(filas: filas, excluidos: excluidos);
  }

  /// Reemplaza, en la lista de ítems de una actividad, los que corresponden
  /// a la fila (mismo código; o, si no tiene código, misma descripción)
  /// por el código/descripción/unidad nuevos. Conserva la cantidad; si
  /// [descripcionNueva] o [unidadNueva] son null, cada ítem conserva la suya.
  /// Devuelve null si no hubo nada que cambiar.
  static List<Map<String, dynamic>>? reemplazarEnLista({
    required List<Map<String, dynamic>> items,
    required String codigoAnterior,
    required String descripcionAnterior,
    required String codigoNuevo,
    String? descripcionNueva,
    String? unidadNueva,
  }) {
    final codAnt = normalizarCodigo(codigoAnterior);
    final descAnt = normalizarTexto(descripcionAnterior);
    var cambio = false;
    final resultado = items.map((raw) {
      final item = Map<String, dynamic>.from(raw);
      final cod = normalizarCodigo(item['codigo'] as String? ?? '');
      final coincide = codAnt.isNotEmpty
          ? cod == codAnt
          : cod.isEmpty && normalizarTexto(item['descripcion'] as String? ?? '') == descAnt;
      if (!coincide) return item;
      cambio = true;
      item['codigo'] = codigoNuevo.trim();
      if (descripcionNueva != null) item['descripcion'] = descripcionNueva.trim();
      if (unidadNueva != null) item['unidad'] = unidadNueva.trim();
      return item;
    }).toList();
    return cambio ? resultado : null;
  }

  /// Huella de una lista de ítems para comparar (el orden de las claves de
  /// un mapa de Firestore no está garantizado).
  static String huellaItems(List<dynamic> items) => items.map((raw) {
        final m = Map<String, dynamic>.from(raw as Map);
        return '${m['codigo']}|${m['descripcion']}|${m['unidad']}|${m['cantidad']}';
      }).join('§');
}
