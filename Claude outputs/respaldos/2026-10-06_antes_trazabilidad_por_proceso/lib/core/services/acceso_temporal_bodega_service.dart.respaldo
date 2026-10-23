// lib/core/services/acceso_temporal_bodega_service.dart

import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../features/tickets/data/models/token_recepcion_externa_model.dart';
import '../../features/tickets/data/models/ticket_model.dart';
import '../../features/tickets/domain/entities/orden_recepcion_repuestos_entity.dart';
import '../../features/tickets/domain/entities/evento_auditoria_entity.dart';

class AccesoTemporalBodegaService {
  final FirebaseFirestore _firestore;

  AccesoTemporalBodegaService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _tokensCol =>
      _firestore.collection('tokens_recepcion_externa');

  /// Genera un token aleatorio seguro de 16 caracteres alfanuméricos
  static String generarTokenAleatorio() {
    const chars = 'abcdefghjkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rnd = Random.secure();
    return List.generate(24, (_) => chars[rnd.nextInt(chars.length)]).join();
  }

  /// Construye la URL completa para el técnico externo
  static String construirUrlAcceso(String token, {String? baseOrigin}) {
    final origin = baseOrigin ?? Uri.base.origin;
    return '$origin/#/recepcion-externa?token=$token';
  }

  /// Crea un nuevo token temporal en Firestore y retorna el modelo creado
  Future<TokenRecepcionExternaModel> generarTokenParaOrden({
    required String ticketId,
    required String ordenId,
    required String tecnicoNombre,
    required String tecnicoId,
    required String creadoPor,
    Duration duracionValidez = const Duration(hours: 24),
  }) async {
    final token = generarTokenAleatorio();
    final ahora = DateTime.now();
    final expiracion = ahora.add(duracionValidez);

    final model = TokenRecepcionExternaModel(
      token: token,
      ticketId: ticketId,
      ordenId: ordenId,
      tecnicoNombre: tecnicoNombre,
      tecnicoId: tecnicoId,
      fechaCreacion: ahora,
      fechaExpiracion: expiracion,
      usado: false,
      creadoPor: creadoPor,
    );

    await _tokensCol.doc(token).set(model.toJson());
    return model;
  }

  /// Consulta y valida un token en Firestore
  Future<TokenRecepcionExternaModel?> obtenerToken(String token) async {
    if (token.trim().isEmpty) return null;
    final doc = await _tokensCol.doc(token.trim()).get();
    if (!doc.exists || doc.data() == null) return null;
    return TokenRecepcionExternaModel.fromJson(doc.data()!, docId: doc.id);
  }

  /// Quema el token temporal y actualiza la orden de recepción en el ticket
  Future<void> consumirTokenYConfirmarRecepcion({
    required String token,
    required String ticketId,
    required String ordenId,
    required List<ItemRecepcionRepuestoEntity> itemsValidados,
    required String nombreTecnico,
    String? notas,
  }) async {
    final ticketRef = _firestore.collection('tickets').doc(ticketId);
    final tokenRef = _tokensCol.doc(token);

    await _firestore.runTransaction((transaction) async {
      // 1. Validar el token dentro de la transacción
      final tokenSnap = await transaction.get(tokenRef);
      if (!tokenSnap.exists) {
        throw Exception('El enlace de acceso temporal no existe.');
      }
      final tokenData = tokenSnap.data()!;
      if (tokenData['usado'] == true) {
        throw Exception('Este enlace ya ha sido utilizado previamente.');
      }

      // 2. Leer el ticket
      final ticketSnap = await transaction.get(ticketRef);
      if (!ticketSnap.exists || ticketSnap.data() == null) {
        throw Exception('El ticket $ticketId no fue encontrado.');
      }

      final ticketModel = TicketModel.fromJson(ticketSnap.data()!);

      // 3. Validar integridad de cantidades y determinar si la orden es total o parcial
      for (final item in itemsValidados) {
        if (item.cantidadRecibidaTecnico < 0 ||
            item.cantidadRecibidaTecnico > item.cantidadDespachadaBodega) {
          throw Exception(
              'Error de validación: La cantidad recibida de ${item.codigo} (${item.cantidadRecibidaTecnico}) no puede superar el máximo alistado por bodega (${item.cantidadDespachadaBodega} ${item.unidad}).');
        }
      }

      bool esTotal = true;
      for (final item in itemsValidados) {
        if (!item.validado || item.cantidadRecibidaTecnico != item.cantidadDespachadaBodega) {
          esTotal = false;
          break;
        }
      }

      final ahora = DateTime.now();
      final estadoFinal = esTotal
          ? EstadoOrdenRecepcion.recibidoTotal
          : EstadoOrdenRecepcion.recibidoParcial;

      // 4. Actualizar la orden correspondiente
      final ordenesActualizadas = ticketModel.ordenesRecepcion.map((ord) {
        if (ord.id == ordenId) {
          return ord.copyWith(
            estado: estadoFinal,
            fechaRecepcion: ahora,
            items: itemsValidados,
          );
        }
        return ord;
      }).toList();

      // 5. Preparar la auditoría forense
      final detalleItems = itemsValidados
          .map((i) => '${i.codigo}: ${i.cantidadRecibidaTecnico}/${i.cantidadDespachadaBodega} ${i.unidad}')
          .join(', ');
      final eventoLog = EventoAuditoriaEntity(
        accion: 'TALLER: REPUESTOS RETIRADOS EN BODEGA POR TÉCNICO EXTERNO $nombreTecnico VÍA ENLACE TEMPORAL [$ordenId]. ESTADO: ${esTotal ? "TOTAL 100%" : "PARCIAL"}. DETALLE: ($detalleItems)',
        usuarioNombre: nombreTecnico,
        usuarioRol: 'TECNICO_EXTERNO',
        timestamp: ahora,
      );

      final historialActualizado = [...ticketModel.historialEventos, eventoLog];

      // 6. Quema del token (usado = true)
      transaction.update(tokenRef, {
        'usado': true,
        'fechaUso': FieldValue.serverTimestamp(),
        'notasUso': notas ?? '',
      });

      // 7. Guardar en el ticket
      transaction.update(ticketRef, {
        'ordenesRecepcion': ordenesActualizadas.map((e) {
          return {
            'id': e.id,
            'fechaAsignacion': Timestamp.fromDate(e.fechaAsignacion),
            'tecnicoId': e.tecnicoId,
            'tecnicoNombre': e.tecnicoNombre,
            'supervisorAsigna': e.supervisorAsigna,
            'fechaRecepcion': e.fechaRecepcion != null ? Timestamp.fromDate(e.fechaRecepcion!) : null,
            'estado': e.estado.name,
            'items': e.items.map((i) => {
              'codigo': i.codigo,
              'descripcion': i.descripcion,
              'cantidadDespachadaBodega': i.cantidadDespachadaBodega,
              'cantidadRecibidaTecnico': i.cantidadRecibidaTecnico,
              'unidad': i.unidad,
              'validado': i.validado,
            }).toList(),
          };
        }).toList(),
        'historialEventos': historialActualizado.map((e) => {
          'accion': e.accion,
          'usuarioNombre': e.usuarioNombre,
          'usuarioRol': e.usuarioRol,
          'timestamp': Timestamp.fromDate(e.timestamp),
        }).toList(),
        'fechaUltimaModificacion': FieldValue.serverTimestamp(),
      });
    });
  }

  /// Busca un token no utilizado y no expirado para una orden específica
  Future<TokenRecepcionExternaModel?> obtenerTokenValidoParaOrden(String ordenId) async {
    final query = await _tokensCol.where('ordenId', isEqualTo: ordenId).get();
    for (final doc in query.docs) {
      final token = TokenRecepcionExternaModel.fromJson(doc.data(), docId: doc.id);
      if (!token.usado && !token.estaExpirado) {
        return token;
      }
    }
    return null;
  }

  /// Obtiene el token activo existente o genera uno nuevo si no existe o expiró
  Future<TokenRecepcionExternaModel> obtenerOGenerarTokenParaOrden({
    required String ticketId,
    required String ordenId,
    required String tecnicoNombre,
    required String tecnicoId,
    required String creadoPor,
    Duration duracionValidez = const Duration(hours: 24),
  }) async {
    final existente = await obtenerTokenValidoParaOrden(ordenId);
    if (existente != null) {
      return existente;
    }
    return generarTokenParaOrden(
      ticketId: ticketId,
      ordenId: ordenId,
      tecnicoNombre: tecnicoNombre,
      tecnicoId: tecnicoId,
      creadoPor: creadoPor,
      duracionValidez: duracionValidez,
    );
  }
}

