// lib/features/tickets/presentation/pages/main_menu_page.dart

import 'package:aquaspot_postventa/core/enum/segmento_operativo.dart';
import 'package:aquaspot_postventa/features/clientes/presentation/pages/gestion_clientes_page.dart';
import 'package:aquaspot_postventa/features/clientes/presentation/widgets/registro_cliente_bottom_sheet.dart';
import 'package:aquaspot_postventa/features/tickets/presentation/bloc/ticket_bloc.dart';
import 'package:aquaspot_postventa/features/tickets/presentation/bloc/ticket_event.dart';
import 'package:aquaspot_postventa/features/tickets/presentation/pages/BandejaBodegaPage.dart';
import 'package:aquaspot_postventa/features/tickets/presentation/pages/BandejaCostosPage.dart';
import 'package:aquaspot_postventa/features/tickets/domain/services/bandeja_costos_service.dart';
import 'package:aquaspot_postventa/features/tickets/presentation/pages/BandejaProformasEnviadasPage.dart';
import 'package:aquaspot_postventa/features/tickets/presentation/pages/BandejaRecepcionGuaboPage.dart';
import 'package:aquaspot_postventa/features/tickets/presentation/pages/BandejaTrabajosPage.dart';
import 'package:aquaspot_postventa/features/tickets/presentation/pages/ValidacionFacturacionPage.dart';
import 'package:aquaspot_postventa/features/tickets/presentation/pages/bandeja_comercial_Page.dart';
import 'package:aquaspot_postventa/features/tickets/presentation/pages/bandeja_compras_page.dart';
import 'package:aquaspot_postventa/features/tickets/presentation/pages/bandeja_entregas_page.dart';
import 'package:aquaspot_postventa/features/tickets/presentation/pages/bandeja_revisiones_garantias_page.dart';
import 'package:aquaspot_postventa/features/tickets/presentation/pages/bandeja_despacho_bodega_page.dart';
import 'package:aquaspot_postventa/features/tickets/presentation/pages/bandeja_recepcion_bodega_page.dart';
import 'package:aquaspot_postventa/features/inventario/presentation/pages/gestion_stock_bodega_page.dart';
import 'package:aquaspot_postventa/features/catalogo/presentation/pages/gestion_catalogo_actividades_page.dart';
import 'package:aquaspot_postventa/features/catalogo/presentation/pages/revision_codigos_plan_maestro_page.dart';
import 'package:aquaspot_postventa/features/tecnicos/presentation/pages/gestion_tecnicos_page.dart';
import 'package:aquaspot_postventa/features/fallas/presentation/pages/gestion_metricas_fallas_page.dart';
import 'package:aquaspot_postventa/features/tickets/presentation/pages/bandeja_fallas_pendientes_page.dart';
import 'package:aquaspot_postventa/features/tickets/presentation/pages/modificar_ticket_page.dart';
import 'package:aquaspot_postventa/features/tickets/presentation/pages/inconsistencias_trazabilidad_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';
import '../../domain/entities/usuario_entity.dart';
import '../../domain/services/menu_principal_service.dart';
import '../../../plan_preventivo/presentation/pages/plan_preventivo_page.dart';
import '../../../tickets/presentation/pages/creacion_ticket_page.dart';
import '../../../tickets/presentation/pages/historial_tickets_page.dart';
import '../../../tickets/presentation/pages/bandeja_evaluaciones_page.dart';
import '../../../tickets/domain/services/grupo_requerimiento_service.dart';
import '../../../tickets/presentation/pages/bandeja_recepcion_page.dart';
import '../../../tickets/presentation/pages/biblioteca_documentos_page.dart';
import '../../../../core/enum/rol_usuario.dart';
import '../pages/registro_usuario_page.dart';

class MainMenuPage extends StatefulWidget {
  const MainMenuPage({super.key});

  @override
  State<MainMenuPage> createState() => _MainMenuPageState();
}

class _MainMenuPageState extends State<MainMenuPage> {
  int _selectedIndex = 0;

  void _logout() {
    context.read<AuthBloc>().add(CerrarSesionEvent());
  }

 @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is Unauthenticated) {
          Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
        }
      },
      builder: (context, state) {
        if (state is! Authenticated) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final operador = state.usuario;
        final bool isAdmin = operador.rol == RolUsuario.admin;
        final bool esTecnico = operador.rol == RolUsuario.tecnico;

        // ✅ EL MULTIPLEXOR DE VISTAS 
        // Para técnicos internos, solo se habilita el módulo de recepción sin historial
        final List<Widget> modulosHMI = [
          _InicioView(operador: operador),
          if (!esTecnico) const HistorialTicketsPage(),
        ];

      return Scaffold(
          backgroundColor: const Color(0xFFF4F7F6),
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            title: Text(
              esTecnico
                  ? "Recepción Bodega - Aquaspot"
                  : (_selectedIndex == 1 ? "Panel de Historial" : "Aquaspot"),
              style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
            ),
            actions: [
              // 🚪 Botón directo de cerrar sesión para técnicos
              if (esTecnico)
                IconButton(
                  icon: const Icon(Icons.logout, color: Colors.red),
                  tooltip: 'Cerrar Sesión',
                  onPressed: _logout,
                ),

              // ⚙️ COMPUERTA LÓGICA: Acceso restringido a Comerciales y Administradores
              if (operador.rol.name.toLowerCase() == 'comercial' || isAdmin)
                IconButton(
                  icon: const Icon(Icons.person_add_alt_1, color: Colors.black54), // Color atenuado para no ser invasivo
                  tooltip: 'Registrar Cliente',
                  onPressed: () async {
                    // 🚀 DISPARO DEL BOTTOM SHEET (USANDO EL MÉTODO ESTÁTICO CORREGIDO)
                    // Esto evita el ProviderNotFoundException al inyectar su propio BLoC.
                    await RegistroClienteBottomSheet.show(context);
                  },
                ),
                
              if (!esTecnico)
                IconButton(icon: const Icon(Icons.notifications_none, color: Colors.black), onPressed: () {}),
              Padding(
                padding: const EdgeInsets.only(right: 16.0),
                child: CircleAvatar(
                  backgroundColor: const Color(0xFF005A9C),
                  child: Text(operador.email.isNotEmpty ? operador.email[0].toUpperCase() : 'U', style: const TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
          // ✅ EL CONMUTADOR
          body: IndexedStack(
            index: esTecnico ? 0 : _selectedIndex,
            children: modulosHMI,
          ),
          bottomNavigationBar: esTecnico
              ? SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                    child: SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.logout, size: 20),
                        label: const Text(
                          'Cerrar Sesión',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade700,
                          foregroundColor: Colors.white,
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: _logout,
                      ),
                    ),
                  ),
                )
              : BottomNavigationBar(
            currentIndex: _selectedIndex,
            selectedItemColor: const Color(0xFF005A9C),
            unselectedItemColor: Colors.grey,
            onTap: (index) {
              // 1. Condición de salida (Acción sin cambio de vista)
              if (index == 2) {
                _logout();
                return; // <-- CRÍTICO: Abortamos la ejecución aquí. El estado no se toca.
              }

              // 2. Disparos de eventos específicos por módulo
              if (index == 1) {
                // DISPARO DE ORDEN DE RECARGA GLOBAL
                context.read<TicketBloc>().add(
                  const ObtenerHistorialTicketsEvent(segmento: SegmentoOperativo.ninguno)
                );
              }

              // 3. Mutación de estado controlada (Solo llegará aquí si index es 0 o 1)
              setState(() {
                _selectedIndex = index;
              });
            },
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Inicio'),
              BottomNavigationBarItem(icon: Icon(Icons.history), label: 'Historial'),
              BottomNavigationBarItem(icon: Icon(Icons.exit_to_app), label: 'Salir'),
            ],
          ),
        );
      },
    );
  }
}

// =====================================================================
// SUB-RUTINA 1: PANEL DE INICIO (menú con buscador)
// Qué ve cada rol, las secciones y la búsqueda están en MenuPrincipalService;
// aquí solo el ícono, el color y la pantalla de cada opción.
// =====================================================================
typedef _M = MenuPrincipalService;

const _azulMenu = Color(0xFF005A9C);
const _azulOscuro = Color(0xFF003057);

/// Ícono, color y pantalla de cada opción del menú.
({IconData icono, Color color, Widget Function() pagina}) _vistaDe(OpcionMenu o) => switch (o) {
      OpcionMenu.crearTicket => (icono: Icons.add_box, color: Colors.blue, pagina: () => const CreacionTicketPage()),
      OpcionMenu.tickets => (icono: Icons.inventory_outlined, color: Colors.teal, pagina: () => const BandejaRecepcionPage()),
      OpcionMenu.biblioteca =>
        (icono: Icons.perm_media_outlined, color: Colors.indigo, pagina: () => const BibliotecaDocumentosPage()),
      OpcionMenu.recepcionGuabo =>
        (icono: Icons.car_rental, color: Colors.lightBlue, pagina: () => const BandejaRecepcionGuaboPage()),
      OpcionMenu.evaluaciones => (
          icono: Icons.handyman,
          color: Colors.orange,
          pagina: () => const BandejaEvaluacionesPage(grupo: GrupoRequerimiento.requerimientos)
        ),
      OpcionMenu.evaluacionesOt => (
          icono: Icons.build_circle_outlined,
          color: Colors.teal,
          pagina: () => const BandejaEvaluacionesPage(grupo: GrupoRequerimiento.ordenesTrabajo)
        ),
      OpcionMenu.procesoTrabajo => (
          icono: Icons.engineering,
          color: Colors.deepOrange,
          pagina: () => const BandejaTrabajosPage(grupo: GrupoRequerimiento.requerimientos)
        ),
      OpcionMenu.procesoTrabajoOt => (
          icono: Icons.precision_manufacturing_outlined,
          color: Colors.teal.shade700,
          pagina: () => const BandejaTrabajosPage(grupo: GrupoRequerimiento.ordenesTrabajo)
        ),
      OpcionMenu.recepcionBodega => (
          icono: Icons.assignment_turned_in_outlined,
          color: const Color(0xFF00796B),
          pagina: () => const BandejaRecepcionBodegaPage()
        ),
      OpcionMenu.garantias =>
        (icono: Icons.verified_user_outlined, color: Colors.green, pagina: () => const BandejaRevisionesGarantiasPage()),
      OpcionMenu.fallasTicketsAntiguos => (
          icono: Icons.playlist_add_check_circle_outlined,
          color: Colors.deepOrange,
          pagina: () => const BandejaFallasPendientesPage()
        ),
      OpcionMenu.clientes => (icono: Icons.people_alt, color: _azulMenu, pagina: () => const GestionClientesPage()),
      OpcionMenu.crearProforma => (icono: Icons.business_center, color: Colors.green, pagina: () => const BandejaComercialPage()),
      OpcionMenu.proformasEnviadas =>
        (icono: Icons.send_outlined, color: Colors.blue, pagina: () => const BandejaProformasEnviadasPage()),
      OpcionMenu.validacionEntregas =>
        (icono: Icons.fact_check, color: Colors.indigo, pagina: () => const BandejaValidacionFacturacionPage()),
      OpcionMenu.entregaFacturacion =>
        (icono: Icons.receipt_long, color: Colors.purple, pagina: () => const BandejaEntregasPage()),
      OpcionMenu.crearProyecto => (
          icono: Icons.account_balance_wallet,
          color: Colors.orange.shade800,
          pagina: () => const BandejaCostosPage(tarjeta: TarjetaCostos.creacionProyectos)
        ),
      OpcionMenu.creacionCodigos =>
        (icono: Icons.qr_code_2, color: Colors.teal, pagina: () => const BandejaCostosPage(tarjeta: TarjetaCostos.creacionCodigos)),
      OpcionMenu.compras => (icono: Icons.shopping_cart_outlined, color: Colors.orange.shade800, pagina: () => const BandejaComprasPage()),
      OpcionMenu.validacionBodegaCompras =>
        (icono: Icons.factory, color: Colors.blue.shade800, pagina: () => const BandejaBodegaPage()),
      OpcionMenu.despachoBodega =>
        (icono: Icons.local_shipping_outlined, color: _azulMenu, pagina: () => const BandejaDespachoBodegaPage()),
      OpcionMenu.inventario => (
          icono: Icons.inventory_2_outlined,
          color: const Color(0xFF2E7D32),
          pagina: () => const GestionStockBodegaPage()
        ),
      OpcionMenu.catalogoActividades =>
        (icono: Icons.menu_book, color: _azulMenu, pagina: () => const GestionCatalogoActividadesPage()),
      OpcionMenu.revisionCodigosPlanMaestro => (
          icono: Icons.fact_check_outlined,
          color: const Color(0xFF00796B),
          pagina: () => const RevisionCodigosPlanMaestroPage()
        ),
      OpcionMenu.planPreventivo =>
        (icono: Icons.event_repeat, color: const Color(0xFF2E7D32), pagina: () => const PlanPreventivoPage()),
      OpcionMenu.tecnicos => (icono: Icons.badge_outlined, color: _azulOscuro, pagina: () => const GestionTecnicosPage()),
      OpcionMenu.metricasFallas =>
        (icono: Icons.troubleshoot_outlined, color: Colors.blueGrey.shade700, pagina: () => const GestionMetricasFallasPage()),
      OpcionMenu.operarios =>
        (icono: Icons.admin_panel_settings, color: Colors.blueGrey, pagina: () => const RegistroUsuarioPage()),
      OpcionMenu.modificarTicket => (icono: Icons.edit_note, color: Colors.deepOrange, pagina: () => const ModificarTicketPage()),
      OpcionMenu.inconsistencias =>
        (icono: Icons.rule, color: Colors.amber.shade800, pagina: () => const InconsistenciasTrazabilidadPage()),
    };

class _InicioView extends StatefulWidget {
  final UsuarioEntity operador;

  const _InicioView({required this.operador});

  @override
  State<_InicioView> createState() => _InicioViewState();
}

class _InicioViewState extends State<_InicioView> {
  final _busqueda = TextEditingController();
  SeccionMenu? _seccion; // null = todas

  static const _dias = ['lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo'];
  static const _meses = [
    'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
    'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
  ];

  @override
  void dispose() {
    _busqueda.dispose();
    super.dispose();
  }

  String _fechaHoy() {
    final f = DateTime.now();
    return '${_dias[f.weekday - 1]} ${f.day} de ${_meses[f.month - 1]}';
  }

  void _abrir(OpcionMenu o) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => _vistaDe(o).pagina()));

  @override
  Widget build(BuildContext context) {
    final op = widget.operador;
    final todas = _M.visibles(rol: op.rol, email: op.email);
    final texto = _busqueda.text;
    final encontradas = _M.buscar(todas, texto);
    final grupos = _M.agrupar(encontradas).where((g) => _seccion == null || g.$1 == _seccion).toList();
    final seccionesDisponibles = _M.agrupar(todas).map((g) => g.$1).toList();
    final nombre = op.nombre.trim().isNotEmpty ? op.nombre.trim().split(RegExp(r'\s+')).first : op.rol.name;

    return LayoutBuilder(builder: (context, c) {
      final columnas = c.maxWidth < 600 ? 2 : (c.maxWidth < 1000 ? 3 : 4);
      return CustomScrollView(slivers: [
        // Encabezado con saludo y buscador.
        SliverToBoxAdapter(
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [_azulMenu, _azulOscuro], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
            ),
            child: Center(
              child: ConstrainedBox(
                // Mismo ancho útil que la cuadrícula (1100 - 2 × 16).
                constraints: const BoxConstraints(maxWidth: 1068),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_fechaHoy(), style: const TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 4),
                  Row(children: [
                    Flexible(
                      child: Text('Hola, $nombre',
                          style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(20)),
                      child: Text(op.rol.name.toUpperCase(),
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ]),
                  const SizedBox(height: 16),
                  Material(
                    elevation: 4,
                    shadowColor: Colors.black26,
                    borderRadius: BorderRadius.circular(16),
                    child: TextField(
                      controller: _busqueda,
                      onChanged: (_) => setState(() {}),
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) {
                        if (encontradas.length == 1) _abrir(encontradas.single);
                      },
                      decoration: InputDecoration(
                        hintText: 'Buscar: compras, preventivo, stock…',
                        prefixIcon: const Icon(Icons.search, color: _azulMenu),
                        suffixIcon: texto.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Limpiar',
                                icon: const Icon(Icons.close),
                                onPressed: () => setState(_busqueda.clear),
                              ),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(vertical: 16),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ),
        // Chips de sección.
        if (seccionesDisponibles.length > 1)
          SliverToBoxAdapter(
            child: _Centrado(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                  child: Row(children: [
                    _chip('Todas', _seccion == null, () => setState(() => _seccion = null)),
                    for (final s in seccionesDisponibles)
                      _chip(s.etiqueta, _seccion == s, () => setState(() => _seccion = _seccion == s ? null : s)),
                  ]),
                ),
            ),
          ),
        if (grupos.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.search_off, size: 56, color: Colors.grey.shade400),
                const SizedBox(height: 8),
                Text(
                  texto.trim().isEmpty ? 'No hay opciones para tu rol.' : 'Sin resultados para "${texto.trim()}".',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 15),
                  textAlign: TextAlign.center,
                ),
              ]),
            ),
          )
        else
          for (final (seccion, opciones) in grupos) ...[
            SliverToBoxAdapter(
              child: _Centrado(
                child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                    child: Text(seccion.etiqueta.toUpperCase(),
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.1, color: Colors.grey.shade600)),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: _Centrado(
                child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: LayoutBuilder(builder: (context, c2) {
                      const espacio = 12.0;
                      final ancho = (c2.maxWidth - espacio * (columnas - 1)) / columnas;
                      return Wrap(spacing: espacio, runSpacing: espacio, children: [
                        for (final o in opciones)
                          SizedBox(
                            width: ancho,
                            child: _TarjetaMenu(opcion: o, busqueda: texto, onTap: () => _abrir(o)),
                          ),
                      ]);
                    }),
                ),
              ),
            ),
          ],
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ]);
    });
  }

  Widget _chip(String texto, bool elegido, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(texto),
          selected: elegido,
          onSelected: (_) => onTap(),
          selectedColor: _azulMenu,
          labelStyle: TextStyle(color: elegido ? Colors.white : Colors.black87, fontWeight: FontWeight.w600),
          showCheckmark: false,
        ),
      );
}

/// Ancho máximo de 1100 centrado en pantallas grandes, con el contenido
/// alineado a la izquierda.
class _Centrado extends StatelessWidget {
  final Widget child;

  const _Centrado({required this.child});

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: SizedBox(width: double.infinity, child: child),
        ),
      );
}

/// Tarjeta de una opción: ícono en un círculo de color, título (con lo
/// buscado resaltado) y descripción corta; se eleva al pasar el mouse.
class _TarjetaMenu extends StatefulWidget {
  final OpcionMenu opcion;
  final String busqueda;
  final VoidCallback onTap;

  const _TarjetaMenu({required this.opcion, required this.busqueda, required this.onTap});

  @override
  State<_TarjetaMenu> createState() => _TarjetaMenuState();
}

class _TarjetaMenuState extends State<_TarjetaMenu> {
  bool _encima = false;

  List<TextSpan> _titulo(String titulo, Color color) {
    final tramos = _M.resaltar(titulo, widget.busqueda);
    const base = TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87);
    if (tramos.isEmpty) return [TextSpan(text: titulo, style: base)];
    final spans = <TextSpan>[];
    var i = 0;
    for (final (ini, fin) in tramos) {
      if (ini > i) spans.add(TextSpan(text: titulo.substring(i, ini), style: base));
      spans.add(TextSpan(
        text: titulo.substring(ini, fin),
        style: base.copyWith(color: color, backgroundColor: color.withValues(alpha: 0.12)),
      ));
      i = fin;
    }
    if (i < titulo.length) spans.add(TextSpan(text: titulo.substring(i), style: base));
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final d = _M.datos[widget.opcion]!;
    final v = _vistaDe(widget.opcion);
    return MouseRegion(
      onEnter: (_) => setState(() => _encima = true),
      onExit: (_) => setState(() => _encima = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        transform: Matrix4.translationValues(0, _encima ? -3 : 0, 0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _encima ? v.color.withValues(alpha: 0.5) : Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: _encima ? 0.10 : 0.04),
              blurRadius: _encima ? 16 : 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: widget.onTap,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(color: v.color.withValues(alpha: 0.12), shape: BoxShape.circle),
                  child: Icon(v.icono, color: v.color, size: 24),
                ),
                const SizedBox(height: 10),
                Text.rich(TextSpan(children: _titulo(d.titulo, v.color)), maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text(d.descripcion,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600, height: 1.3)),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
