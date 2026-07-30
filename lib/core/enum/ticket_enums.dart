// lib/features/tickets/domain/entities/ticket_enums.dart

enum Sede { DURAN, EL_GUABO, NINGUNO }

enum TipoGarantia {
  pendiente,      // Estado inicial en la UI
  servicio,       // Garantía sobre un trabajo de reparación previo
  maquinaNueva,   // Garantía de fábrica por equipo recién vendido
  noAplica        // Para tickets que no son garantía (Venta, Alquiler, etc.)
}

/// Define el centro de costos o entidad que absorbe el valor operativo.
enum ResponsableFacturacion {
  pendiente,      // Aún no calculado
  cliente,        // Facturación normal al cliente final
  agripotsa,      // Absorbido por la matriz (Ej: Garantía máquina nueva)
  tallerInterno,  // Absorbido por el taller (Ej: Garantía de servicio)
  noAplica
}

enum TipoEquipo { Caracol, Cosechadora, Contador, Otros}

enum Prioridad { baja, media, alta }

enum EstadoTicket { 
  creado, 
  enCamino,            
  recepcionFisica,
  revisionGarantia,
  comercial,
  cotizado,
  costos,
  compras,
  bodega,
  procesoTrabajo,
  validacionFacturacion,
  finalizado,           // Cerrado y correo enviado
  anulado 
}

enum TipoRequerimiento {
  ventaRepuesto,
  alquilerPrueba,
  reparacion,
  reclamoGarantia,
  ventaMaquina,
  ninguno
}

enum LugarAtencion {
  taller,
  campo,
  pendiente, // ⚙️ Clave para mantener el submenú abierto
  noAplica
}