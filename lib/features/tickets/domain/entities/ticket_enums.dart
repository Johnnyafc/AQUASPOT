// lib/features/tickets/domain/entities/ticket_enums.dart

enum Sede { guayaquil, machala }

enum TipoEquipo { caracol, maquina, contador }

enum Prioridad { baja, media, alta }

enum EstadoTicket { 
  creado,              // Etapa 1: Comercial/Operaciones
  evaluacionTecnica,   // Etapa 2: Taller/Mantenimiento
  recepcionFisica      // Etapa 3: Generación de Acta
}