// lib/features/tickets/data/datasources/webhook_remote_datasource.dart

import 'package:dio/dio.dart';
import '../models/ticket_model.dart';
import '../../../../core/errors/exceptions.dart';

abstract class WebhookRemoteDataSource {
  /// Dispara el JSON del ticket hacia el backend en Python
  Future<void> notificarBackendPython(TicketModel ticket);
}

class WebhookRemoteDataSourceImpl implements WebhookRemoteDataSource {
  final Dio dio;

  WebhookRemoteDataSourceImpl({required this.dio});

  @override
  Future<void> notificarBackendPython(TicketModel ticket) async {
    try {
      // TODO: Mover esta URL a constants.dart después
      const String webhookUrl = 'https://aquaspot-python-backend.a.run.app/api/v1/actas';

      final response = await dio.post(
        webhookUrl,
        data: ticket.toJson(),
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw ServerException();
      }
    } on DioException {
      // Si el servidor de Python está caído, lanzamos la excepción de red
      throw ServerException();
    }
  }
}