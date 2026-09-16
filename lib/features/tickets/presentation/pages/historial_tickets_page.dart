// lib/features/tickets/presentation/pages/historial_tickets_page.dart

import 'package:aquaspot_postventa/core/enum/segmento_operativo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/ticket_bloc.dart';
import '../bloc/ticket_event.dart';
import '../bloc/ticket_state.dart'; 
import '../../../../core/enum/ticket_enums.dart';
import '../../domain/entities/ticket_entity.dart';
import 'detalle_ticket_page.dart';
import 'dashboard_tickets_page.dart';
import '../widgets/tiempo_en_curso_widget.dart';
import '../../../../core/theme/ticket_visual_theme.dart';

class HistorialTicketsPage extends StatefulWidget {
  const HistorialTicketsPage({super.key});

  @override
  State<HistorialTicketsPage> createState() => _HistorialTicketsPageState();
}

class _HistorialTicketsPageState extends State<HistorialTicketsPage> {
  // ⚙️ SENSORES DE BÚSQUEDA LOCAL
  final TextEditingController _searchController = TextEditingController();
  String _filtroBusqueda = '';

  @override
  void initState() {
    super.initState();
    // ⚙️ LLAVE MAESTRA: Solicitamos telemetría GLOBAL
    context.read<TicketBloc>().add(
      const ObtenerHistorialTicketsEvent(segmento: SegmentoOperativo.ninguno)
    );
  }

  @override
  void dispose() {
    // 🧹 MANTENIMIENTO: Liberamos los pines de memoria del controlador
    _searchController.dispose();
    super.dispose();
  }

  // =========================================================================
  // ⚙️ DECODIFICADORES HMI (Transformación de datos crudos a interfaz visual)
  // =========================================================================

  // 🔧 ANTES: 12 colores muy saturados y sin relación entre sí, uno por
  // cada EstadoTicket — en Historial (que mezcla tickets de CUALQUIER
  // estado en la misma pantalla) esto se veía como un arcoíris compitiendo
  // por la atención. Ahora se delega a `colorPorEstadoTicket` (ver
  // ticket_visual_theme.dart): solo 4 colores semánticos (nuevo / en
  // proceso / finalizado / anulado) — el nombre del estado (ej. "COMPRAS",
  // "BODEGA") sigue distinguiendo cada paso, el color ya no.
  Color _getColorPorEstado(EstadoTicket estado) => colorPorEstadoTicket(estado);

  String _formatearNombreEstado(String camelCase) {
    for (final estado in EstadoTicket.values) {
      if (estado.name == camelCase) return estado.nombreMayusculas;
    }
    RegExp exp = RegExp(r'(?<=[a-z])[A-Z]');
    String conEspacios = camelCase.replaceAllMapped(exp, (m) => ' ${m.group(0)}');
    return conEspacios.toUpperCase();
  }

  IconData _getIconoPorEstado(EstadoTicket estado) {
    switch (estado) {
      case EstadoTicket.creado: return Icons.fiber_new;
      case EstadoTicket.revisionGarantia: return Icons.policy;
      case EstadoTicket.recepcionFisica: return Icons.handyman;
      case EstadoTicket.enCamino: return Icons.local_shipping;
      case EstadoTicket.comercial: return Icons.point_of_sale;
      case EstadoTicket.cotizado: return Icons.request_quote;
      case EstadoTicket.costos: return Icons.account_balance_wallet;
      case EstadoTicket.compras: return Icons.shopping_cart;
      case EstadoTicket.bodega: return Icons.inventory;
      case EstadoTicket.procesoTrabajo: return Icons.engineering;
      case EstadoTicket.validacionFacturacion: return Icons.loupe;
      case EstadoTicket.finalizado: return Icons.task_alt;
      case EstadoTicket.anulado: return Icons.cancel;
      case EstadoTicket.entrega: return Icons.add_box;
    }
  }

  // 🧠 ALGORITMO DE ESCANEO PROFUNDO (Deep Search)
  bool _ticketCumpleFiltroGlobal(TicketEntity t, String query) {
    if (query.isEmpty) return true;
    
    // Inyectamos todas las variables del ticket en un solo bloque de memoria para escaneo rápido
    final dataCruda = '''
      ${t.id} ${t.clienteId} ${t.numeroSerie ?? ''} ${t.campamento}
      ${t.nombreContacto} ${t.telefonoContacto} ${t.fallaReportada}
      ${t.equipo.name} ${t.sede.name} ${t.marca} ${t.codigoProyecto ?? ''}
      ${t.numeroOrdenVenta ?? ''} ${t.tipoGarantia ?? ''}
      ${t.estadoActual.name}
    '''.toLowerCase();

    return dataCruda.contains(query);
  }

  // =========================================================================
  // 🚀 CONSTRUCTOR DE LA VISTA PRINCIPAL
  // =========================================================================

  @override
  Widget build(BuildContext context) {
    final bool modoBusquedaGlobal = _filtroBusqueda.isNotEmpty;

    return DefaultTabController(
      // 🆕 +1: agregamos la pestaña "TODOS" al inicio, además de una por cada estado.
      length: EstadoTicket.values.length + 1,
      // ⚙️ NOTA DE ARQUITECTURA (fix del "contenedor de origen"):
      // Esta página SOLO se usa embebida dentro del IndexedStack de
      // main_menu_page.dart, que ya aporta su propio Scaffold con AppBar
      // ("Aquaspot") y BottomNavigationBar. Antes esta página traía SU
      // PROPIO Scaffold+AppBar ("Panel de Historial"), y al anidar un
      // Scaffold dentro de otro, el AppBar interno repetía el padding del
      // área segura superior (status bar) y sumaba otros ~56px de barra
      // de herramientas — puro espacio duplicado que le robaba alto útil
      // a la lista/grid de tickets y dejaba las tarjetas de "TODOS"
      // apretadas contra el BottomNavigationBar. Se reemplaza el
      // Scaffold+AppBar por un simple Column con una cabecera compacta
      // (Material, sin padding de status bar) para que main_menu_page.dart
      // sea el único que reserva espacio de chrome en toda la pantalla.
      child: Column(
        children: [
          // ==========================================
          // 🏷️ CABECERA COMPACTA: título + pestañas (sin Scaffold/AppBar propio)
          // ==========================================
          if (!modoBusquedaGlobal)
            Material(
              // 🔧 El título "Panel de Historial" ya lo muestra el AppBar de
              // main_menu_page.dart (contextual según la pestaña activa), así
              // que aquí ya no repetimos el texto: solo queda la barra de
              // pestañas, recuperando el alto que antes ocupaba el título
              // duplicado.
              color: const Color(0xFF005A9C),
              child: TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white60,
                indicatorColor: Colors.orange,
                indicatorWeight: 4,
                tabs: [
                  // 🆕 PESTAÑA "TODOS": ve todos los tickets sin importar su estado.
                  const Tab(
                    icon: Icon(Icons.all_inbox),
                    text: 'TODOS',
                  ),
                  ...EstadoTicket.values.map((estado) {
                    return Tab(
                      icon: Icon(_getIconoPorEstado(estado)),
                      text: _formatearNombreEstado(estado.name)
                    );
                  }),
                ],
              ),
            ),

          // ==========================================
          // 🔍 PANEL DE BÚSQUEDA (Actuador Frontal)
          // ==========================================
          Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: Colors.white,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Búsqueda Global (ID, Serie, Falla, Cliente, etc)...',
                        prefixIcon: const Icon(Icons.saved_search, color: Color(0xFF005A9C), size: 28),
                        suffixIcon: modoBusquedaGlobal
                            ? IconButton(
                                icon: const Icon(Icons.clear, color: Colors.red),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _filtroBusqueda = ''); // Reset del relé
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        contentPadding: const EdgeInsets.symmetric(vertical: 0),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF005A9C), width: 2),
                        ),
                      ),
                      onChanged: (valor) {
                        // 🔄 RELE DE ESTADO: Repinta la matriz filtrada en tiempo real
                        setState(() {
                          _filtroBusqueda = valor.trim().toLowerCase();
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  // 📊 NUEVA OPCIÓN: "Dashboard". Reutiliza los tickets que YA están
                  // cargados en memoria (state.historial, descargado una sola vez por
                  // ObtenerHistorialTicketsEvent) — abrir el dashboard, cambiar sus
                  // filtros o reordenar su tabla NO dispara ninguna lectura adicional
                  // a Firestore, así que no afecta la cuenta de pago de Aquaspot.
                  Material(
                    color: const Color(0xFF005A9C).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    child: IconButton(
                      tooltip: 'Dashboard',
                      icon: const Icon(Icons.analytics_outlined, color: Color(0xFF005A9C)),
                      onPressed: () {
                        final ticketsActuales = context.read<TicketBloc>().state.historial;
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => DashboardTicketsPage(tickets: ticketsActuales)),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

            // ==========================================
            // 🛡️ BUCLE PRINCIPAL DE DATOS (Telemetría)
            // ==========================================
            Expanded(
              child: BlocBuilder<TicketBloc, TicketState>(
                buildWhen: (previous, current) => previous.status != current.status,
                builder: (context, state) {
                  
                  // 1. ESTADO DE TRABAJO (Lectura de sensores en curso)
                  if (state.status == TicketStatus.loading) {
                    return const Center(child: CircularProgressIndicator(color: Color(0xFF005A9C)));
                  } 
                  
                  // 2. ESTADO DE ALARMA (Falla de red o lógica)
                  if (state.status == TicketStatus.error) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.warning_amber_rounded, size: 50, color: Colors.red),
                          const SizedBox(height: 16),
                          Text(state.message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
                          TextButton(
                            onPressed: () => context.read<TicketBloc>().add(const ObtenerHistorialTicketsEvent(segmento: SegmentoOperativo.general)),
                            child: const Text('REINTENTAR CONEXIÓN'),
                          )
                        ],
                      ),
                    );
                  } 
                  
                  // 3. ESTADO DE LECTURA EXITOSA
                  if (state.status == TicketStatus.loaded || state.status == TicketStatus.operationSuccess) {
                    
                    // ⚙️ MODO 1: BÚSQUEDA GLOBAL ACTIVADA (Ignora las pestañas)
                    if (modoBusquedaGlobal) {
                      final ticketsFiltrados = state.historial
                          .where((t) => _ticketCumpleFiltroGlobal(t, _filtroBusqueda))
                          .toList();
                          
                      return _buildListaTickets(
                        ticketsFiltrados, 
                        "No se encontraron tickets en toda la planta que coincidan con:\n'$_filtroBusqueda'"
                      );
                    }
                    
                    // ⚙️ MODO 2: NAVEGACIÓN NORMAL (Por Pestañas)
                    return TabBarView(
                      children: [
                        // 🆕 PESTAÑA "TODOS": resumen general + la lista completa, sin filtrar por estado.
                        // 🔧 FIX "TARJETA FIJA": el resumen ya NO va afuera en un Column con
                        // Expanded (eso lo dejaba fijo, robándole espacio a la lista). Ahora se
                        // pasa como `header` para que viva DENTRO del mismo scroll que las
                        // tarjetas: al desplazar hacia abajo, el resumen se va con la lista y
                        // deja ver los siguientes tickets.
                        _buildListaTickets(
                          state.historial,
                          "No hay tickets registrados en el sistema.",
                          header: _buildResumenGeneral(state.historial),
                        ),
                        ...EstadoTicket.values.map((estadoTicketActual) {
                          final ticketsFiltrados = state.historial
                              .where((t) => t.estadoActual == estadoTicketActual)
                              .toList();

                          final nombreEstado = _formatearNombreEstado(estadoTicketActual.name);

                          return _buildListaTickets(
                            ticketsFiltrados,
                            "No hay equipos en fase:\n$nombreEstado"
                          );
                        }),
                      ],
                    );
                  }
                  
                  return const SizedBox.shrink();
                },
              ),
            ),
          ],
        ),
    ); // 🔧 cierra DefaultTabController (child: Column; ya no hay Scaffold anidado que cerrar)
  }



  // =========================================================================
  // 📊 WIDGET HELPER: Resumen General (solo en la pestaña "TODOS")
  // =========================================================================

  Widget _buildResumenGeneral(List<TicketEntity> tickets) {
    final int total = tickets.length;
    final int totalGarantias = tickets.where((t) => t.esGarantia == true).length;
    final int totalCaracol = tickets.where((t) => t.equipo == TipoEquipo.Caracol).length;
    final int totalCosechadora = tickets.where((t) => t.equipo == TipoEquipo.Cosechadora).length;
    final int totalContador = tickets.where((t) => t.equipo == TipoEquipo.Contador).length;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.analytics_outlined, color: Color(0xFF005A9C)),
              const SizedBox(width: 8),
              const Text(
                'Resumen General',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF005A9C)),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF005A9C).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'TOTAL: $total',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF005A9C), fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 🚜 POR GARANTÍA Y TIPO DE EQUIPO
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildChipResumen('Garantías', totalGarantias, Colors.red, Icons.policy),
              _buildChipResumen('Caracol', totalCaracol, Colors.brown, Icons.rotate_right),
              _buildChipResumen('Cosechadora', totalCosechadora, Colors.green.shade700, Icons.agriculture),
              _buildChipResumen('Contador', totalContador, Colors.blueGrey, Icons.speed),
            ],
          ),

          const Divider(height: 24),

          // 📊 POR ESTADO
          const Text(
            'Por estado:',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: EstadoTicket.values.map((estado) {
              final cantidad = tickets.where((t) => t.estadoActual == estado).length;
              return _buildChipResumen(
                _formatearNombreEstado(estado.name),
                cantidad,
                _getColorPorEstado(estado),
                _getIconoPorEstado(estado),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildChipResumen(String etiqueta, int cantidad, Color color, IconData icono) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        border: Border.all(color: color.withOpacity(0.4)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            '$etiqueta: $cantidad',
            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildListaTickets(List<TicketEntity> ticketsFiltrados, String mensajeVacio, {Widget? header}) {
    // 🔧 `header` (ej. el Resumen General de la pestaña "TODOS") ahora se
    // dibuja como el primer elemento DENTRO del mismo scroll que la lista de
    // tickets (vía Sliver), en vez de quedar fijo afuera. Así se desplaza
    // junto con las tarjetas y deja ver las siguientes en pantallas chicas.
    if (ticketsFiltrados.isEmpty) {
      return RefreshIndicator(
        onRefresh: () async => context.read<TicketBloc>().add(const ObtenerHistorialTicketsEvent(segmento: SegmentoOperativo.general)),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            if (header != null) SliverToBoxAdapter(child: header),
            SliverFillRemaining(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.inbox_outlined, size: 56, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      Text(
                        mensajeVacio,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // 🔧 Selección de texto habilitada también aquí: cada tarjeta lleva su
    // propia `key: ValueKey(ticket.id)` (ver _buildTicketCard) para que
    // Flutter reutilice el mismo widget/RenderObject cuando llega un
    // snapshot nuevo de Firestore, en vez de destruirlo y recrearlo — eso
    // es lo que evita (no garantiza al 100%, es un bug de Flutter Web,
    // pero reduce muchísimo el riesgo) el crash "RenderBox was not laid
    // out" del escaneo de selección al reconstruirse la lista.
    return RefreshIndicator(
      onRefresh: () async => context.read<TicketBloc>().add(const ObtenerHistorialTicketsEvent(segmento: SegmentoOperativo.general)),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final anchoDisponible = constraints.maxWidth;

          // 📱 MODO MÓVIL (Pantallas estrechas)
          if (anchoDisponible < 600) {
            return CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                if (header != null) SliverToBoxAdapter(child: header),
                SliverPadding(
                  padding: const EdgeInsets.all(12),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _buildTicketCard(ticketsFiltrados[index]),
                      childCount: ticketsFiltrados.length,
                    ),
                  ),
                ),
              ],
            );
          }

          // 💻 MODO TABLET / ESCRITORIO (Pantallas anchas)
          //
          // 🔧 ANTES: SliverGrid con `mainAxisExtent` fijo (una altura de celda
          // fija en píxeles). Cualquier tarjeta cuyo contenido creciera un poco
          // (ej. al agregar la fila de "Proyecto" o el reloj en vivo) terminaba
          // recortada, mostrando el aviso amarillo/negro de "overflow" de
          // Flutter — porque una altura fija no se adapta al contenido.
          //
          // ✅ AHORA: en vez de una grilla de altura fija, se arman "filas" de
          // N tarjetas (N = cuántas caben según el ancho disponible, igual que
          // antes) usando `Row` + `Expanded`. Un `Row` SIN `crossAxisAlignment:
          // stretch` se estira verticalmente hasta la altura de su hijo más
          // alto de forma automática — así cada fila se ajusta sola al
          // contenido real de sus tarjetas, sin importar cuánto crezcan en el
          // futuro. Esto es lo que hace que ya no vuelva a pasar el overflow.
          else {
            final columnas = _columnasParaAncho(anchoDisponible);
            final filas = _agruparEnFilas(ticketsFiltrados, columnas);
            return CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                if (header != null) SliverToBoxAdapter(child: header),
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => Padding(
                        padding: EdgeInsets.only(bottom: index == filas.length - 1 ? 0 : 16),
                        child: _buildFilaDeTarjetas(filas[index], columnas),
                      ),
                      childCount: filas.length,
                    ),
                  ),
                ),
              ],
            );
          }
        },
      ),
    );
  }

  // =========================================================================
  // 🧱 GRILLA RESPONSIVA SIN ALTURA FIJA (ver comentario en el modo escritorio)
  // =========================================================================

  // Mismo criterio que antes tenía `maxCrossAxisExtent: 450`: cuántas
  // columnas de ~450px caben en el ancho disponible (mínimo 1).
  int _columnasParaAncho(double ancho) {
    final columnas = (ancho / 450).floor();
    return columnas < 1 ? 1 : columnas;
  }

  List<List<TicketEntity>> _agruparEnFilas(List<TicketEntity> items, int tamanoFila) {
    final filas = <List<TicketEntity>>[];
    for (var i = 0; i < items.length; i += tamanoFila) {
      final fin = (i + tamanoFila > items.length) ? items.length : i + tamanoFila;
      filas.add(items.sublist(i, fin));
    }
    return filas;
  }

  // Una fila de hasta `columnas` tarjetas. Si la última fila queda incompleta,
  // se rellenan los espacios restantes con un `Expanded` vacío para que las
  // tarjetas no se estiren más de la cuenta y el ancho se mantenga parejo.
  Widget _buildFilaDeTarjetas(List<TicketEntity> fila, int columnas) {
    final hijos = <Widget>[];
    for (var i = 0; i < columnas; i++) {
      if (i > 0) hijos.add(const SizedBox(width: 16));
      hijos.add(i < fila.length ? Expanded(child: _buildTicketCard(fila[i])) : const Expanded(child: SizedBox.shrink()));
    }
    // 🔧 `stretch` (antes `start`): dentro de una misma fila, todas las
    // tarjetas quedan con el mismo alto (el de la más alta) — así los
    // bordes inferiores de la fila quedan parejos aunque una tarjeta tenga
    // más datos (ej. "Proyecto") que su vecina. Antes, con `start`, cada
    // tarjeta tomaba su alto natural y la fila se veía "desalineada".
    // 🔧 `IntrinsicHeight`: esta fila vive dentro de un ListView.builder
    // (alto no acotado). `stretch` por sí solo necesita que la fila ya
    // tenga un alto definido para "estirar" a sus hijos — sin esto Flutter
    // lanza "BoxConstraints forces an infinite height". IntrinsicHeight le
    // da a la fila el alto de su hijo más alto y RECIÉN AHÍ stretch iguala
    // a los demás a ese alto.
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: hijos),
    );
  }

  // =========================================================================
  // ⚙️ WIDGET HELPER: Tarjeta de Ticket
  // =========================================================================

  Widget _buildTicketCard(TicketEntity ticket) {
    final colorEstado = _getColorPorEstado(ticket.estadoActual);

    // 🔧 key estable: así Flutter reconoce esta tarjeta como "la misma"
    // entre reconstrucciones (ej. al llegar un snapshot nuevo de
    // Firestore) en vez de destruirla y recrearla — ver nota en
    // _buildListaTickets sobre por qué esto importa para la selección de
    // texto (SelectionArea global en main.dart).
    return Card(
      key: ValueKey(ticket.id),
      elevation: 3,
      margin: const EdgeInsets.symmetric(vertical: 6),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => DetalleTicketPage(ticket: ticket)));
        },
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 🎨 BARRA DE COLOR: identifica el estado de un vistazo, incluso de lejos
              Container(width: 6, color: colorEstado),

              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. AVATAR: antes era un círculo de relleno sólido (mucho "grito"
                      // de color); ahora es una insignia suave — mismo color, fondo
                      // diluido en vez de sólido.
                      AvatarSuave(color: colorEstado, icono: _getIconoPorEstado(ticket.estadoActual), radio: 26),
                      const SizedBox(width: 14),

                      // 2. CUERPO DE DATOS
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Título (ID) y equipo como subtítulo, más fáciles de leer separados
                            Text(
                              ticket.id,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1A1A1A)),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${ticket.equipo.name.toUpperCase()} • ${ticket.marca.toUpperCase()}',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                            ),

                            const SizedBox(height: 8),

                            // 🛡️ CHIP DE ESTADO ACTUAL: insignia suave (antes: relleno
                            // sólido + texto blanco).
                            InsigniaSuave(
                              color: colorEstado,
                              icono: _getIconoPorEstado(ticket.estadoActual),
                              texto: _formatearNombreEstado(ticket.estadoActual.name),
                            ),

                            const SizedBox(height: 10),

                            // 🆕 Cliente (camaronera/empresa) — es un dato distinto del
                            // contacto: clienteId sí guarda el nombre legible de la
                            // empresa (ej. "Acuarios del Golfo"), y nombreContacto el de
                            // la persona de contacto (ej. "Jose Montalvo"). Se muestran
                            // ambos, cada uno en su línea.
                            // 🎨 Todos los íconos de dato (Cliente/Contacto/Proyecto) usan
                            // un único gris azulado neutro (kTicketIcono) — antes cada
                            // línea tenía su propio tono, sumando ruido sin aportar
                            // significado.
                            if (ticket.clienteId.trim().isNotEmpty) ...[
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.apartment, size: 15, color: kTicketIcono),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'Cliente: ${ticket.clienteId}',
                                      style: const TextStyle(fontSize: 13, color: kTicketTextoPrincipal, fontWeight: FontWeight.w600),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                            ],
                            // Contacto y Falla, cada uno en su propia línea con ícono
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.person_outline, size: 15, color: kTicketIcono),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'Contacto: ${ticket.nombreContacto}',
                                    style: const TextStyle(fontSize: 13, color: kTicketTextoPrincipal),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            // 🆕 Proyecto (solo si el ticket tiene uno asignado) — se muestra
                            // en Historial como lo pidió el usuario.
                            if (ticket.codigoProyecto != null && ticket.codigoProyecto!.trim().isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.folder_outlined, size: 15, color: kTicketIcono),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'Proyecto: ${ticket.codigoProyecto}',
                                      style: const TextStyle(fontSize: 13, color: kTicketTextoPrincipal),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            const SizedBox(height: 4),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.report_problem_outlined, size: 15, color: kTicketAlerta),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    ticket.fallaReportada,
                                    style: const TextStyle(fontSize: 13, color: kTicketTextoPrincipal),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),

                            // 🆕 TIEMPO EN EL ESTADO ACTUAL, EN VIVO — sube solo mientras la
                            // tarjeta está en pantalla (ver TiempoEnCursoWidget). No es un
                            // valor guardado que haya que refrescar desde Firestore: se
                            // recalcula contra la hora real del dispositivo, así que siempre
                            // muestra el tiempo correcto, incluso si nadie abrió la app en
                            // varios días.
                            // 🎨 Antes iba dentro de una caja azul rellena — un color más
                            // sin significado real (no es una alerta). Ahora es texto
                            // plano neutro, igual que en el resto de las bandejas.
                            const SizedBox(height: 8),
                            TiempoEnCursoWidget(
                              desde: ticket.fechaInicioEstadoActual,
                              builder: (context, texto) => Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.hourglass_bottom, size: 12, color: kTicketIcono),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      'En "${_formatearNombreEstado(ticket.estadoActual.name)}": $texto',
                                      style: const TextStyle(fontWeight: FontWeight.w600, color: kTicketTextoSecundario, fontSize: 12),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // 3. ICONO DE ACCIÓN
                      Padding(
                        padding: const EdgeInsets.only(left: 4.0, top: 14.0),
                        child: Icon(Icons.chevron_right, color: Colors.grey.shade400),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}