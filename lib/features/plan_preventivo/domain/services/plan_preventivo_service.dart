// lib/features/plan_preventivo/domain/services/plan_preventivo_service.dart
//
// 🗓️ Reglas del PLAN PREVENTIVO (solo reglas puras, sin Flutter ni
// Firebase; probado en test/plan_preventivo_test.dart):
// - Frecuencia según la máquina: horas (cosechadora), km (vehículo) y días
//   (contador, caracol, aire acondicionado y herramientas).
// - Código PREV-01, PREV-02… correlativo por máquina (cuenta también las
//   desactivadas, para no repetir un código).
// - Nombre en MAYÚSCULAS (mínimo 3 caracteres), horas hombre y frecuencia
//   mayores a 0, repuestos solo del inventario (con código) y cantidad > 0.
// - Solo supervisor y admin lo administran.

import '../../../../core/enum/rol_usuario.dart';
import '../../../inventario/domain/entities/item_inventario_entity.dart';
import '../../../tickets/domain/entities/mantenimiento_interno_entity.dart';
import '../../../tickets/domain/entities/repuesto_registrado_entity.dart';
import '../entities/actividad_preventiva_entity.dart';

enum UnidadFrecuencia { horas, km, dias }

extension UnidadFrecuenciaX on UnidadFrecuencia {
  /// "250 h", "5000 km", "30 días".
  String get sufijo => switch (this) {
        UnidadFrecuencia.horas => 'h',
        UnidadFrecuencia.km => 'km',
        UnidadFrecuencia.dias => 'días',
      };

  String get etiqueta => switch (this) {
        UnidadFrecuencia.horas => 'Horas de uso (horómetro)',
        UnidadFrecuencia.km => 'Kilómetros recorridos',
        UnidadFrecuencia.dias => 'Días',
      };
}

class PlanPreventivoService {
  static const String prefijoCodigo = 'PREV-';
  static const int minimoCaracteresNombre = 3;

  static bool puedeAdministrar(RolUsuario rol) => rol == RolUsuario.admin || rol == RolUsuario.supervisor;

  static UnidadFrecuencia unidadDe(TipoActivoMantenimiento t) => switch (t) {
        TipoActivoMantenimiento.cosechadora => UnidadFrecuencia.horas,
        TipoActivoMantenimiento.vehiculo => UnidadFrecuencia.km,
        _ => UnidadFrecuencia.dias,
      };

  static String _numero(double v) => v % 1 == 0 ? v.toInt().toString() : v.toString();

  /// "cada 250 h", "cada 5000 km", "cada 30 días".
  static String textoFrecuencia(ActividadPreventivaEntity a) =>
      'cada ${_numero(a.frecuencia)} ${unidadDe(a.tipoActivo).sufijo}';

  // ------------------------------------------------------------ Código
  /// Siguiente código PREV-NN de la máquina (cuenta también las inactivas).
  static String siguienteCodigo(List<ActividadPreventivaEntity> todas, TipoActivoMantenimiento tipo) {
    var mayor = 0;
    for (final a in todas.where((a) => a.tipoActivo == tipo)) {
      final n = int.tryParse(a.codigo.toUpperCase().replaceFirst(prefijoCodigo, ''));
      if (n != null && n > mayor) mayor = n;
    }
    return '$prefijoCodigo${(mayor + 1).toString().padLeft(2, '0')}';
  }

  /// Actividad nueva (vacía) de la máquina, con su código.
  static ActividadPreventivaEntity nueva(List<ActividadPreventivaEntity> todas, TipoActivoMantenimiento tipo) =>
      ActividadPreventivaEntity(codigo: siguienteCodigo(todas, tipo), tipoActivo: tipo, nombre: '');

  // ------------------------------------------------------------ Lista
  /// Activas de la máquina, ordenadas por código.
  static List<ActividadPreventivaEntity> activasDe(List<ActividadPreventivaEntity> todas, TipoActivoMantenimiento tipo) =>
      todas.where((a) => a.activo && a.tipoActivo == tipo).toList()..sort((a, b) => a.codigo.compareTo(b.codigo));

  /// Filtra por código o nombre (todas las palabras, sin tildes ni mayúsculas).
  static List<ActividadPreventivaEntity> buscar(List<ActividadPreventivaEntity> lista, String texto) {
    final palabras = normalizar(texto).split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (palabras.isEmpty) return lista;
    return [
      for (final a in lista)
        if (palabras.every(normalizar('${a.codigo} ${a.nombre} ${a.descripcion}').contains)) a,
    ];
  }

  /// Minúsculas y sin tildes.
  static String normalizar(String s) {
    const de = 'áàäâéèëêíìïîóòöôúùüûñ';
    const a = 'aaaaeeeeiiiioooouuuun';
    final b = StringBuffer();
    for (final ch in s.toLowerCase().split('')) {
      final i = de.indexOf(ch);
      b.write(i >= 0 ? a[i] : ch);
    }
    return b.toString();
  }

  // ------------------------------------------------------------ Repuestos
  static String _clave(String codigo) => codigo.trim().toUpperCase();

  /// Agrega un repuesto del inventario (cantidad 1); si ya está, suma 1.
  static ActividadPreventivaEntity agregarRepuesto(ActividadPreventivaEntity a, ItemInventarioEntity item) {
    final i = a.repuestos.indexWhere((r) => _clave(r.codigo) == _clave(item.codigo));
    final repuestos = [...a.repuestos];
    if (i >= 0) {
      repuestos[i] = repuestos[i].copyWith(cantidad: repuestos[i].cantidad + 1);
    } else {
      repuestos.add(RepuestoRegistradoEntity(
        codigo: item.codigo,
        descripcion: item.descripcion,
        unidad: item.unidad,
        cantidad: 1,
      ));
    }
    return a.copyWith(repuestos: repuestos);
  }

  static ActividadPreventivaEntity cambiarCantidad(ActividadPreventivaEntity a, int indice, double cantidad) =>
      a.copyWith(repuestos: [...a.repuestos]..[indice] = a.repuestos[indice].copyWith(cantidad: cantidad));

  static ActividadPreventivaEntity quitarRepuesto(ActividadPreventivaEntity a, int indice) =>
      a.copyWith(repuestos: [...a.repuestos]..removeAt(indice));

  // ------------------------------------------------------------ Guardado
  /// Errores (vacío = se puede guardar).
  static List<String> validar(ActividadPreventivaEntity a) => [
        if (a.nombre.trim().length < minimoCaracteresNombre)
          'Escriba el nombre de la actividad (mínimo $minimoCaracteresNombre caracteres).',
        if (a.horasHombre <= 0) 'Ingrese las horas hombre.',
        if (a.frecuencia <= 0) 'Ingrese cada cuánto se hace (${unidadDe(a.tipoActivo).sufijo}).',
        if (a.repuestos.any((r) => r.codigo.trim().isEmpty)) 'Solo se aceptan repuestos del inventario (con código).',
        if (a.repuestos.any((r) => r.cantidad <= 0)) 'Las cantidades de repuestos deben ser mayores a 0.',
      ];

  /// Lo que se guarda: nombre en MAYÚSCULAS, textos sin espacios de más y
  /// quién la modificó.
  static ActividadPreventivaEntity paraGuardar(ActividadPreventivaEntity a, {required String usuarioNombre}) =>
      a.copyWith(
        nombre: a.nombre.trim().toUpperCase(),
        descripcion: a.descripcion.trim(),
        actualizadoPor: usuarioNombre,
      );
}
