// lib/core/utils/constants.dart

/// Cuenta administradora maestra: única que ve "Modificar Ticket" (menú
/// principal) y "Tickets con posibles inconsistencias" (dashboard).
const String correoAdministradorMaestro = 'adminmaster@aquaspot.ec';

bool esAdministradorMaestro(String email) => email.trim().toLowerCase() == correoAdministradorMaestro;

/// Ronda vigente de revisión del diagnóstico de fallas. Un ticket con
/// `rondaDiagnosticoFallas` menor a este valor vuelve a salir en la bandeja
/// "Fallas Pendientes por Diagnosticar" hasta que se guarde de nuevo. Para
/// pedir una nueva revisión de todos los tickets basta con subir este número.
const int rondaRevisionDiagnosticoFallas = 1;

/// Lista estándar de razones del problema (causa raíz) usada como catálogo
/// base para clasificar fallas diagnosticadas, cuando una falla todavía no
/// tiene razones propias configuradas en el catálogo de fallas.
/// Ver: gestion_metricas_fallas_page.dart, agregar_diagnostico_falla_page.dart.
const List<String> razonesProblemaEstandar = [
  'Diseño defectuoso',
  'Defecto de materiales',
  'Deficiencias de fabricación',
  'Defectos de instalación',
  'Condiciones de servicio',
  'Deficiencias de mantenimiento',
  'Operación incorrecta',
];
