// lib/core/services/archivos_borrador_store.dart
//
// 🗄️ Almacén de ARCHIVOS de borradores (fotos, PDF, Excel) en el
// almacenamiento grande del navegador (IndexedDB), para que los borradores
// no dependan del límite de ~5 MB del almacenamiento normal de la web.
//
// IMPORT CONDICIONAL (mismo esquema que web_previsualizador.dart): Android
// nunca compila `package:web`; usa la versión vacía (disponible == false)
// y sigue con la lógica de BorradorStorageService (base64 + ruta).
export 'archivos_borrador_store_stub.dart'
    if (dart.library.js_interop) 'archivos_borrador_store_web.dart';
