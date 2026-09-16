// lib/core/utils/web_previsualizador_web.dart
//
// Implementación real: SOLO se compila cuando el target es Web (por el
// import condicional en `web_previsualizador.dart`). Aquí sí es seguro usar
// `package:web` y `dart:js_interop`, porque el compilador de Android/iOS
// nunca llega a ver este archivo.
import 'dart:typed_data';
import 'dart:js_interop';
import 'package:web/web.dart' as web;

Future<void> abrirBlobEnNuevaPestana(Uint8List bytes, String mimeType) async {
  // Conversión de señales (Dart a JS Interop)
  final jsBytes = bytes.toJS;
  final blobOptions = web.BlobPropertyBag(type: mimeType);

  // Empaquetado Binario: Creamos el Blob nativo
  final blob = web.Blob([jsBytes].toJS, blobOptions);

  // Generamos la ruta local (Object URL)
  final url = web.URL.createObjectURL(blob);

  // Inyectamos la orden directa al kernel del navegador
  web.window.open(url, '_blank');

  // Mantenimiento preventivo: Liberamos memoria RAM
  Future.delayed(const Duration(seconds: 2), () {
    web.URL.revokeObjectURL(url);
  });
}
