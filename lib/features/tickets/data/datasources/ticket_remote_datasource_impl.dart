// lib/features/tickets/data/datasources/ticket_remote_datasource.dart

import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import '../../../clientes/data/models/cliente_model.dart';
import '../models/ticket_model.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/enum/ticket_enums.dart';
import '../../../../core/enum/segmento_operativo.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:typed_data'; // <-- Ruta de tu nuevo Enum       // <-- Ruta de tu Enum de máquinas
import '../datasources/ticket_remote_datasource.dart';

class TicketRemoteDataSourceImpl implements TicketRemoteDataSource {
  final FirebaseFirestore firestore;

  TicketRemoteDataSourceImpl({required this.firestore});


 Future<List<ClienteModel>> obtenerClientes() async {
    try {
      // ⚙️ VÁLVULA ABIERTA: Extrae toda la colección sin filtros
      final snapshot = await firestore.collection('clientes').get();

      return snapshot.docs.map((doc) {
        // ⚙️ INYECCIÓN LIMPIA: Pasamos la data pura y el ID como argumentos separados
        return ClienteModel.fromJson(doc.data(), doc.id);
      }).toList();
      
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Fallo de conexión con Firestore');
    } catch (e) {
      throw ServerException(e.toString());
    }
  }


  @override
  Future<String> subirActaPdfStorage(String ticketId, Uint8List pdfBytes) async {
    try {
      // 1. Apuntamos al directorio de actas
      final storageRef = FirebaseStorage.instance.ref().child('actas_recepcion/acta_$ticketId.pdf');
      
      // 2. Metadatos vitales para que el navegador sepa que es un PDF
      final metadata = SettableMetadata(contentType: 'application/pdf');

      // 3. Bombeo de datos
      final uploadTask = await storageRef.putData(pdfBytes, metadata);

      // 4. Extracción de la telemetría (URL)
      return await uploadTask.ref.getDownloadURL();
    } catch (e) {
      print("🚨 ERROR CRUDO DE FIREBASE (STORAGE PDF): $e");
      throw ServerException(e.toString());
    }
  }


// --- Subir Orden de Venta ---
Future<String> subirOrdenVenta(XFile file, String ticketId) async {
  return _subirA("ordenes_venta", file, ticketId);
}

// --- Subir Orden de Compra ---
Future<String> subirOrdenCompra(XFile file, String ticketId) async {
  return _subirA("ordenes_compra", file, ticketId);
}

// --- Motor privado de subida (La lógica es idéntica, solo cambia el destino) ---
Future<String> _subirA(String carpetaDestino, XFile file, String ticketId) async {
  try {
    final fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.name}';
    final ref = FirebaseStorage.instance.ref().child('tickets/$ticketId/$carpetaDestino/$fileName');

    final uploadTask = await ref.putData(
      await file.readAsBytes(),
      SettableMetadata(contentType: 'application/pdf')
    );
    
    return await uploadTask.ref.getDownloadURL();
  } catch (e) {
    throw ServerException('Falla en subida a $carpetaDestino: $e');
  }
}

@override
Future<void> anularTicket(String ticketId, Map<String, dynamic> data) async {
  try {
    await firestore.collection('tickets').doc(ticketId).update(data);
  } catch (e) {
    // Si falla la escritura, lanzamos la excepción que el Repo atrapará
    throw ServerException('Error al anular en Firestore: $e');
  }
}


Stream<String?> escucharEstadoExcel(String ticketId) {
  return FirebaseFirestore.instance
      .collection('tickets')
      .doc(ticketId)
      .snapshots() // <--- Este es el sensor en tiempo real
      .map((snapshot) {
        if (!snapshot.exists || snapshot.data() == null) return null;
        
        // Extraemos solo la variable de control que inyecta nuestro backend Node.js
        return snapshot.data()!['estadoProcesamientoExcel'] as String?;
      });
}

@override
  Future<String> subirArchivoDocumental(PlatformFile archivo, String ticketId, String subcarpeta) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      // Normalizamos el nombre para evitar caracteres extraños en la URL
      final nombreSeguro = archivo.name.replaceAll(RegExp(r'[^a-zA-Z0-9\.]'), '_');
      final nombreUnico = '${timestamp}_$nombreSeguro';
      final ref = FirebaseStorage.instance.ref().child('tickets/$ticketId/$subcarpeta/$nombreUnico');
      
      // 🏷️ ETIQUETADO INDUSTRIAL (MIME TYPE)
      // Extraemos la extensión para decirle al Storage qué tipo de archivo es.
      final extension = archivo.extension?.toLowerCase() ?? '';
      final String contentType = _determinarContentType(extension);
      
      final metadata = SettableMetadata(
        contentType: contentType,
        customMetadata: {
          'subido_por': 'sistema_tecnico',
          'fecha': DateTime.now().toIso8601String(),
        }
      );

      UploadTask uploadTask;

      // ⚙️ COMPUERTA LÓGICA DE ENTORNO
      if (kIsWeb) {
        if (archivo.bytes == null) throw ServerException('Fallo de sensor: Bytes nulos en entorno WEB');
        
        // ⚠️ ALERTA DE CARGA: Si suben videos pesados en WEB, esto consumirá mucha RAM local.
        uploadTask = ref.putData(archivo.bytes!, metadata);
      } else {
        if (archivo.path == null) throw ServerException('Fallo de sensor: Ruta nula en entorno MOBILE');
        
        uploadTask = ref.putFile(File(archivo.path!), metadata);
      }
      
      return await (await uploadTask).ref.getDownloadURL();
    } catch (e) {
      throw ServerException('Error catastrófico de telemetría en Storage: $e'); 
    }
  }

  // ==========================================
  // 🔬 SENSOR AUXILIAR: ANALIZADOR DE ESPECTRO (MIME)
  // ==========================================
  String _determinarContentType(String extension) {
    switch (extension) {
      // 📷 Fotos
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      // 🎥 Videos
      case 'mp4':
        return 'video/mp4';
      case 'mov':
        return 'video/quicktime';
      case 'avi':
        return 'video/x-msvideo';
      // 📄 Documentos
      case 'pdf':
        return 'application/pdf';
      case 'xls':
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      default:
        // Si no lo reconoce, usa el estándar genérico
        return 'application/octet-stream';
    }
  }




@override
  Future<TicketModel> crearTicket(TicketModel ticket) async {
    try {
      final counterRef = firestore.collection('metadata').doc('contadores');

      final ticketGenerado = await firestore.runTransaction<TicketModel>((transaction) async {
        
        final snapshot = await transaction.get(counterRef);
        int currentCount = 0;
        
        if (snapshot.exists && snapshot.data() != null && snapshot.data()!.containsKey('ticket_count')) {
          currentCount = snapshot.data()!['ticket_count'] as int;
        }

        final nextCount = currentCount + 1;

        // ⚙️ TROQUELADO LÓGICO
        final nuevoId = 'REQ-${nextCount.toString().padLeft(5, '0')}';
        
        // 🔌 LA LÍNEA CRÍTICA: Apuntamos al nuevo ID, NO a ticket.id
        final docRef = firestore.collection('tickets').doc(nuevoId); 

        // Inyección directa para esquivar el error de copyWith
        final Map<String, dynamic> ticketJson = ticket.toJson();
        ticketJson['id'] = nuevoId; 

        // Escritura síncrona
        transaction.set(counterRef, {'ticket_count': nextCount}, SetOptions(merge: true));
        transaction.set(docRef, ticketJson);

        return TicketModel.fromJson(ticketJson);
      });

      return ticketGenerado;
      
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<TicketModel> actualizarTicket(TicketModel ticket) async {
    try {
      final Map<String, dynamic> json = ticket.toJson();

      // PROTECCION MINIMA: si esta escritura trae el codigo de proyecto
      // vacio/nulo, no lo mandamos -- asi una copia local desactualizada
      // (ej. una pantalla que se abrio antes de que Costos lo generara)
      // nunca puede borrar un codigo de proyecto que el servidor ya tiene.
      // Si de verdad se quiere limpiar el codigo, usar actualizarCampos()
      // mandando explicitamente 'codigoProyecto': null.
      if (ticket.codigoProyecto == null || ticket.codigoProyecto!.trim().isEmpty) {
        json.remove('codigoProyecto');
      }

      await firestore.collection('tickets').doc(ticket.id).update(json);
      return ticket;
    } catch (e) {
      print("🚨 ERROR CRUDO DE FIREBASE (ACTUALIZACIÓN): $e");
      throw ServerException(e.toString());
    }
  }

  // NUEVO: escritura parcial por campos. Cada handler del bloc decide
  // explicitamente que campos manda -- nada mas se toca en el documento.
  // Se usa sobre todo para los flujos que pueden operar con una copia
  // vieja del ticket en memoria (ej. despacho de bodega) y para la via
  // administrativa (ForzarCambioEstadoAdminEvent), que si puede mandar
  // cualquier campo, incluidos los protegidos arriba.
  @override
  Future<TicketModel> actualizarCampos(String ticketId, Map<String, dynamic> campos) async {
    try {
      final docRef = firestore.collection('tickets').doc(ticketId);
      await docRef.update(campos);

      // Releemos el documento para devolver el estado real y completo que
      // quedo en el servidor (no una copia local reconstruida a mano),
      // asi el bloc puede sincronizar su estado en memoria con precision.
      final snapshot = await docRef.get();
      final data = snapshot.data();
      if (data == null) {
        throw ServerException('El ticket $ticketId no existe tras actualizar campos.');
      }
      data['id'] = snapshot.id;
      return TicketModel.fromJson(data);
    } catch (e) {
      print("🚨 ERROR CRUDO DE FIREBASE (ACTUALIZACION PARCIAL): $e");
      throw ServerException(e.toString());
    }
  }

  // NUEVO: escritura parcial DENTRO de una transaccion, que primero lee
  // el estado real (fresco) del ticket en Firestore y solo aplica los
  // campos si 'estadoActual' esta en la lista permitida. Si el ticket ya
  // avanzo de etapa, no escribe nada y lanza un error claro. Pensado para
  // el requerimiento (repuestosTaller) editable por comercial en Caracol,
  // para que el candado de etapa no dependa de un objeto local que puede
  // estar desactualizado.
  @override
  Future<void> actualizarCamposConGuardaEstado({
    required String ticketId,
    required Map<String, dynamic> campos,
    required List<String> estadosPermitidos,
  }) async {
    try {
      final docRef = firestore.collection('tickets').doc(ticketId);
      await firestore.runTransaction((tx) async {
        final snap = await tx.get(docRef);
        if (!snap.exists) {
          throw ServerException('El ticket $ticketId no existe.');
        }
        final estadoActual = snap.data()?['estadoActual'] as String?;
        if (!estadosPermitidos.contains(estadoActual)) {
          throw ServerException(
            'El ticket ya no esta en una etapa editable (estado actual: $estadoActual). No se guardo el cambio.',
          );
        }
        tx.update(docRef, campos);
      });
    } catch (e) {
      print("🚨 ERROR CRUDO DE FIREBASE (GUARDA DE ESTADO): $e");
      if (e is ServerException) rethrow;
      throw ServerException(e.toString());
    }
  }

  // NUEVO: mismo id de documento que usa la carga masiva por Excel
  // (guardarLoteInventario) para que el descuento apunte SIEMPRE al mismo
  // documento en inventario_bodega que un codigo determinado.
  String _idInventarioDesdeCodigo(String codigo) {
    return codigo
        .trim()
        .replaceAll('/', '_')
        .replaceAll('.', '_')
        .replaceAll('#', '_')
        .replaceAll(' ', '_');
  }

  // NUEVO: guarda evidencias de un despacho de bodega y descuenta stock de
  // inventario_bodega para ese despacho puntual, dentro de UNA sola
  // transaccion (o se guarda todo, o no se guarda nada).
  //
  // Idempotencia: se lee el ticket TAL COMO ESTA en el servidor (no lo que
  // llego del cliente) y se revisa el campo stockDescontado del despacho
  // con id == despachoId. Si ya es true, no se toca ningun documento de
  // inventario -- solo se guarda 'campos' (fotos nuevas, evento de
  // auditoria, posible cambio de estadoActual) tal cual llego. Si es
  // false, se resta 'cantidad' de 'stockDisponible' por cada item de
  // itemsADescontar (tope en cero, nunca negativo), y se marca ese
  // despacho puntual (dentro de campos['historialDespachos']) como
  // stockDescontado: true antes de escribir el ticket.
  @override
  Future<void> guardarEvidenciasDespachoConDescuentoStock({
    required String ticketId,
    required String despachoId,
    required Map<String, dynamic> campos,
    required List<Map<String, dynamic>> itemsADescontar,
    required bool liberarReserva,
  }) async {
    try {
      final ticketRef = firestore.collection('tickets').doc(ticketId);
      await firestore.runTransaction((tx) async {
        final ticketSnap = await tx.get(ticketRef);
        if (!ticketSnap.exists) {
          throw ServerException('El ticket $ticketId no existe.');
        }

        final historialServidor =
            (ticketSnap.data()?['historialDespachos'] as List<dynamic>?) ?? [];
        bool yaDescontado = false;
        for (final d in historialServidor) {
          if (d is Map && d['id'] == despachoId) {
            yaDescontado = (d['stockDescontado'] as bool?) ?? false;
            break;
          }
        }

        // 1. TODAS las lecturas de inventario van ANTES de cualquier
        // escritura: es un requisito de las transacciones de Firestore.
        final Map<String, DocumentSnapshot<Map<String, dynamic>>> inventarioSnaps = {};
        if (!yaDescontado) {
          for (final item in itemsADescontar) {
            final codigo = (item['codigo'] as String?)?.trim() ?? '';
            final docId = _idInventarioDesdeCodigo(codigo);
            if (docId.isEmpty || inventarioSnaps.containsKey(docId)) continue;
            final ref = firestore.collection('inventario_bodega').doc(docId);
            inventarioSnaps[docId] = await tx.get(ref);
          }
        }

        // 2. Escrituras de descuento de stock (solo la primera vez).
        // Si liberarReserva es true (ticket Caracol), en el mismo paso se
        // libera de stockReservado lo mismo que se resta de
        // stockDisponible -- lo que estaba apartado ya se consumio de
        // verdad, deja de estar "pendiente".
        if (!yaDescontado) {
          for (final item in itemsADescontar) {
            final codigo = (item['codigo'] as String?)?.trim() ?? '';
            final cantidad = (item['cantidad'] as num?)?.toDouble() ?? 0.0;
            final docId = _idInventarioDesdeCodigo(codigo);
            if (docId.isEmpty || cantidad <= 0) continue;
            final snap = inventarioSnaps[docId];
            if (snap == null || !snap.exists) {
              // Sin documento de inventario para este codigo: se omite,
              // no se frena el resto del descuento ni el guardado.
              continue;
            }
            final stockActual = (snap.data()?['stockDisponible'] as num?)?.toDouble() ?? 0.0;
            final nuevoStock = stockActual - cantidad;
            final Map<String, dynamic> ajusteInventario = {
              // Tope en cero: nunca queda negativo.
              'stockDisponible': nuevoStock < 0 ? 0.0 : nuevoStock,
            };
            if (liberarReserva) {
              final reservadoActual = (snap.data()?['stockReservado'] as num?)?.toDouble() ?? 0.0;
              final nuevoReservado = reservadoActual - cantidad;
              ajusteInventario['stockReservado'] = nuevoReservado < 0 ? 0.0 : nuevoReservado;
            }
            tx.update(snap.reference, ajusteInventario);
          }
        }

        // 3. Marca stockDescontado:true en el despacho correspondiente,
        // dentro del historialDespachos que se va a escribir en el ticket.
        final historialAEscribir = (campos['historialDespachos'] as List<dynamic>?) ?? [];
        final historialConFlag = historialAEscribir.map((d) {
          final mapa = Map<String, dynamic>.from(d as Map);
          if (mapa['id'] == despachoId) {
            mapa['stockDescontado'] = true;
          }
          return mapa;
        }).toList();

        final camposFinal = Map<String, dynamic>.from(campos);
        camposFinal['historialDespachos'] = historialConFlag;

        // 4. Escritura del ticket (evidencias + auditoria + estado).
        tx.update(ticketRef, camposFinal);
      });
    } catch (e) {
      print("🚨 ERROR CRUDO DE FIREBASE (DESCUENTO DE STOCK): $e");
      if (e is ServerException) rethrow;
      throw ServerException(e.toString());
    }
  }

  // NUEVO: evaluacion tecnica del supervisor + reserva de stock (Caracol),
  // en una sola transaccion. Candado de idempotencia: si el ticket YA
  // tenia evaluacionTecnica guardada en el servidor, no se vuelve a
  // reservar (protege contra doble clic / reintento de red en el boton
  // "Confirmar y Subir").
  @override
  Future<void> guardarEvaluacionTecnicaConReservaStock({
    required TicketModel ticket,
    required List<Map<String, dynamic>> itemsAReservar,
  }) async {
    try {
      final ticketRef = firestore.collection('tickets').doc(ticket.id);
      await firestore.runTransaction((tx) async {
        final ticketSnap = await tx.get(ticketRef);
        if (!ticketSnap.exists) {
          throw ServerException('El ticket ${ticket.id} no existe.');
        }

        final yaTeniaEvaluacion = ticketSnap.data()?['evaluacionTecnica'] != null;

        // 1. Lecturas de inventario ANTES de cualquier escritura.
        final Map<String, DocumentSnapshot<Map<String, dynamic>>> inventarioSnaps = {};
        if (!yaTeniaEvaluacion) {
          for (final item in itemsAReservar) {
            final codigo = (item['codigo'] as String?)?.trim() ?? '';
            final docId = _idInventarioDesdeCodigo(codigo);
            if (docId.isEmpty || inventarioSnaps.containsKey(docId)) continue;
            final ref = firestore.collection('inventario_bodega').doc(docId);
            inventarioSnaps[docId] = await tx.get(ref);
          }
        }

        // 2. Reserva (solo la primera vez que este ticket guarda su
        // evaluacion tecnica).
        if (!yaTeniaEvaluacion) {
          for (final item in itemsAReservar) {
            final codigo = (item['codigo'] as String?)?.trim() ?? '';
            final cantidad = (item['cantidad'] as num?)?.toDouble() ?? 0.0;
            final docId = _idInventarioDesdeCodigo(codigo);
            if (docId.isEmpty || cantidad <= 0) continue;
            final snap = inventarioSnaps[docId];
            if (snap == null || !snap.exists) {
              // Sin documento de inventario para este codigo: no hay
              // nada que apartar, se omite (no frena el guardado).
              continue;
            }
            final reservadoActual = (snap.data()?['stockReservado'] as num?)?.toDouble() ?? 0.0;
            tx.update(snap.reference, {
              'stockReservado': reservadoActual + cantidad,
            });
          }
        }

        // 3. Escritura del ticket -- mismo criterio que actualizarTicket
        // (proteger codigoProyecto si viene vacio/nulo en esta copia).
        final Map<String, dynamic> json = ticket.toJson();
        if (ticket.codigoProyecto == null || ticket.codigoProyecto!.trim().isEmpty) {
          json.remove('codigoProyecto');
        }
        tx.update(ticketRef, json);
      });
    } catch (e) {
      print("🚨 ERROR CRUDO DE FIREBASE (RESERVA EVALUACION TECNICA): $e");
      if (e is ServerException) rethrow;
      throw ServerException(e.toString());
    }
  }

  // NUEVO: guardado de campos con candado de estado (igual que
  // actualizarCamposConGuardaEstado) MAS el ajuste de stockReservado
  // segun el delta entre lo que el servidor tenia guardado en
  // evaluacionTecnica.repuestosTaller y la nueva lista -- todo leido
  // fresco dentro de la misma transaccion, para no depender de una copia
  // vieja en el celular de quien esta editando.
  @override
  Future<void> actualizarCamposConGuardaEstadoYAjusteReserva({
    required String ticketId,
    required Map<String, dynamic> campos,
    required List<String> estadosPermitidos,
    required List<Map<String, dynamic>> repuestosTallerNuevos,
  }) async {
    try {
      final ticketRef = firestore.collection('tickets').doc(ticketId);
      await firestore.runTransaction((tx) async {
        final ticketSnap = await tx.get(ticketRef);
        if (!ticketSnap.exists) {
          throw ServerException('El ticket $ticketId no existe.');
        }
        final estadoActual = ticketSnap.data()?['estadoActual'] as String?;
        if (!estadosPermitidos.contains(estadoActual)) {
          throw ServerException(
            'El ticket ya no esta en una etapa editable (estado actual: $estadoActual). No se guardo el cambio.',
          );
        }

        // 1. Cantidad actual (segun el servidor, no el celular) por codigo.
        final Map<String, double> cantidadActualPorCodigo = {};
        final evalServidor = ticketSnap.data()?['evaluacionTecnica'] as Map<String, dynamic>?;
        final repuestosServidor = evalServidor?['repuestosTaller'] as List<dynamic>? ?? [];
        for (final r in repuestosServidor) {
          if (r is Map) {
            final cod = (r['codigo'] as String?)?.trim() ?? '';
            if (cod.isEmpty) continue;
            final cant = (r['cantidad'] as num?)?.toDouble() ?? 0.0;
            cantidadActualPorCodigo[cod] = (cantidadActualPorCodigo[cod] ?? 0.0) + cant;
          }
        }

        // 2. Cantidad nueva (lo que se esta por guardar) por codigo.
        final Map<String, double> cantidadNuevaPorCodigo = {};
        for (final r in repuestosTallerNuevos) {
          final cod = (r['codigo'] as String?)?.trim() ?? '';
          if (cod.isEmpty) continue;
          final cant = (r['cantidad'] as num?)?.toDouble() ?? 0.0;
          cantidadNuevaPorCodigo[cod] = (cantidadNuevaPorCodigo[cod] ?? 0.0) + cant;
        }

        // 3. Deltas por codigo (positivo = reservar mas, negativo =
        // liberar). Se ignoran los codigos sin cambio.
        final Set<String> todosLosCodigos = {
          ...cantidadActualPorCodigo.keys,
          ...cantidadNuevaPorCodigo.keys,
        };
        final Map<String, double> deltasPorCodigo = {};
        for (final cod in todosLosCodigos) {
          final delta = (cantidadNuevaPorCodigo[cod] ?? 0.0) - (cantidadActualPorCodigo[cod] ?? 0.0);
          if (delta != 0) deltasPorCodigo[cod] = delta;
        }

        // 4. TODAS las lecturas de inventario antes de cualquier escritura.
        final Map<String, DocumentSnapshot<Map<String, dynamic>>> inventarioSnaps = {};
        for (final cod in deltasPorCodigo.keys) {
          final docId = _idInventarioDesdeCodigo(cod);
          if (docId.isEmpty) continue;
          final ref = firestore.collection('inventario_bodega').doc(docId);
          inventarioSnaps[docId] = await tx.get(ref);
        }

        // 5. Aplica los ajustes de stockReservado.
        deltasPorCodigo.forEach((cod, delta) {
          final docId = _idInventarioDesdeCodigo(cod);
          final snap = inventarioSnaps[docId];
          if (snap == null || !snap.exists) return; // nada que ajustar
          final reservadoActual = (snap.data()?['stockReservado'] as num?)?.toDouble() ?? 0.0;
          final nuevoReservado = reservadoActual + delta;
          tx.update(snap.reference, {
            // Tope en cero como red de seguridad -- no deberia activarse
            // nunca porque el candado de estado ya impide editar una vez
            // que bodega empezo a despachar.
            'stockReservado': nuevoReservado < 0 ? 0.0 : nuevoReservado,
          });
        });

        // 6. Escritura del ticket (igual que actualizarCamposConGuardaEstado).
        tx.update(ticketRef, campos);
      });
    } catch (e) {
      print("🚨 ERROR CRUDO DE FIREBASE (AJUSTE DE RESERVA): $e");
      if (e is ServerException) rethrow;
      throw ServerException(e.toString());
    }
  }

  // NUEVO: anula el ticket y libera lo que quedaba pendiente de
  // stockReservado (repuestosTaller actual del servidor menos lo ya
  // despachado, leido fresco dentro de la transaccion) -- solo se llama
  // para tickets Caracol desde el bloc.
  @override
  Future<void> anularTicketConLiberacionReserva({
    required TicketModel ticket,
  }) async {
    try {
      final ticketRef = firestore.collection('tickets').doc(ticket.id);
      await firestore.runTransaction((tx) async {
        final ticketSnap = await tx.get(ticketRef);
        if (!ticketSnap.exists) {
          throw ServerException('El ticket ${ticket.id} no existe.');
        }

        // 1. Cantidad reservada por codigo (repuestosTaller del servidor).
        final Map<String, double> reservadoPorCodigo = {};
        final evalServidor = ticketSnap.data()?['evaluacionTecnica'] as Map<String, dynamic>?;
        final repuestosServidor = evalServidor?['repuestosTaller'] as List<dynamic>? ?? [];
        for (final r in repuestosServidor) {
          if (r is Map) {
            final cod = (r['codigo'] as String?)?.trim() ?? '';
            if (cod.isEmpty) continue;
            final cant = (r['cantidad'] as num?)?.toDouble() ?? 0.0;
            reservadoPorCodigo[cod] = (reservadoPorCodigo[cod] ?? 0.0) + cant;
          }
        }

        // 2. Cantidad ya despachada por codigo (itemsDespachoBodega del
        // servidor) -- eso ya se libero en su momento, no se vuelve a tocar.
        final Map<String, double> despachadoPorCodigo = {};
        final itemsServidor = ticketSnap.data()?['itemsDespachoBodega'] as List<dynamic>? ?? [];
        for (final it in itemsServidor) {
          if (it is Map) {
            final cod = (it['codigo'] as String?)?.trim() ?? '';
            if (cod.isEmpty) continue;
            final cant = (it['cantidadDespachada'] as num?)?.toDouble() ?? 0.0;
            despachadoPorCodigo[cod] = (despachadoPorCodigo[cod] ?? 0.0) + cant;
          }
        }

        // 3. Pendiente a liberar por codigo (nunca negativo).
        final Map<String, double> pendientePorCodigo = {};
        reservadoPorCodigo.forEach((cod, reservado) {
          final despachado = despachadoPorCodigo[cod] ?? 0.0;
          final pendiente = reservado - despachado;
          if (pendiente > 0) pendientePorCodigo[cod] = pendiente;
        });

        // 4. TODAS las lecturas de inventario antes de cualquier escritura.
        final Map<String, DocumentSnapshot<Map<String, dynamic>>> inventarioSnaps = {};
        for (final cod in pendientePorCodigo.keys) {
          final docId = _idInventarioDesdeCodigo(cod);
          if (docId.isEmpty) continue;
          final ref = firestore.collection('inventario_bodega').doc(docId);
          inventarioSnaps[docId] = await tx.get(ref);
        }

        // 5. Libera stockReservado.
        pendientePorCodigo.forEach((cod, pendiente) {
          final docId = _idInventarioDesdeCodigo(cod);
          final snap = inventarioSnaps[docId];
          if (snap == null || !snap.exists) return;
          final reservadoActual = (snap.data()?['stockReservado'] as num?)?.toDouble() ?? 0.0;
          final nuevoReservado = reservadoActual - pendiente;
          tx.update(snap.reference, {
            'stockReservado': nuevoReservado < 0 ? 0.0 : nuevoReservado,
          });
        });

        // 6. Escritura del ticket como anulado (mismo criterio que
        // actualizarTicket).
        final Map<String, dynamic> json = ticket.toJson();
        if (ticket.codigoProyecto == null || ticket.codigoProyecto!.trim().isEmpty) {
          json.remove('codigoProyecto');
        }
        tx.update(ticketRef, json);
      });
    } catch (e) {
      print("🚨 ERROR CRUDO DE FIREBASE (ANULACION CON LIBERACION DE RESERVA): $e");
      if (e is ServerException) rethrow;
      throw ServerException(e.toString());
    }
  }

  // ✅ NUEVO: Implementación de la lectura de historial
@override
  Future<String> subirDocumentoComercial(String ticketId, PlatformFile archivo, String tipoDocumento) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      // Añadimos el tipoDocumento (ej. proforma_pdf) como prefijo para identificar rápido la telemetría
      final nombreUnico = '${tipoDocumento}_${timestamp}_${archivo.name}';
      
      // 🔧 Ruteo estricto a la celda comercial
      final ref = FirebaseStorage.instance.ref().child('tickets/$ticketId/comercial/$nombreUnico');
      
      UploadTask uploadTask;

      // ⚙️ COMPUERTA LÓGICA DE ENTORNO (Matriz Estandarizada)
      if (kIsWeb) {
        // En WEB no hay rutas del sistema operativo, inyectamos los bytes crudos
        uploadTask = ref.putData(archivo.bytes!);
      } else {
        // En MOBILE leemos la ruta física del almacenamiento local
        uploadTask = ref.putFile(File(archivo.path!));
      }
      
      return await (await uploadTask).ref.getDownloadURL();
    } catch (e) {
      throw ServerException('Fallo en la válvula de inyección comercial: $e'); 
    }
  }




@override
  Future<List<TicketModel>> obtenerTickets(SegmentoOperativo segmentoUsuario) async {
    try {
      // 1. Instanciamos la tubería principal (Query base)
      Query query = firestore.collection('tickets');
      

      // 2. Aplicamos la válvula de segmentación (Filtro por Tenant)
      
      if (segmentoUsuario != null && segmentoUsuario != SegmentoOperativo.general && segmentoUsuario != SegmentoOperativo.ninguno ) {
        print('Entramos al if si tenemos algo en segmento');
        print(segmentoUsuario);
        List<String> maquinasPermitidas = [];

        switch (segmentoUsuario) {
          case SegmentoOperativo.caracol:
            maquinasPermitidas = [TipoEquipo.Caracol.name];
            break;
          case SegmentoOperativo.cosechadora:
            // Ruteo múltiple: El supervisor de cosechadoras ve toda la familia
            maquinasPermitidas = [
              TipoEquipo.Cosechadora.name,
            ];
            break;
          case SegmentoOperativo.contador:
            maquinasPermitidas = [TipoEquipo.Contador.name];
            break;
          default:
            maquinasPermitidas = [];
        }


        if (maquinasPermitidas.isNotEmpty) {
          query = query.where('equipo', whereIn: maquinasPermitidas);

        } else {
          // Bloqueo de seguridad: Si su segmento es inválido, retornamos lista vacía
          return []; 
        }
      }

// 3. Extracción ordenada
// 3. Extracción ordenada por ID de Requerimiento
// FieldPath.documentId es la clave interna que Firestore usa para identificar el documento
final snapshot = await query
    .orderBy(FieldPath.documentId, descending: true) 
    .get();

// --- [DEBUG] PUNTO DE INSPECCIÓN ---
print("🔍 [DEBUG] Consulta ejecutada. Total de documentos recibidos: ${snapshot.docs.length}");

// Si este número es 0, el problema es el filtro de la query (el .where)
if (snapshot.docs.isEmpty) {
  print("⚠️ [DEBUG] La consulta no trajo nada. Revisa tus filtros o el nombre de la colección.");
}
      // 4. Mapeo seguro
return snapshot.docs.map((doc) {
  final data = doc.data() as Map<String, dynamic>;
  data['id'] = doc.id;
  
  try {
    return TicketModel.fromJson(data);
  } catch (e, stackTrace) {
    // Si falla aquí, tu TicketModel no está preparado para los datos que vienen de la DB
    print("🚨 [ERROR CRÍTICO] Falla al convertir a TicketModel:");
    print("Datos que causaron el error: $data");
    print("Detalle: $e");
    print("Stacktrace: $stackTrace");
    rethrow; // Esto detiene la ejecución para que veas el error en la consola
  }
}).toList();
      
    } catch (e) {
      print("🚨 ERROR CRUDO DE FIREBASE (LECTURA HISTORIAL): $e");
      throw ServerException(e.toString());
    }
  }
}