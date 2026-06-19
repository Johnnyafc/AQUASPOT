// lib/features/auth/data/models/usuario_model.dart (o tu ruta actual)

import '../../domain/entities/usuario_entity.dart'; // Ajusta tu ruta

class UsuarioModel extends UsuarioEntity {
  const UsuarioModel({
    required super.uid,
    required super.email,
    required super.nombre,
    required super.rol,
  });

  factory UsuarioModel.fromJson(Map<String, dynamic> json, String uid, String email) {
    return UsuarioModel(
      uid: uid,
      email: email,
      // Interceptamos la llave 'Nombre' (con mayúscula) o 'nombre'
      nombre: json['Nombre'] ?? json['nombre'] ?? 'Operario Desconocido',
      rol: _parsearRol(json['rol'] ?? ''),
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
}