// lib/features/tickets/domain/entities/ticket_enums.dart

enum Sede { DURAN, EL_GUABO }

enum TipoEquipo { Caracol, Cosechadora, Contador, Otros}

enum Prioridad { baja, media, alta }

enum EstadoTicket { 
  creado,
  recibido,              
  evaluacionTecnica,   
  recepcionFisica,
  comercial,
  cotizado      
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