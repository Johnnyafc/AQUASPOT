// lib/features/tickets/domain/services/grupo_requerimiento_service.dart
//
// 🗂️ Tarjetas separadas en Evaluación Técnica y Proceso de Trabajo: los
// REQUERIMIENTOS (reparación, garantía, venta…) y las OT (mantenimiento
// interno). Se separa por tipo, no por el código, así los mantenimientos
// creados antes con código REQ-… también van a la de OT. Probado en
// test/grupo_requerimiento_test.dart.

import '../entities/ticket_entity.dart';

enum GrupoRequerimiento { requerimientos, ordenesTrabajo }

class GrupoRequerimientoService {
  static GrupoRequerimiento de(TicketEntity t) =>
      t.esMantenimientoInterno ? GrupoRequerimiento.ordenesTrabajo : GrupoRequerimiento.requerimientos;

  static bool pertenece(GrupoRequerimiento grupo, TicketEntity t) => de(t) == grupo;
}
