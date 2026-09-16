// lib/features/tickets/presentation/widgets/tiempo_en_curso_widget.dart
//
// ⏱️ Muestra cuánto tiempo lleva un ticket en su estado ACTUAL, y lo va
// actualizando solo mientras la tarjeta está en pantalla.
//
// ⚙️ POR QUÉ ESTO NO NECESITA UN BACKEND:
// El valor mostrado es simplemente `DateTime.now().difference(desde)`,
// donde `desde` es el timestamp del último paso del historial del ticket
// (ya guardado en Firestore desde antes). Esa resta se recalcula de cero
// cada vez que el widget se construye, así que automáticamente refleja el
// tiempo real transcurrido — incluso si nadie abrió la app en días — sin
// que ningún proceso tenga que "seguir corriendo" en un servidor. Es
// "asincrónico" por diseño: el reloj no vive en la pantalla, vive en la
// resta de fechas; la pantalla solo lo vuelve a calcular cada vez que se
// abre. El Timer de aquí es puramente cosmético: hace que el número
// visible suba solo mientras alguien está mirando la tarjeta, en vez de
// quedarse congelado hasta el próximo refresco de datos.
//
// 🚀 RENDIMIENTO: cada tarjeta tiene su PROPIO Timer chiquito y solo se
// reconstruye a sí misma (este widget), nunca la lista completa — así,
// aunque haya cientos de tickets en pantalla, "hacer tick" no afecta el
// scroll ni el resto de la interfaz. El intervalo por defecto es 30s
// (de sobra para un texto que se muestra en minutos).

import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/utils/duracion_utils.dart';

class TiempoEnCursoWidget extends StatefulWidget {
  // Fecha desde la que se cuenta el tiempo (ej. cuándo el ticket entró a
  // su estado actual). Si es null, se muestra [textoSinFecha] y no se
  // arranca ningún timer.
  final DateTime? desde;

  // Construye la UI de la tarjeta con el texto ya formateado (ej.
  // "2d 3h 15m"), para que cada pantalla mantenga su propio estilo visual.
  final Widget Function(BuildContext context, String textoFormateado) builder;

  final Duration intervalo;
  final String textoSinFecha;

  const TiempoEnCursoWidget({
    super.key,
    required this.desde,
    required this.builder,
    this.intervalo = const Duration(seconds: 30),
    this.textoSinFecha = 'Sin tiempo registrado',
  });

  @override
  State<TiempoEnCursoWidget> createState() => _TiempoEnCursoWidgetState();
}

class _TiempoEnCursoWidgetState extends State<TiempoEnCursoWidget> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _iniciarTimer();
  }

  @override
  void didUpdateWidget(covariant TiempoEnCursoWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Si cambia la fecha de referencia (ej. la tarjeta ahora representa
    // otro ticket, como pasa al reciclar widgets en un ListView) o el
    // intervalo, reiniciamos el timer desde cero.
    if (oldWidget.desde != widget.desde || oldWidget.intervalo != widget.intervalo) {
      _timer?.cancel();
      _iniciarTimer();
    }
  }

  void _iniciarTimer() {
    if (widget.desde == null) return;
    _timer = Timer.periodic(widget.intervalo, (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final desde = widget.desde;
    final texto = desde == null ? widget.textoSinFecha : formatearDuracion(DateTime.now().difference(desde));
    return widget.builder(context, texto);
  }
}
