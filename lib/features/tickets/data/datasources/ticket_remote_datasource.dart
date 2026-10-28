import 'dart:io';

import 'package:aquaspot_postventa/core/errors/failures.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dartz/dartz.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import '../../../clientes/data/models/cliente_model.dart';
import '../models/ticket_model.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/enum/ticket_enums.dart';
import '../../../../core/enum/segmento_operativo.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:typed_data'; 

abstract class TicketRemoteDataSource {
  Future<List<ClienteModel>> obtenerClientes();
  Future<TicketModel> crearTicket(TicketModel ticket);
  Future<TicketModel> actualizarTicket(TicketModel ticket);
  // NUEVO: escritura parcial -- solo los campos que se le pasen.
  Future<TicketModel> actualizarCampos(String ticketId, Map<String, dynamic> campos);
  // NUEVO: escritura parcial con candado de estado (transaccion atomica).
  // Solo se usa en el flujo de "requerimiento" editable por comercial
  // (equipo Caracol): valida que el ticket siga en un estado permitido
  // ANTES de escribir, dentro de la misma transaccion de Firestore.
  Future<void> actualizarCamposConGuardaEstado({
    required String ticketId,
    required Map<String, dynamic> campos,
    required List<String> estadosPermitidos,
  });
  // NUEVO: validación simple de Despacho Bodega. En una transacción relee
  // el ticket y solo escribe si TODAVÍA cumple requiereValidacionSimpleBodega
  // (por si cambió desde que se cargó la bandeja). Devuelve el ticket real.
  Future<TicketModel> actualizarCamposConGuardaValidacionSimpleBodega({
    required String ticketId,
    required Map<String, dynamic> campos,
  });

  // 🛒 Relee el ticket en una transacción y escribe lo que calcule
  // [calcular] a partir del ticket actual: los campos del ticket y, si hay,
  // documentos nuevos de inventario_bodega (solo se crean si no existen).
  // Las excepciones que lance [calcular] se propagan tal cual.
  Future<TicketModel> actualizarEnTransaccion({
    required String ticketId,
    required ({
      Map<String, dynamic> campos,
      List<Map<String, dynamic>> inventarioNuevos,
      Map<String, double> reservas,
    }) Function(TicketModel actual)
        calcular,
  });

  // NUEVO: guarda las evidencias fotograficas de un despacho de bodega Y,
  // en la MISMA transaccion de Firestore, descuenta el stock de
  // inventario_bodega correspondiente a ese despacho puntual -- una sola
  // vez por despacho, controlado por el campo stockDescontado (ver
  // RegistroDespachoEntity). Si ya se habia descontado antes, no vuelve
  // a tocar inventario, solo guarda las fotos/evento nuevos.
  Future<void> guardarEvidenciasDespachoConDescuentoStock({
    required String ticketId,
    required String despachoId,
    required Map<String, dynamic> campos,
    required List<Map<String, dynamic>> itemsADescontar,
    // NUEVO: si es true, ademas de restar stockDisponible, se libera
    // (resta) la misma cantidad de stockReservado -- solo aplica a
    // tickets Caracol, que son los unicos que reservan hoy.
    required bool liberarReserva,
  });

  // NUEVO: guarda la evaluacion tecnica del supervisor Y, en la MISMA
  // transaccion, aparta (reserva) en inventario_bodega los repuestos de
  // taller -- solo se usa para tickets Caracol. Trae su propio candado de
  // idempotencia: si el ticket YA tenia una evaluacionTecnica guardada en
  // el servidor, no se vuelve a reservar (evita doble reserva por doble
  // clic o reintento de red), solo se actualiza el resto del documento.
  /// [ajustarConStock] (opcional): recibe el stock neto ACTUAL (código en
  /// MAYÚSCULAS → disponible − apartado, leído en la transacción antes de
  /// apartar) y devuelve el ticket a guardar (ej. su destino). Devuelve el
  /// ticket guardado.
  Future<TicketModel> guardarEvaluacionTecnicaConReservaStock({
    required TicketModel ticket,
    required List<Map<String, dynamic>> itemsAReservar,
    TicketModel Function(Map<String, double> stockNeto)? ajustarConStock,
  });

  // NUEVO: mismo candado de etapa que actualizarCamposConGuardaEstado,
  // mas el ajuste de stockReservado segun el delta entre lo que YA
  // estaba guardado en el servidor (se lee fresco, dentro de la misma
  // transaccion) y la nueva lista de repuestosTaller que se esta
  // guardando. Sube la reserva si se agrego/aumento algo, la baja si se
  // borro/redujo (con tope en cero como red de seguridad).
  Future<void> actualizarCamposConGuardaEstadoYAjusteReserva({
    required String ticketId,
    required Map<String, dynamic> campos,
    required List<String> estadosPermitidos,
    required List<Map<String, dynamic>> repuestosTallerNuevos,
  });

  // NUEVO: anula el ticket y, en la MISMA transaccion, libera de
  // stockReservado lo que quedaba pendiente (repuestosTaller actual del
  // servidor menos lo ya despachado) -- solo aplica a tickets Caracol.
  Future<void> anularTicketConLiberacionReserva({
    required TicketModel ticket,
  });

  Future<String> subirActaPdfStorage(String ticketId, Uint8List pdfBytes);
  
  // ✅ NUEVO: Sonda de extracción para el historial
  Future<List<TicketModel>> obtenerTickets(SegmentoOperativo segmento);
  Future<String> subirArchivoDocumental(PlatformFile archivo, String ticketId, String subcarpeta);
  Future<String> subirDocumentoComercial(String ticketId, PlatformFile archivo, String tipoDocumento);
  Future<String> subirOrdenVenta(XFile file, String ticketId);
Future<String> subirOrdenCompra(XFile file, String ticketId);
Future<void> anularTicket(String ticketId, Map<String, dynamic> data);
Stream<String?> escucharEstadoExcel(String ticketId);
}
