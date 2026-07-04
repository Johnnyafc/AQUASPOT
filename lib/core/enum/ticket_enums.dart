// lib/features/tickets/domain/entities/ticket_enums.dart

enum Sede { guayaquil, machala }

enum TipoEquipo { Caracol, Cosechadora_premium,Cosechadora_standart,Cosechadora_elevacion, Contador, Otros}

enum Prioridad { baja, media, alta }

enum EstadoTicket { 
  creado,              // Etapa 1: Comercial/Operaciones
  evaluacionTecnica,   // Etapa 2: Taller/Mantenimiento
  recepcionFisica      // Etapa 3: Generación de Acta
}