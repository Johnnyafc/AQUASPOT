// lib/features/tickets/presentation/models/archivos_linea_venta.dart
//
// 🛒 Evidencia de una línea "por determinar" de Venta de Repuesto, aún sin
// subir (archivos elegidos en el formulario). Va en la misma posición que su
// línea. Es un modelo de presentación: lo usan el formulario y el evento del
// Bloc; los enlaces ya subidos viven en LineaRepuestoVentaEntity.

import 'package:equatable/equatable.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';

class ArchivosLineaVenta extends Equatable {
  final List<XFile> evidencias;
  final List<PlatformFile> audios;

  const ArchivosLineaVenta({this.evidencias = const [], this.audios = const []});

  bool get estaVacio => evidencias.isEmpty && audios.isEmpty;

  @override
  List<Object?> get props => [evidencias, audios];
}
