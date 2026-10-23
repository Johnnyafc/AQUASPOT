// lib/core/enum/proceso_auditoria.dart
//
// Etiquetas estructuradas de la auditoría (historialEventos) para medir los
// tiempos por proceso, incluso cuando varios departamentos trabajan en
// paralelo (Compras / Validación Bodega / Despacho / Taller).
//
// Cada evento nuevo guarda:
//   - proceso:  quién actuó.
//   - hito:     si con esa acción el proceso INICIA, AVANZA o termina (FIN).
//   - habilita: a qué procesos les deja trabajo (desde ahí empieza a
//               contar su tiempo).
// Los eventos antiguos no tienen estos campos (son opcionales) y se siguen
// clasificando por el texto de la acción.

import 'ticket_enums.dart';

enum ProcesoAuditoria {
  recepcion,
  evaluacion,
  garantia,
  comercial,          // Comercial cotizando ("En cotización")
  aprobacionCliente,  // Espera de respuesta del cliente ("Proforma enviada")
  costos,
  compras,            // Emisión de órdenes de compra
  validacionBodega,   // Compras valida lo que va llegando
  bodega,             // Despacho
  taller,             // Proceso de Trabajo
  revisionPagos,
  entrega,            // Guía y factura
  admin,              // Ajustes administrativos (fuera de los promedios)
  otro,               // Anulación, etc. (fuera de los promedios)
}

enum HitoProceso { inicio, avance, fin }

/// Proceso que trabaja el ticket cuando está en ese estado (para que un
/// cambio forzado de estado habilite la etapa correcta). null = estado final.
ProcesoAuditoria? procesoDeEstado(EstadoTicket estado) {
  switch (estado) {
    case EstadoTicket.creado:
    case EstadoTicket.enCamino:
      return ProcesoAuditoria.recepcion;
    case EstadoTicket.recepcionFisica:
      return ProcesoAuditoria.evaluacion;
    case EstadoTicket.revisionGarantia:
      return ProcesoAuditoria.garantia;
    case EstadoTicket.cotizandoRepuesto:
    case EstadoTicket.compras:
      return ProcesoAuditoria.compras;
    case EstadoTicket.comercial:
      return ProcesoAuditoria.comercial;
    case EstadoTicket.cotizado:
      return ProcesoAuditoria.aprobacionCliente;
    case EstadoTicket.costos:
      return ProcesoAuditoria.costos;
    case EstadoTicket.bodega:
      return ProcesoAuditoria.bodega;
    case EstadoTicket.procesoTrabajo:
      return ProcesoAuditoria.taller;
    case EstadoTicket.validacionFacturacion:
      return ProcesoAuditoria.revisionPagos;
    case EstadoTicket.entrega:
      return ProcesoAuditoria.entrega;
    case EstadoTicket.finalizado:
    case EstadoTicket.anulado:
      return null;
  }
}

extension ProcesoAuditoriaX on ProcesoAuditoria {
  /// Nombre de la barra del dashboard "Tiempo promedio por proceso".
  /// null = no entra en los promedios.
  String? get etiquetaDashboard {
    switch (this) {
      case ProcesoAuditoria.recepcion:
        return 'Recepción';
      case ProcesoAuditoria.evaluacion:
        return 'Evaluación Técnica';
      case ProcesoAuditoria.garantia:
        return 'Revisión Garantía';
      case ProcesoAuditoria.comercial:
        return 'En cotización';
      case ProcesoAuditoria.aprobacionCliente:
        return 'Proforma enviada';
      case ProcesoAuditoria.costos:
        return 'Costos';
      case ProcesoAuditoria.compras:
        return 'Compras';
      case ProcesoAuditoria.validacionBodega:
        return 'Validación Bodega';
      case ProcesoAuditoria.bodega:
        return 'Despacho';
      case ProcesoAuditoria.taller:
        return 'Proceso de Trabajo';
      case ProcesoAuditoria.revisionPagos:
        return 'Revisión de pagos';
      case ProcesoAuditoria.entrega:
        return 'Entrega';
      case ProcesoAuditoria.admin:
      case ProcesoAuditoria.otro:
        return null;
    }
  }
}
