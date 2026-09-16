// lib/core/utils/web_previsualizador.dart
//
// 🔌 IMPORT CONDICIONAL: aísla el código que depende de `package:web` /
// `dart:js_interop` para que SOLO se compile cuando el target es Web.
//
// Antes, GestionComprasPage.dart importaba `package:web/web.dart` de forma
// INCONDICIONAL. Eso obligaba al compilador de Android (`flutter build apk`)
// a intentar compilar también ese código de interop con JS, y el SDK de
// Dart de esa máquina no resuelve esos tipos (`JSObject`, `JSArray`, etc.)
// para el target nativo → el build de release fallaba con errores como
// "'JSObject' isn't a type" en package:web.
//
// Con este archivo, el target Android nunca ve `package:web`: usa
// `web_previsualizador_stub.dart` (vacío) en su lugar, y solo el target Web
// usa `web_previsualizador_web.dart` (la implementación real).
export 'web_previsualizador_stub.dart'
    if (dart.library.js_interop) 'web_previsualizador_web.dart';
