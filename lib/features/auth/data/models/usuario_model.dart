// lib/features/auth/data/models/usuario_model.dart (o tu ruta actual)

import '../../domain/entities/usuario_entity.dart'; // Ajusta tu ruta
import '../../../../core/enum/segmento_operativo.dart';

class UsuarioModel extends UsuarioEntity {
  const UsuarioModel({
    required super.uid,
    required super.email,
    required super.nombre,
    required super.segmento,
    required super.rol,
  });

  factory UsuarioModel.fromJson(Map<String, dynamic> json, String uid, String email) {
    return UsuarioModel(
      uid: uid,
      email: email,
      // Interceptamos la llave 'Nombre' (con mayúscula) o 'nombre'
      nombre: json['Nombre'] ?? json['nombre'] ?? 'Operario Desconocido',
      rol: _parsearRol(json['rol'] ?? ''),
      segmento: _parsearSegmento(json['segmento']),
    );
  }

  // Subrutina para el Enum (Ajusta según tu implementación actual)
  static RolUsuario _parsearRol(String rolStr) {
    switch (rolStr.toLowerCase()) {
      case 'requerimiento': return RolUsuario.requerimiento;
      case 'tecnico': return RolUsuario.tecnico;
      case 'supervisor': return RolUsuario.supervisor;
      case 'recepcion': return RolUsuario.recepcion;
      default: return RolUsuario.desconocido;
    }
  }
static SegmentoOperativo _parsearSegmento(String? segmentoStr) {
    // Válvula de seguridad: Si el campo no existe en Firestore, lo mandamos a 'ninguno'
    if (segmentoStr == null || segmentoStr.trim().isEmpty) {
      return SegmentoOperativo.ninguno;
    }

    switch (segmentoStr.toLowerCase().trim()) {
      case 'contador': return SegmentoOperativo.contador;
      case 'cosechadora': return SegmentoOperativo.cosechadora;
      case 'caracol': return SegmentoOperativo.caracol;
      case 'general': return SegmentoOperativo.general;
      default: return SegmentoOperativo.ninguno; // Estado de fallo (Fail-Safe)
    }
  }

}