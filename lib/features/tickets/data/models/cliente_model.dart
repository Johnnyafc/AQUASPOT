// lib/features/tickets/data/models/cliente_model.dart

import '../../domain/entities/cliente_entity.dart';
import '../../domain/entities/ticket_enums.dart';

class ClienteModel extends ClienteEntity {
  const ClienteModel({
    required super.id,
    required super.nombreCliente,
    required super.sede,
    required super.campamentos,
    required super.contactoPrincipal,
    required super.telefono,
  });

  factory ClienteModel.fromJson(Map<String, dynamic> json) {
    return ClienteModel(
      id: json['id'] ?? '',
      nombreCliente: json['nombreCliente'] ?? '',
      // Mapeo seguro del String al Enum
      sede: Sede.values.firstWhere(
        (e) => e.name == json['sede'],
        orElse: () => Sede.guayaquil,
      ),
      campamentos: List<String>.from(json['campamentos'] ?? []),
      contactoPrincipal: json['contactoPrincipal'] ?? '',
      telefono: json['telefono'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nombreCliente': nombreCliente,
      'sede': sede.name,
      'campamentos': campamentos,
      'contactoPrincipal': contactoPrincipal,
      'telefono': telefono,
    };
  }
}