// lib/features/auth/domain/services/menu_principal_service.dart
//
// 🧭 Reglas del MENÚ PRINCIPAL (solo reglas puras, sin Flutter ni Firebase;
// probado en test/menu_principal_test.dart):
// - Qué opciones ve cada rol (los mismos permisos que tenía el menú; la
//   cuenta administradora maestra además ve "Modificar Ticket" e
//   "Inconsistencias de Trazabilidad"). Sin opciones repetidas.
// - Secciones (Tickets, Taller, Comercial, Costos y Compras, Bodega,
//   Catálogos y Planes, Administración) y su orden.
// - Buscador: sin tildes ni mayúsculas, todas las palabras, por título,
//   descripción, sección y palabras clave (ej. "stock" → Inventario).

import '../../../../core/enum/rol_usuario.dart';
import '../../../../core/utils/constants.dart' show esAdministradorMaestro;

enum SeccionMenu { tickets, taller, comercial, costosCompras, bodega, catalogos, administracion }

extension SeccionMenuX on SeccionMenu {
  String get etiqueta => switch (this) {
        SeccionMenu.tickets => 'Tickets',
        SeccionMenu.taller => 'Taller',
        SeccionMenu.comercial => 'Comercial',
        SeccionMenu.costosCompras => 'Costos y Compras',
        SeccionMenu.bodega => 'Bodega',
        SeccionMenu.catalogos => 'Catálogos y Planes',
        SeccionMenu.administracion => 'Administración',
      };
}

enum OpcionMenu {
  crearTicket,
  tickets,
  biblioteca,
  recepcionGuabo,
  evaluaciones,
  evaluacionesOt,
  procesoTrabajo,
  procesoTrabajoOt,
  recepcionBodega,
  garantias,
  fallasTicketsAntiguos,
  clientes,
  crearProforma,
  proformasEnviadas,
  validacionEntregas,
  entregaFacturacion,
  crearProyecto,
  creacionCodigos,
  compras,
  validacionBodegaCompras,
  despachoBodega,
  inventario,
  catalogoActividades,
  revisionCodigosPlanMaestro,
  planPreventivo,
  tecnicos,
  metricasFallas,
  operarios,
  modificarTicket,
  inconsistencias,
}

class DatosOpcionMenu {
  final String titulo;
  final String descripcion;
  final SeccionMenu seccion;
  final List<String> palabrasClave;

  const DatosOpcionMenu(this.titulo, this.descripcion, this.seccion, [this.palabrasClave = const []]);
}

class MenuPrincipalService {
  static const Map<OpcionMenu, DatosOpcionMenu> datos = {
    OpcionMenu.crearTicket: DatosOpcionMenu('Crear Ticket', 'Nuevo requerimiento: reparación, garantía, venta o mantenimiento',
        SeccionMenu.tickets, ['nuevo', 'requerimiento', 'crear', 'mantenimiento interno', 'venta de repuesto']),
    OpcionMenu.tickets: DatosOpcionMenu('Tickets', 'Recepción y seguimiento de tickets', SeccionMenu.tickets,
        ['recepcion', 'bandeja', 'requerimientos']),
    OpcionMenu.biblioteca: DatosOpcionMenu('Biblioteca de Documentos', 'Informes, actas, fotos y archivos de cada ticket',
        SeccionMenu.tickets, ['pdf', 'excel', 'fotos', 'videos', 'archivos', 'documentos', 'informe']),
    OpcionMenu.recepcionGuabo: DatosOpcionMenu('Recepción del Guabo', 'Equipos que llegan al taller del Guabo',
        SeccionMenu.taller, ['guabo', 'llegada', 'recepcion']),
    OpcionMenu.evaluaciones: DatosOpcionMenu('Evaluaciones técnicas', 'Requerimientos: diagnóstico, actividades y solicitud de materiales',
        SeccionMenu.taller, ['evaluacion', 'diagnostico', 'tecnico', 'informe', 'requerimiento', 'reparacion']),
    OpcionMenu.evaluacionesOt: DatosOpcionMenu('Evaluaciones de OT', 'Mantenimiento interno: diagnóstico, actividades y materiales',
        SeccionMenu.taller, ['evaluacion', 'ot', 'orden de trabajo', 'mantenimiento', 'interno']),
    OpcionMenu.procesoTrabajo: DatosOpcionMenu('Proceso de trabajo', 'Requerimientos: trabajos en el taller y retiro de materiales',
        SeccionMenu.taller, ['taller', 'trabajo', 'reparacion', 'retiro', 'requerimiento']),
    OpcionMenu.procesoTrabajoOt: DatosOpcionMenu('Proceso de trabajo OT', 'Mantenimiento interno: trabajos y retiro de materiales',
        SeccionMenu.taller, ['taller', 'trabajo', 'ot', 'orden de trabajo', 'mantenimiento', 'interno']),
    OpcionMenu.recepcionBodega: DatosOpcionMenu('Recepción Bodega', 'Recibir repuestos y materiales en el taller',
        SeccionMenu.taller, ['recibir', 'materiales', 'repuestos']),
    OpcionMenu.garantias: DatosOpcionMenu('Revisión de garantías', 'Dictamen de los reclamos de garantía',
        SeccionMenu.taller, ['garantia', 'reclamo', 'dictamen']),
    OpcionMenu.fallasTicketsAntiguos: DatosOpcionMenu('Agregar Fallas a Tickets Antiguos',
        'Diagnóstico de fallas retroactivo', SeccionMenu.taller, ['fallas', 'diagnostico', 'antiguos']),
    OpcionMenu.clientes: DatosOpcionMenu('Gestión y Edición de Clientes', 'Datos de clientes y contactos',
        SeccionMenu.comercial, ['cliente', 'contacto', 'camaronera']),
    OpcionMenu.crearProforma: DatosOpcionMenu('Crear proforma', 'Propuesta comercial de los tickets evaluados',
        SeccionMenu.comercial, ['proforma', 'cotizacion', 'propuesta', 'precio']),
    OpcionMenu.proformasEnviadas: DatosOpcionMenu('Proformas enviadas', 'Seguimiento y aceptación del cliente',
        SeccionMenu.comercial, ['proforma', 'aceptacion', 'orden de venta', 'ov']),
    OpcionMenu.validacionEntregas: DatosOpcionMenu('Validación entregas comercial', 'Revisión antes de facturar',
        SeccionMenu.comercial, ['facturacion', 'validacion', 'entrega']),
    OpcionMenu.entregaFacturacion: DatosOpcionMenu('Entrega y facturación', 'Entrega al cliente y factura',
        SeccionMenu.comercial, ['factura', 'entrega', 'guia']),
    OpcionMenu.crearProyecto: DatosOpcionMenu('Creación de proyectos', 'Costos: código de proyecto de cada requerimiento',
        SeccionMenu.costosCompras, ['costos', 'proyecto', 'crear proyecto', 'erp']),
    OpcionMenu.creacionCodigos: DatosOpcionMenu('Creación de códigos', 'Costos: códigos de repuestos sin código en el ERP',
        SeccionMenu.costosCompras, ['costos', 'codigo', 'crear codigo', 'repuesto', 'erp', 'ficha']),
    OpcionMenu.compras: DatosOpcionMenu('Compras', 'Órdenes de compra y cotizaciones de repuestos',
        SeccionMenu.costosCompras, ['oc', 'orden de compra', 'cotizar', 'proveedor']),
    OpcionMenu.validacionBodegaCompras: DatosOpcionMenu('Validación Bodega (Compras)', 'Confirmar que los repuestos llegaron',
        SeccionMenu.costosCompras, ['validar', 'llegada', 'repuestos']),
    OpcionMenu.despachoBodega: DatosOpcionMenu('Despacho Bodega', 'Picking y despacho de repuestos al taller',
        SeccionMenu.bodega, ['picking', 'despacho', 'entregar', 'pick']),
    OpcionMenu.inventario: DatosOpcionMenu('Inventario y Stock Bodega', 'Existencias y carga del inventario',
        SeccionMenu.bodega, ['stock', 'existencias', 'inventario', 'repuestos']),
    OpcionMenu.catalogoActividades: DatosOpcionMenu('Catálogo de Actividades y Repuestos', 'Plan Maestro por equipo',
        SeccionMenu.catalogos, ['plan maestro', 'actividades', 'catalogo', 'mano de obra']),
    OpcionMenu.revisionCodigosPlanMaestro: DatosOpcionMenu('Revisión de Códigos del Plan Maestro',
        'Códigos del plan contra el inventario', SeccionMenu.catalogos, ['codigos', 'plan maestro', 'revision']),
    OpcionMenu.planPreventivo: DatosOpcionMenu('Plan Preventivo', 'Agregar actividades de mantenimiento preventivo',
        SeccionMenu.catalogos, ['preventivo', 'mantenimiento', 'frecuencia', 'actividades', 'maquinas']),
    OpcionMenu.tecnicos: DatosOpcionMenu('Catálogo de Técnicos', 'Técnicos del taller', SeccionMenu.catalogos,
        ['tecnicos', 'personal']),
    OpcionMenu.metricasFallas: DatosOpcionMenu('Métricas de Fallas', 'Categorías, partes y razones de falla',
        SeccionMenu.catalogos, ['fallas', 'metricas', 'categorias', 'partes', 'razones']),
    OpcionMenu.operarios: DatosOpcionMenu('Gestión de Operarios', 'Usuarios y roles de la app',
        SeccionMenu.administracion, ['usuarios', 'roles', 'operarios', 'registro']),
    OpcionMenu.modificarTicket: DatosOpcionMenu('Modificar Ticket', 'Cambiar el estado de un ticket con motivo',
        SeccionMenu.administracion, ['estado', 'admin', 'modificar']),
    OpcionMenu.inconsistencias: DatosOpcionMenu('Inconsistencias de Trazabilidad', 'Revisar tickets con trazabilidad rota',
        SeccionMenu.administracion, ['trazabilidad', 'auditoria', 'inconsistencias']),
  };

  // ------------------------------------------------------------ Permisos
  static bool puedeVer(OpcionMenu o, {required RolUsuario rol, required String email}) {
    bool es(List<RolUsuario> roles) => rol == RolUsuario.admin || roles.contains(rol);
    return switch (o) {
      OpcionMenu.biblioteca => rol != RolUsuario.tecnico,
      OpcionMenu.modificarTicket || OpcionMenu.inconsistencias => esAdministradorMaestro(email),
      OpcionMenu.operarios => rol == RolUsuario.admin,
      OpcionMenu.crearTicket => es([RolUsuario.requerimiento, RolUsuario.supervisor, RolUsuario.comercial]),
      OpcionMenu.tickets => es([RolUsuario.supervisor, RolUsuario.recepcion]),
      OpcionMenu.recepcionGuabo ||
      OpcionMenu.evaluaciones ||
      OpcionMenu.evaluacionesOt ||
      OpcionMenu.procesoTrabajo ||
      OpcionMenu.procesoTrabajoOt =>
        es([RolUsuario.supervisor]),
      OpcionMenu.recepcionBodega => es([RolUsuario.tecnico, RolUsuario.supervisor]),
      OpcionMenu.garantias ||
      OpcionMenu.catalogoActividades ||
      OpcionMenu.revisionCodigosPlanMaestro ||
      OpcionMenu.planPreventivo ||
      OpcionMenu.tecnicos ||
      OpcionMenu.metricasFallas ||
      OpcionMenu.fallasTicketsAntiguos =>
        es([RolUsuario.supervisor]),
      OpcionMenu.clientes ||
      OpcionMenu.crearProforma ||
      OpcionMenu.proformasEnviadas ||
      OpcionMenu.validacionEntregas ||
      OpcionMenu.entregaFacturacion =>
        es([RolUsuario.comercial]),
      OpcionMenu.crearProyecto || OpcionMenu.creacionCodigos => es([RolUsuario.costos]),
      OpcionMenu.compras || OpcionMenu.validacionBodegaCompras => es([RolUsuario.compras]),
      OpcionMenu.inventario => es([RolUsuario.compras, RolUsuario.bodega]),
      OpcionMenu.despachoBodega => es([RolUsuario.bodega]),
    };
  }

  /// Opciones que ve el usuario, en el orden del menú (sin repetir).
  static List<OpcionMenu> visibles({required RolUsuario rol, required String email}) =>
      [for (final o in OpcionMenu.values) if (puedeVer(o, rol: rol, email: email)) o];

  /// Agrupadas por sección, en el orden de las secciones (solo las que
  /// tienen opciones).
  static List<(SeccionMenu, List<OpcionMenu>)> agrupar(List<OpcionMenu> opciones) => [
        for (final s in SeccionMenu.values)
          if (opciones.any((o) => datos[o]!.seccion == s)) (s, [for (final o in opciones) if (datos[o]!.seccion == s) o]),
      ];

  // ------------------------------------------------------------ Buscador
  /// Minúsculas y sin tildes (misma longitud que el texto original).
  static String normalizar(String s) {
    const de = 'áàäâéèëêíìïîóòöôúùüûñ';
    const a = 'aaaaeeeeiiiioooouuuun';
    final b = StringBuffer();
    for (final ch in s.toLowerCase().split('')) {
      final i = de.indexOf(ch);
      b.write(i >= 0 ? a[i] : ch);
    }
    return b.toString();
  }

  static List<String> _palabras(String texto) =>
      normalizar(texto).split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();

  /// Opciones que contienen todas las palabras buscadas.
  static List<OpcionMenu> buscar(List<OpcionMenu> opciones, String texto) {
    final palabras = _palabras(texto);
    if (palabras.isEmpty) return opciones;
    return [
      for (final o in opciones)
        if (palabras.every(_textoBuscable(o).contains)) o,
    ];
  }

  static String _textoBuscable(OpcionMenu o) {
    final d = datos[o]!;
    return normalizar('${d.titulo} ${d.descripcion} ${d.seccion.etiqueta} ${d.palabrasClave.join(' ')}');
  }

  /// Tramos [inicio, fin) del [titulo] que coinciden con lo buscado (para
  /// resaltarlos), ordenados y sin solaparse.
  static List<(int, int)> resaltar(String titulo, String texto) {
    final t = normalizar(titulo);
    final tramos = <(int, int)>[];
    for (final p in _palabras(texto)) {
      var i = t.indexOf(p);
      while (i >= 0) {
        tramos.add((i, i + p.length));
        i = t.indexOf(p, i + p.length);
      }
    }
    tramos.sort((a, b) => a.$1.compareTo(b.$1));
    final unidos = <(int, int)>[];
    for (final r in tramos) {
      if (unidos.isNotEmpty && r.$1 <= unidos.last.$2) {
        final u = unidos.removeLast();
        unidos.add((u.$1, r.$2 > u.$2 ? r.$2 : u.$2));
      } else {
        unidos.add(r);
      }
    }
    return unidos;
  }
}
