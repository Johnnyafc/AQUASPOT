// lib/features/tickets/domain/services/codigo_requerimiento_service.dart
//
// 🔢 Código con el que se crea un requerimiento: los de MANTENIMIENTO
// INTERNO llevan su propia numeración "OT-00001" (contador ot_count); el
// resto sigue con "REQ-00001" (contador ticket_count). Solo reglas puras;
// probado en test/codigo_requerimiento_test.dart.

import '../../../../core/enum/ticket_enums.dart';

class CodigoRequerimientoService {
  static bool _esOrdenTrabajo(TipoRequerimiento? tipo) => tipo == TipoRequerimiento.mantenimientoInterno;

  /// Campo del documento metadata/contadores que lleva la numeración.
  static String campoContador(TipoRequerimiento? tipo) => _esOrdenTrabajo(tipo) ? 'ot_count' : 'ticket_count';

  static String prefijo(TipoRequerimiento? tipo) => _esOrdenTrabajo(tipo) ? 'OT' : 'REQ';

  /// Código del requerimiento número [numero] (5 dígitos): OT-00001 / REQ-00001.
  static String codigo(TipoRequerimiento? tipo, int numero) => '${prefijo(tipo)}-${numero.toString().padLeft(5, '0')}';
}
