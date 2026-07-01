// lib/features/tickets/data/repositories/ticket_repository_impl.dart

import 'package:dartz/dartz.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../domain/entities/cliente_entity.dart';
import '../../domain/entities/ticket_entity.dart';
import '../../domain/repositories/ticket_repository.dart';
import '../datasources/ticket_remote_datasource.dart';
import '../datasources/webhook_remote_datasource.dart';
import '../models/ticket_model.dart';
import '../models/evento_auditoria_model.dart';
import '../datasources/storage_remote_datasource.dart';
import '../../../../core/enum/segmento_operativo.dart';
import 'dart:io';
import 'dart:typed_data';


class TicketRepositoryImpl implements ITicketRepository {
  final TicketRemoteDataSource firebaseDataSource;
  final WebhookRemoteDataSource webhookDataSource;
  final StorageRemoteDataSource storageDataSource;
  final NetworkInfo networkInfo;
  

  TicketRepositoryImpl({
    required this.firebaseDataSource,
    required this.webhookDataSource,
    required this.storageDataSource,
    required this.networkInfo,
  });

  // --- Subrutina de Conversión Universal ---
  TicketModel _entityToModel(TicketEntity entity) {
    return TicketModel(
      id: entity.id,
      estadoActual: entity.estadoActual,
      sede: entity.sede,
      clienteId: entity.clienteId,
      campamento: entity.campamento,
      nombreContacto: entity.nombreContacto,
      telefonoContacto: entity.telefonoContacto,
      emailContacto: entity.emailContacto,
      equipo: entity.equipo,
      equipoDetalle: entity.equipoDetalle,
      fallaReportada: entity.fallaReportada,
      accesoriosRecibidos: entity.accesoriosRecibidos,
      numeroSerie: entity.numeroSerie, // ✅ AHORA SÍ: El número de serie viaja a Firebase
      evaluacionTecnica: entity.evaluacionTecnica, 
      fotosUrls: entity.fotosUrls,
      pdfActaUrl: entity.pdfActaUrl,
      historialEventos: entity.historialEventos.map((e) => EventoAuditoriaModel(
        accion: e.accion,
        usuarioNombre: e.usuarioNombre,
        usuarioRol: e.usuarioRol,
        timestamp: e.timestamp,
      )).toList(),
    );
  }

  // --- Operaciones CRUD ---





  @override
  Future<Either<Failure, List<ClienteEntity>>> obtenerClientes() async {
    if (await networkInfo.isConnected) {
      try {
        final modelos = await firebaseDataSource.obtenerClientes();
        return Right(modelos); 
      } on ServerException {
        return const Left(ServerFailure('Error al leer la matriz de clientes desde el servidor.'));
      }
    } else {
      return const Left(NetworkFailure('Sin conexión a internet en el campamento.'));
    }
  }

@override
  Future<Either<Failure, List<TicketEntity>>> obtenerTickets({SegmentoOperativo? segmentoUsuario}) async {
    try {
      // 📡 El repositorio solo transporta la señal hacia el origen de datos
      final modelos = await firebaseDataSource.obtenerTickets(segmentoUsuario: segmentoUsuario);
      return Right(modelos); 
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message)); 
    } catch (e) {
      return Left(ServerFailure('Error inesperado al leer el historial SCADA: $e'));
    }
  }

  @override
  Future<Either<Failure, String>> subirActaPdfStorage(String ticketId, Uint8List pdfBytes) async {
    try {
      // remoteDataSource es la instancia que ya tienes inyectada en tu clase
      final url = await firebaseDataSource.subirActaPdfStorage(ticketId, pdfBytes);
      return Right(url);
    } catch (e) {
      return Left(ServerFailure("Hubo un error en subir el pdf"));
    }
  }


  @override
  Future<Either<Failure, String>> subirEvidencia(XFile file, String ticketId) async {
    // 1. Verificación de enlace de red (telemetría)
    if (await networkInfo.isConnected) {
      try {
        // 2. Disparamos la subida a través del DataSource
        final urlDescarga = await storageDataSource.subirEvidencia(file, ticketId);
        return Right(urlDescarga); // Éxito: Retornamos la URL
      } on ServerException catch (e) {
        // Fallo en Firebase
        return Left(ServerFailure(e.message ?? 'Error en la transmisión de datos al bucket.'));
      } catch (e) {
        // Fallo crítico no esperado
        return Left(ServerFailure('Fallo catastrófico del sistema de archivos: $e'));
      }
    } else {
      // Sin internet (Campamento off-grid)
      return const Left(NetworkFailure('Operación abortada: No hay conexión a internet para subir archivos pesados.'));
    }
  }


  @override
  Future<Either<Failure, TicketEntity>> crearTicket(TicketEntity ticket) async {
    if (await networkInfo.isConnected) {
      try {
        final ticketModel = _entityToModel(ticket);
        final resultado = await firebaseDataSource.crearTicket(ticketModel);
        return Right(resultado);
      } catch (e) { 
        print("🚨 ERROR CRUDO EN REPOSITORIO (CREAR): ${e.toString()}");
        return Left(ServerFailure(e.toString()));
      }
    } else {
      return const Left(NetworkFailure('Operación abortada: No hay señal de red.'));
    }
  }

  // ✅ CANAL UNIFICADO PARA TODAS LAS ACTUALIZACIONES (Evaluación, Recepción, etc.)
  @override
  Future<Either<Failure, TicketEntity>> actualizarTicket(TicketEntity ticket) async {
    if (await networkInfo.isConnected) {
      try {
        final ticketModel = _entityToModel(ticket);
        final resultado = await firebaseDataSource.actualizarTicket(ticketModel);
        return Right(resultado);
      } catch (e) {
        print("🚨 ERROR CRUDO EN REPOSITORIO (ACTUALIZAR): ${e.toString()}");
        return Left(ServerFailure('Fallo de sincronización: No se pudo actualizar el estado del equipo. Error: $e'));
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
        
        // 1. Guardar el estado final en Firebase
        final ticketActualizado = await firebaseDataSource.actualizarTicket(ticketModel);
        
        // 2. Disparar el Webhook a Python para generar el PDF
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