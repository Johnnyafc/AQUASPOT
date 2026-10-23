// 🛡️ Protección de la trazabilidad: todo evento de auditoría que crea el
// código ACTIVO debe llevar `proceso:` (ver proceso_auditoria.dart). Si
// alguien agrega una acción nueva y olvida etiquetarla, este test falla
// (además el dashboard la mostraría como "Sin clasificar").

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// Manejadores del bloc que ya no se disparan desde ninguna pantalla
/// (código muerto pendiente de limpieza): no se exige etiqueta.
const _manejadoresSinUso = {
  '_onProcesarBodega',
  '_onCompletarCompras',
  '_onCompletarProcesoTrabajo',
  '_onConsumirRepuestosBodega',
  '_onDeclararNoRequiereCompras',
  '_onAsignarTecnicosTrabajo',
};

/// Devuelve, para cada `EventoAuditoriaEntity(` del archivo, el bloque
/// completo de argumentos y el manejador `_onXxx` que lo contiene.
List<({String manejador, String bloque, int linea})> _eventos(String codigo) {
  final out = <({String manejador, String bloque, int linea})>[];
  final reManejador = RegExp(r'Future<void>\s+(_on\w+)\s*\(');
  var inicio = codigo.indexOf('EventoAuditoriaEntity(');
  while (inicio >= 0) {
    // Balanceo de paréntesis para obtener el bloque completo.
    var nivel = 0;
    var fin = inicio + 'EventoAuditoriaEntity'.length;
    for (; fin < codigo.length; fin++) {
      final c = codigo[fin];
      if (c == '(') nivel++;
      if (c == ')') {
        nivel--;
        if (nivel == 0) break;
      }
    }
    final previo = reManejador.allMatches(codigo.substring(0, inicio));
    out.add((
      manejador: previo.isEmpty ? '' : previo.last.group(1)!,
      bloque: codigo.substring(inicio, fin + 1),
      linea: '\n'.allMatches(codigo.substring(0, inicio)).length + 1,
    ));
    inicio = codigo.indexOf('EventoAuditoriaEntity(', fin);
  }
  return out;
}

void main() {
  test('Todo evento de auditoría activo del bloc lleva proceso', () {
    final codigo = File('lib/features/tickets/presentation/bloc/ticket_bloc.dart').readAsStringSync();
    final sinEtiqueta = _eventos(codigo)
        .where((e) => !_manejadoresSinUso.contains(e.manejador))
        .where((e) => !e.bloque.contains('proceso:'))
        .map((e) => '${e.manejador} (línea ${e.linea})')
        .toList();
    expect(sinEtiqueta, isEmpty, reason: 'Eventos sin etiquetar: $sinEtiqueta');
  });

  test('Eventos creados fuera del bloc también llevan proceso', () {
    for (final ruta in [
      'lib/core/services/acceso_temporal_bodega_service.dart',
      'lib/features/tickets/presentation/pages/GenerarCotizacionPage.dart',
    ]) {
      final sinEtiqueta = _eventos(File(ruta).readAsStringSync())
          .where((e) => !e.bloque.contains('proceso:'))
          .map((e) => 'línea ${e.linea}')
          .toList();
      expect(sinEtiqueta, isEmpty, reason: '$ruta: $sinEtiqueta');
    }
  });

  test('El cambio de estado genérico desde pantallas pasa su proceso', () {
    final guabo = File('lib/features/tickets/presentation/pages/BandejaRecepcionGuaboPage.dart').readAsStringSync();
    expect(guabo.contains('proceso: ProcesoAuditoria.recepcion'), isTrue);
  });
}
