// lib/core/utils/media_helper.dart

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';

/// 🛠️ CAPA DE SEGURIDAD PARA HARDWARE DE GAMA BAJA (tablet china, UNISOC T606)
///
/// 🩺 DIAGNÓSTICO ACTUALIZADO (con la pista nueva: SOLO pasa con fotos que la
/// PROPIA tablet toma con su cámara, nunca con fotos de galería, y SOLO en
/// este equipo):
///
/// La teoría anterior ("el driver colapsa si le pedimos que redimensione")
/// quedó descartada: quitamos `imageQuality`/`maxWidth`/`maxHeight` y el
/// cuadro negro siguió apareciendo. Si el problema fuera ese, además debería
/// afectar también a fotos de galería (mismo decodificador), y no lo hace.
///
/// El patrón real (solo captura en vivo, solo este equipo, almacenamiento
/// eMMC lento de gama baja) es la firma clásica de una CONDICIÓN DE CARRERA
/// entre la app de cámara nativa y el sistema de archivos: el Activity de la
/// cámara le devuelve el control a Flutter (`image_picker`) apenas dispara,
/// pero el archivo JPEG todavía se está terminando de escribir físicamente
/// en el almacenamiento lento del equipo. Si leemos esos bytes en ese
/// instante, obtenemos un binario truncado (a veces de 0 bytes, a veces sin
/// el marcador de cierre del JPEG). Flutter no puede decodificar eso y
/// dibuja el cuadro negro. Una foto de galería nunca sufre esto porque ya
/// estaba completamente escrita desde antes.
///
/// Por eso esta clase hace DOS cosas, no solo comprimir:
/// 1. `esperarArchivoDeCamaraListo`: espera activamente a que el archivo se
///    estabilice (tamaño constante + cabecera JPEG válida) antes de tocarlo.
/// 2. `comprimirImagenNativa`: una vez que el archivo es válido, lo
///    comprime con `flutter_image_compress` (rutinas C++ propias) para no
///    saturar la RAM/ancho de banda del equipo.
class MediaHelper {
  MediaHelper._();

  /// 🔎 Valida que un archivo tenga al menos la cabecera JPEG (SOI: 0xFFD8)
  /// y un tamaño mínimo razonable. Un archivo a medio escribir por la
  /// cámara suele estar vacío, truncado, o no empezar con ese marcador.
  static Future<bool> _esJpegValido(File archivo, {int tamanoMinimoBytes = 5000}) async {
    try {
      final int tamano = await archivo.length();
      if (tamano < tamanoMinimoBytes) return false;

      final RandomAccessFile raf = await archivo.open();
      final Uint8List cabecera = await raf.read(2);
      await raf.close();

      return cabecera.length == 2 && cabecera[0] == 0xFF && cabecera[1] == 0xD8;
    } catch (_) {
      return false;
    }
  }

  /// ⏳ Espera a que la cámara termine de escribir el archivo en disco.
  ///
  /// Sondea el tamaño del archivo varias veces con una pequeña pausa entre
  /// intentos: si el tamaño deja de cambiar (ya no está creciendo) Y la
  /// cabecera JPEG es válida, lo aceptamos. Si tras todos los intentos el
  /// archivo sigue sin ser válido, devolvemos `null` para que quien llama
  /// le pida al operario repetir la captura en vez de guardar un archivo
  /// corrupto silenciosamente.
  static Future<XFile?> esperarArchivoDeCamaraListo(
    XFile archivo, {
    int intentos = 8,
    Duration espera = const Duration(milliseconds: 300),
  }) async {
    if (kIsWeb) return archivo;

    final File file = File(archivo.path);
    int tamanoAnterior = -1;

    for (int i = 0; i < intentos; i++) {
      if (!await file.exists()) {
        await Future.delayed(espera);
        continue;
      }

      final int tamanoActual = await file.length();
      final bool estable = tamanoActual > 0 && tamanoActual == tamanoAnterior;
      tamanoAnterior = tamanoActual;

      if (estable && await _esJpegValido(file)) {
        return archivo; // ✅ Archivo completo y decodificable
      }

      await Future.delayed(espera);
    }

    // Última oportunidad, por si justo se completó en la última pausa.
    if (await file.exists() && await _esJpegValido(file)) {
      return archivo;
    }

    return null; // 🚫 Nunca se estabilizó: el archivo nació corrupto
  }

  /// Comprime una imagen nativa (Android/iOS) de forma segura y aislada del
  /// hardware. Si algo falla en el camino, devuelve el archivo original en
  /// vez de perder la evidencia capturada por el operario.
  static Future<XFile?> comprimirImagenNativa(
    XFile archivoOriginal, {
    int calidad = 70,
    int minWidth = 1200,
    int minHeight = 1200,
  }) async {
    // En Web no aplica: ahí no existe el bug del driver nativo y
    // flutter_image_compress no opera sobre bytes de la misma forma.
    if (kIsWeb) return archivoOriginal;

    try {
      final Uint8List bytesOriginales = await archivoOriginal.readAsBytes();

      final Uint8List? bytesComprimidos = await FlutterImageCompress.compressWithList(
        bytesOriginales,
        quality: calidad,
        minWidth: minWidth,
        minHeight: minHeight,
        format: CompressFormat.jpeg,
      );

      if (bytesComprimidos == null || bytesComprimidos.isEmpty) {
        // La rutina C++ no devolvió nada útil: mejor conservar el crudo
        // que perder la foto.
        return archivoOriginal;
      }

      // Escribimos el resultado junto al archivo original (misma carpeta
      // temporal que ya usa image_picker), para no depender de otro paquete
      // solo para ubicar un directorio temporal.
      final String carpetaDestino = File(archivoOriginal.path).parent.path;
      final String rutaSalida =
          '$carpetaDestino/comp_${DateTime.now().microsecondsSinceEpoch}.jpg';
      final File archivoSalida = await File(rutaSalida).writeAsBytes(bytesComprimidos);

      return XFile(archivoSalida.path);
    } catch (_) {
      // Cualquier fallo en la compresión aislada: nos quedamos con el
      // crudo antes que dejar al operario sin evidencia.
      return archivoOriginal;
    }
  }
}
