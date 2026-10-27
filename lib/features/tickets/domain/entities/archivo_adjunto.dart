// lib/features/tickets/domain/entities/archivo_adjunto.dart
//
// 📎 Archivo listo para subir (foto, video, documento), sin depender de
// image_picker ni de file_picker: la pantalla lo arma con los bytes del
// archivo elegido y el dominio solo conoce bytes, nombre y tipo. Es lo que
// usa el código nuevo en lugar de XFile (deuda conocida en domain).

import 'dart:typed_data';

import 'package:equatable/equatable.dart';

class ArchivoAdjunto extends Equatable {
  final Uint8List bytes;
  final String nombre;
  final String? tipoContenido; // ej. image/jpeg, video/mp4 (null = se deduce del nombre)

  const ArchivoAdjunto({required this.bytes, required this.nombre, this.tipoContenido});

  @override
  List<Object?> get props => [nombre, tipoContenido, bytes.length];
}
