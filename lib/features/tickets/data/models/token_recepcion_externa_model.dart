// lib/features/tickets/data/models/token_recepcion_externa_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class TokenRecepcionExternaModel {
  final String token;
  final String ticketId;
  final String ordenId;
  final String tecnicoNombre;
  final String tecnicoId;
  final DateTime fechaCreacion;
  final DateTime fechaExpiracion;
  final bool usado;
  final DateTime? fechaUso;
  final String creadoPor;

  const TokenRecepcionExternaModel({
    required this.token,
    required this.ticketId,
    required this.ordenId,
    required this.tecnicoNombre,
    required this.tecnicoId,
    required this.fechaCreacion,
    required this.fechaExpiracion,
    this.usado = false,
    this.fechaUso,
    this.creadoPor = 'SUPERVISOR',
  });

  bool get estaExpirado => DateTime.now().isAfter(fechaExpiracion);
  bool get esValido => !usado && !estaExpirado;

  factory TokenRecepcionExternaModel.fromJson(Map<String, dynamic> json, {String? docId}) {
    DateTime parseFecha(dynamic v, DateTime fallback) {
      if (v == null) return fallback;
      if (v is Timestamp) return v.toDate();
      if (v is String) return DateTime.tryParse(v) ?? fallback;
      return fallback;
    }

    return TokenRecepcionExternaModel(
      token: docId ?? json['token']?.toString() ?? '',
      ticketId: json['ticketId']?.toString() ?? '',
      ordenId: json['ordenId']?.toString() ?? '',
      tecnicoNombre: json['tecnicoNombre']?.toString() ?? '',
      tecnicoId: json['tecnicoId']?.toString() ?? '',
      fechaCreacion: parseFecha(json['fechaCreacion'], DateTime.now()),
      fechaExpiracion: parseFecha(
        json['fechaExpiracion'],
        DateTime.now().add(const Duration(hours: 24)),
      ),
      usado: json['usado'] as bool? ?? false,
      fechaUso: json['fechaUso'] != null ? parseFecha(json['fechaUso'], DateTime.now()) : null,
      creadoPor: json['creadoPor']?.toString() ?? 'SUPERVISOR',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'token': token,
      'ticketId': ticketId,
      'ordenId': ordenId,
      'tecnicoNombre': tecnicoNombre,
      'tecnicoId': tecnicoId,
      'fechaCreacion': Timestamp.fromDate(fechaCreacion),
      'fechaExpiracion': Timestamp.fromDate(fechaExpiracion),
      'usado': usado,
      if (fechaUso != null) 'fechaUso': Timestamp.fromDate(fechaUso!),
      'creadoPor': creadoPor,
    };
  }

  TokenRecepcionExternaModel copyWith({
    String? token,
    String? ticketId,
    String? ordenId,
    String? tecnicoNombre,
    String? tecnicoId,
    DateTime? fechaCreacion,
    DateTime? fechaExpiracion,
    bool? usado,
    DateTime? fechaUso,
    String? creadoPor,
  }) {
    return TokenRecepcionExternaModel(
      token: token ?? this.token,
      ticketId: ticketId ?? this.ticketId,
      ordenId: ordenId ?? this.ordenId,
      tecnicoNombre: tecnicoNombre ?? this.tecnicoNombre,
      tecnicoId: tecnicoId ?? this.tecnicoId,
      fechaCreacion: fechaCreacion ?? this.fechaCreacion,
      fechaExpiracion: fechaExpiracion ?? this.fechaExpiracion,
      usado: usado ?? this.usado,
      fechaUso: fechaUso ?? this.fechaUso,
      creadoPor: creadoPor ?? this.creadoPor,
    );
  }
}

