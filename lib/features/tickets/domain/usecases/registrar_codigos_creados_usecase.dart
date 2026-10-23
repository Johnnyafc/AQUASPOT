// lib/features/tickets/domain/usecases/registrar_codigos_creados_usecase.dart
//
// 🧾 Costos registra el código oficial (y la descripción con la que lo creó
// en el ERP) de cada repuesto nuevo de una Venta de Repuesto. En una sola
// transacción: actualiza las líneas, agrega los repuestos al inventario de la
// app con stock 0 (solo si el código no existía) y devuelve el ticket a
// Proformas enviadas, donde Comercial ve los códigos y registra la OV.

import 'package:dartz/dartz.dart';
import '../../../../core/enum/proceso_auditoria.dart';
import '../../../../core/enum/ticket_enums.dart';
import '../../../../core/errors/failures.dart';
import '../entities/cambio_venta_repuesto.dart';
import '../entities/evento_auditoria_entity.dart';
import '../entities/ticket_entity.dart';
import '../repositories/ticket_repository.dart';
import '../services/creacion_codigos_venta_service.dart';

/// Código creado por Costos para la línea [indiceLinea] del requerimiento.
class CodigoCreado {
  final int indiceLinea;
  final String codigo;
  final String descripcion;

  const CodigoCreado({required this.indiceLinea, required this.codigo, required this.descripcion});
}

class RegistrarCodigosCreadosUseCase {
  final ITicketRepository repository;

  RegistrarCodigosCreadosUseCase(this.repository);

  Future<Either<Failure, TicketEntity>> call({
    required String ticketId,
    required List<CodigoCreado> codigos,
    required String nombreUsuario,
    required String rolUsuario,
    DateTime? ahora,
  }) async {
    if (codigos.isEmpty || codigos.any((c) => c.codigo.trim().isEmpty || c.descripcion.trim().isEmpty)) {
      return const Left(ValidationFailure('Ingrese el código y la descripción de cada repuesto.'));
    }
    final claves = codigos.map((c) => c.codigo.trim().toUpperCase()).toList();
    if (claves.toSet().length != claves.length) {
      return const Left(ValidationFailure('Hay códigos repetidos: cada repuesto debe tener su propio código.'));
    }
    final momento = ahora ?? DateTime.now();
    return repository.actualizarVentaRepuestoEnTransaccion(
      ticketId: ticketId,
      aplicar: (actual) => aplicarSobre(actual, codigos, nombreUsuario, rolUsuario, momento),
    );
  }

  /// Regla pura (testeable sin repositorio).
  static CambioVentaRepuesto aplicarSobre(
    TicketEntity actual,
    List<CodigoCreado> codigos,
    String nombreUsuario,
    String rolUsuario,
    DateTime momento,
  ) {
    if (actual.estadoActual != EstadoTicket.costos) {
      throw CambioVentaRechazado(
          'El requerimiento ya no está en Costos (estado: ${actual.estadoActual.nombreLegible}). No se guardaron los códigos.');
    }
    final pendientes = CreacionCodigosVentaService.indicesPendientes(actual).toSet();
    final recibidos = codigos.map((c) => c.indiceLinea).toSet();
    if (pendientes.isEmpty || !recibidos.containsAll(pendientes) || !pendientes.containsAll(recibidos)) {
      throw const CambioVentaRechazado('Los repuestos pendientes de código cambiaron. Vuelva a abrir la pantalla.');
    }

    final lineas = [...actual.lineasRepuestoVenta];
    for (final c in codigos) {
      lineas[c.indiceLinea] = CreacionCodigosVentaService.conCodigoOficial(
        lineas[c.indiceLinea],
        codigo: c.codigo,
        descripcion: c.descripcion,
        creadoPor: nombreUsuario,
        creadoEn: momento,
      );
    }

    return CambioVentaRepuesto(
      lineas: lineas,
      estadoNuevo: EstadoTicket.cotizado,
      inventarioNuevos: [
        for (final c in codigos)
          RepuestoInventarioNuevo(
            codigo: lineas[c.indiceLinea].codigo,
            descripcion: lineas[c.indiceLinea].descripcion,
            unidad: lineas[c.indiceLinea].unidad,
          ),
      ],
      evento: EventoAuditoriaEntity(
        accion: 'COSTOS: ${codigos.length} CÓDIGO(S) DE REPUESTO CREADO(S) — REGRESA A PROFORMAS ENVIADAS PARA LA OV',
        usuarioNombre: nombreUsuario,
        usuarioRol: rolUsuario,
        timestamp: momento,
        proceso: ProcesoAuditoria.costos,
        hito: HitoProceso.fin,
        habilita: const [ProcesoAuditoria.aprobacionCliente],
      ),
    );
  }
}
