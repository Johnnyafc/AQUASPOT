// lib/features/tickets/data/repositories/ticket_repository_impl.dart

import 'package:dartz/dartz.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../domain/entities/cliente_entity.dart';
import '../../domain/entities/ticket_entity.dart';
import '../../domain/repositories/ticket_repository.dart';
import '../datasources/ticket_remote_datasource.dart';
import '../datasources/webhook_remote_datasource.dart';
import '../models/ticket_model.dart';

class TicketRepositoryImpl implements ITicketRepository {
  final TicketRemoteDataSource firebaseDataSource;
  final WebhookRemoteDataSource webhookDataSource;
  final NetworkInfo networkInfo;

  TicketRepositoryImpl({
    required this.firebaseDataSource,
    required this.webhookDataSource,
    required this.networkInfo,
  });

  // Función auxiliar para castear la Entidad pura a un Modelo serializable
  TicketModel _entityToModel(TicketEntity entity) {
    return TicketModel(
      id: entity.id,
      estadoActual: entity.estadoActual,
      sede: entity.sede,
      clienteId: entity.clienteId,
      campamento: entity.campamento,
      nombreContacto: entity.nombreContacto,
      telefonoContacto: entity.telefonoContacto,
      equipo: entity.equipo,
      fallaReportada: entity.fallaReportada,
      evaluacionTecnica: entity.evaluacionTecnica,
      fotosUrls: entity.fotosUrls,
      pdfActaUrl: entity.pdfActaUrl,
      historialEventos: entity.historialEventos,
    );
  }

  @override
  Future<Either<Failure, List<ClienteEntity>>> obtenerClientes() async {
    if (await networkInfo.isConnected) {
      try {
        final modelos = await firebaseDataSource.obtenerClientes();
        return Right(modelos); // Right significa "Éxito" en programación funcional
      } on ServerException {
        return const Left(ServerFailure('Error al leer la matriz de clientes desde el servidor.'));
      }
    } else {
      return const Left(NetworkFailure('Sin conexión a internet en el campamento.'));
    }
  }

  @override
  Future<Either<Failure, TicketEntity>> crearTicket(TicketEntity ticket) async {
    if (await networkInfo.isConnected) {
      try {
        final ticketModel = _entityToModel(ticket);
        final resultado = await firebaseDataSource.crearTicket(ticketModel);
        return Right(resultado);
      } on ServerException {
        return const Left(ServerFailure('Fallo al registrar el ticket en el sistema central.'));
      }
    } else {
      return const Left(NetworkFailure('Operación abortada: No hay señal de red.'));
    }
  }

  @override
  Future<Either<Failure, TicketEntity>> actualizarEvaluacionTecnica(TicketEntity ticket) async {
    if (await networkInfo.isConnected) {
      try {
        final ticketModel = _entityToModel(ticket);
        final resultado = await firebaseDataSource.actualizarTicket(ticketModel);
        return Right(resultado);
      } on ServerException {
        return const Left(ServerFailure('No se pudo guardar la evaluación técnica.'));
      }
    } else {
      return const Left(NetworkFailure('Operación abortada: No hay señal de red.'));
    }
  }

  @override
  Future<Either<Failure, TicketEntity>> notificarYGenerarActa(TicketEntity ticket) async {
    if (await networkInfo.isConnected) {
      try {
        final ticketModel = _entityToModel(ticket);
        
        // 1. Guardar el estado final en Firebase (Transacción transaccional principal)
        final ticketActualizado = await firebaseDataSource.actualizarTicket(ticketModel);
        
        // 2. Disparar el Webhook a Python para generar el PDF y enviar el correo
        await webhookDataSource.notificarBackendPython(ticketActualizado);

        return Right(ticketActualizado);
      } on ServerException {
        return const Left(ServerFailure('Error en la consolidación del acta. Verifique los servicios.'));
      }
    } else {
      return const Left(NetworkFailure('Operación abortada: No hay señal de red.'));
    }
  }
}