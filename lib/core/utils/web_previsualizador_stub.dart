// lib/core/utils/web_previsualizador_stub.dart
//
// Implementación vacía para plataformas nativas (Android/iOS). La UI que
// llama a `abrirBlobEnNuevaPestana` solo existe en la rama Web de la app,
// así que esta rama nunca se ejecuta en nativo — pero el archivo debe
// existir para que el import condicional en `web_previsualizador.dart`
// tenga algo válido que compilar en el build de Android/iOS.
import 'dart:typed_data';

Future<void> abrirBlobEnNuevaPestana(Uint8List bytes, String mimeType) async {
  throw UnsupportedError(
    'La previsualización de archivos en una nueva pestaña solo está disponible en Web.',
  );
}
