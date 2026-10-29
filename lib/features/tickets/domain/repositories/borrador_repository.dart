// lib/features/tickets/domain/repositories/borrador_repository.dart
//
// 💾 Borradores locales (en este dispositivo / navegador) de formularios a
// medio llenar: los datos como mapa simple y sus archivos (fotos, videos)
// aparte, para que se recuperen si se cierra o recarga la página.

import 'package:equatable/equatable.dart';
import '../entities/archivo_adjunto.dart';

class BorradorLocal extends Equatable {
  final Map<String, dynamic> datos;
  final Map<String, ArchivoAdjunto> archivos; // id → archivo

  const BorradorLocal({required this.datos, this.archivos = const {}});

  @override
  List<Object?> get props => [datos, archivos];
}

abstract class IBorradorRepository {
  /// Reemplaza el borrador [clave] (los archivos que ya no están se borran).
  Future<void> guardar(String clave, BorradorLocal borrador);

  /// null si no hay borrador (o no se pudo leer).
  Future<BorradorLocal?> obtener(String clave);

  Future<void> eliminar(String clave);
}
