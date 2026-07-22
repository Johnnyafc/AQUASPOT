// lib/features/tickets/domain/entities/ticket_enums.dart

enum Sede { DURAN, EL_GUABO, NINGUNO }

enum TipoEquipo { Caracol, Cosechadora, Contador, Otros}

enum Prioridad { baja, media, alta }

enum EstadoTicket { 
  creado, 
  enCamino,            
  recepcionFisica,
  comercial,
  cotizado,
  costos,
  compras,
  bodega,
  procesoTrabajo,
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