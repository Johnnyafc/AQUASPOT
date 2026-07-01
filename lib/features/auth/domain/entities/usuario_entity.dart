// lib/features/auth/domain/entities/usuario_entity.dart

import 'package:equatable/equatable.dart';
// ⚙️ IMPORTANTE: Asegúrate de importar la ruta correcta de tu enum
import '../../../../core/enum/segmento_operativo.dart'; 

// El nivel de privilegios del operador
enum RolUsuario { 
  requerimiento, 
  tecnico, 
  supervisor,
  recepcion, 
  desconocido // Estado de fallo de seguridad
}

class UsuarioEntity extends Equatable {
  final String uid;
  final String email;
  final String nombre;
  final RolUsuario rol;
  
  // 🚀 NUEVO: El identificador de ruteo de tickets (Tenant Partitioning)
  final SegmentoOperativo segmento;

  const UsuarioEntity({
    required this.uid,
    required this.email,
    required this.nombre,
    required this.rol,
    required this.segmento, // Obligatorio para inicializar el usuario
  });

  @override
  // ⚙️ VITAL: Si el segmento no está aquí, BLoC no reconstruirá la UI al cambiar de área
  List<Object?> get props => [uid, email, nombre, rol, segmento]; 
}