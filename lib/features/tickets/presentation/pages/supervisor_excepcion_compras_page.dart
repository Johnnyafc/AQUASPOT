// lib/features/tickets/presentation/pages/supervisor_excepcion_compras_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/enum/segmento_operativo.dart';
import '../../../../core/enum/ticket_enums.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../domain/entities/ticket_entity.dart';
import '../bloc/ticket_bloc.dart';
import '../bloc/ticket_event.dart';
import '../bloc/ticket_state.dart';
import '../widgets/tarjeta_no_requiere_compras_widget.dart';

enum FiltroExcepcionCompras { todos, requierenCompras, sinCompras }

class SupervisorExcepcionComprasPage extends StatefulWidget {
  const SupervisorExcepcionComprasPage({super.key});

  @override
  State<SupervisorExcepcionComprasPage> createState() => _SupervisorExcepcionComprasPageState();
}

class _SupervisorExcepcionComprasPageState extends State<SupervisorExcepcionComprasPage> {
  final TextEditingController _searchController = TextEditingController();
  FiltroExcepcionCompras _filtroActivo = FiltroExcepcionCompras.todos;
  String _busquedaQuery = '';

  @override
  void initState() {
    super.initState();
    // Cargar historial si no está cargado
    final authState = context.read<AuthBloc>().state;
    SegmentoOperativo segmentoActivo = SegmentoOperativo.ninguno;
    if (authState is Authenticated) {
      segmentoActivo = authState.usuario.segmento;
    }
    context.read<TicketBloc>().add(ObtenerHistorialTicketsEvent(segmento: segmentoActivo));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _abrirDialogoDeclararNoCompras(BuildContext context, TicketEntity ticket) {
    final TextEditingController motivoController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.remove_shopping_cart, color: Colors.orange.shade800, size: 28),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Declarar: No Requiere Compras',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.shade300),
                    ),
                    child: Text(
                      'Ticket: ${ticket.id}\n'
                      'Equipo: ${ticket.equipo.name} (${ticket.marca})\n'
                      'Cliente: ${ticket.clienteId}',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Al confirmar, se enviará automáticamente una tarjeta naranja de alerta a todos los usuarios del flujo (Costos, Compras, Bodega, Taller y Entrega) indicando que este equipo no necesita compras de repuestos ni insumos.',
                    style: TextStyle(fontSize: 12, color: Colors.black87),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: motivoController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Motivo / Justificación técnica *',
                      hintText: 'Ej. Stock suficiente en bodega de taller, solo requiere mantenimiento correctivo de mano de obra...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Por favor ingrese el motivo de la excepción';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('CANCELAR'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade900,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('CONFIRMAR EXCEPCIÓN'),
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  final authState = context.read<AuthBloc>().state;
                  String nombre = 'Supervisor';
                  String rol = 'SUPERVISOR';
                  if (authState is Authenticated) {
                    nombre = authState.usuario.nombre;
                    rol = authState.usuario.rol.name.toUpperCase();
                  }

                  context.read<TicketBloc>().add(
                    DeclararNoRequiereComprasEvent(
                      ticket: ticket,
                      noRequiereCompras: true,
                      motivo: motivoController.text.trim(),
                      nombreUsuario: nombre,
                      rolUsuario: rol,
                    ),
                  );

                  Navigator.pop(dialogCtx);
                }
              },
            ),
          ],
        );
      },
    );
  }

  void _abrirDialogoRestablecerCompras(BuildContext context, TicketEntity ticket) {
    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.shopping_cart, color: Colors.blue, size: 28),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Restablecer: Requiere Compras',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Text(
            '¿Deseas anular la excepción para el Ticket ${ticket.id}?\n\n'
            'El ticket volverá al flujo normal de compras y la notificación naranja será removida de las estaciones.',
            style: const TextStyle(fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('CANCELAR'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade800,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                final authState = context.read<AuthBloc>().state;
                String nombre = 'Supervisor';
                String rol = 'SUPERVISOR';
                if (authState is Authenticated) {
                  nombre = authState.usuario.nombre;
                  rol = authState.usuario.rol.name.toUpperCase();
                }

                context.read<TicketBloc>().add(
                  DeclararNoRequiereComprasEvent(
                    ticket: ticket,
                    noRequiereCompras: false,
                    motivo: null,
                    nombreUsuario: nombre,
                    rolUsuario: rol,
                  ),
                );

                Navigator.pop(dialogCtx);
              },
              child: const Text('RESTABLECER COMPRAS'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        title: const Text(
          'Control de Compras (Excepción)',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.deepOrange.shade900,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: BlocConsumer<TicketBloc, TicketState>(
        listener: (context, state) {
          if (state.status == TicketStatus.operationSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message), backgroundColor: Colors.green),
            );
          } else if (state.status == TicketStatus.error) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message), backgroundColor: Colors.red),
            );
          }
        },
        builder: (context, state) {
          if (state.status == TicketStatus.loading && state.historial.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          final ticketsActivos = state.historial.where((t) {
            // Filtrar tickets finalizados o anulados para centrarse en los operativos
            return t.estadoActual != EstadoTicket.finalizado &&
                   t.estadoActual != EstadoTicket.anulado;
          }).toList();

          // Filtro por pestaña
          List<TicketEntity> filtradosPorPestana = ticketsActivos;
          if (_filtroActivo == FiltroExcepcionCompras.requierenCompras) {
            filtradosPorPestana = ticketsActivos.where((t) => !t.noRequiereCompras).toList();
          } else if (_filtroActivo == FiltroExcepcionCompras.sinCompras) {
            filtradosPorPestana = ticketsActivos.where((t) => t.noRequiereCompras).toList();
          }

          // Filtro por búsqueda
          final query = _busquedaQuery.trim().toLowerCase();
          final ticketsFinales = filtradosPorPestana.where((t) {
            if (query.isEmpty) return true;
            return t.id.toLowerCase().contains(query) ||
                   t.clienteId.toLowerCase().contains(query) ||
                   t.campamento.toLowerCase().contains(query) ||
                   t.nombreContacto.toLowerCase().contains(query) ||
                   t.equipo.name.toLowerCase().contains(query) ||
                   t.marca.toLowerCase().contains(query) ||
                   (t.numeroSerie ?? '').toLowerCase().contains(query) ||
                   (t.codigoProyecto ?? '').toLowerCase().contains(query) ||
                   t.estadoActual.nombreLegible.toLowerCase().contains(query);
          }).toList();

          final int totalSinCompras = ticketsActivos.where((t) => t.noRequiereCompras).length;
          final int totalConCompras = ticketsActivos.where((t) => !t.noRequiereCompras).length;

          return Column(
            children: [
              // Barra de filtros y métricas
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Column(
                  children: [
                    // Campo de búsqueda
                    TextField(
                      controller: _searchController,
                      onChanged: (val) {
                        setState(() {
                          _busquedaQuery = val;
                        });
                      },
                      decoration: InputDecoration(
                        hintText: 'Buscar por ID, cliente, equipo, serie, estado...',
                        prefixIcon: const Icon(Icons.search, size: 22),
                        suffixIcon: _busquedaQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {
                                    _busquedaQuery = '';
                                  });
                                },
                              )
                            : null,
                        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF7F9FC),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Pestañas de segmentación
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildFilterChip(
                            label: 'Todos (${ticketsActivos.length})',
                            selected: _filtroActivo == FiltroExcepcionCompras.todos,
                            onSelected: () => setState(() => _filtroActivo = FiltroExcepcionCompras.todos),
                          ),
                          const SizedBox(width: 8),
                          _buildFilterChip(
                            label: 'Requieren Compras ($totalConCompras)',
                            selected: _filtroActivo == FiltroExcepcionCompras.requierenCompras,
                            onSelected: () => setState(() => _filtroActivo = FiltroExcepcionCompras.requierenCompras),
                            colorSeleccionado: Colors.blue.shade800,
                          ),
                          const SizedBox(width: 8),
                          _buildFilterChip(
                            label: 'Sin Compras ($totalSinCompras)',
                            selected: _filtroActivo == FiltroExcepcionCompras.sinCompras,
                            onSelected: () => setState(() => _filtroActivo = FiltroExcepcionCompras.sinCompras),
                            colorSeleccionado: Colors.deepOrange.shade800,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Lista de tickets
              Expanded(
                child: ticketsFinales.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            Text(
                              _busquedaQuery.isNotEmpty
                                  ? 'No se encontraron tickets con "$_busquedaQuery"'
                                  : 'No hay tickets en esta categoría.',
                              style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () async {
                          final authState = context.read<AuthBloc>().state;
                          SegmentoOperativo seg = SegmentoOperativo.ninguno;
                          if (authState is Authenticated) {
                            seg = authState.usuario.segmento;
                          }
                          context.read<TicketBloc>().add(ObtenerHistorialTicketsEvent(segmento: seg));
                        },
                        child: ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: ticketsFinales.length,
                          itemBuilder: (context, index) {
                            final ticket = ticketsFinales[index];
                            return _buildTicketCard(context, ticket);
                          },
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool selected,
    required VoidCallback onSelected,
    Color? colorSeleccionado,
  }) {
    final activeColor = colorSeleccionado ?? Colors.deepOrange.shade900;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          color: selected ? Colors.white : Colors.black87,
          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          fontSize: 12,
        ),
      ),
      selected: selected,
      selectedColor: activeColor,
      backgroundColor: Colors.grey.shade200,
      onSelected: (_) => onSelected(),
    );
  }

  Widget _buildTicketCard(BuildContext context, TicketEntity ticket) {
    final bool sinCompras = ticket.noRequiereCompras;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: sinCompras ? Colors.orange.shade700 : Colors.grey.shade300,
          width: sinCompras ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabecera: ID y Estado
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Ticket: ${ticket.id}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blueGrey.shade100,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    ticket.estadoActual.nombreLegible,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueGrey.shade900),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Info del equipo y cliente
            Text(
              'Equipo: ${ticket.equipo.name.toUpperCase()} (${ticket.marca}) | Cliente: ${ticket.clienteId}',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 2),
            Text(
              'Contacto: ${ticket.nombreContacto} | Sede: ${ticket.sede.name}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),

            if (ticket.codigoProyecto != null && ticket.codigoProyecto!.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                'Proyecto: ${ticket.codigoProyecto}',
                style: TextStyle(fontSize: 12, color: Colors.blue.shade900, fontWeight: FontWeight.w500),
              ),
            ],

            // Si está marcado como sin compras, desplegamos la tarjeta naranja
            if (sinCompras) ...[
              const SizedBox(height: 8),
              TarjetaNoRequiereComprasWidget(
                ticket: ticket,
                margin: EdgeInsets.zero,
                onEditar: () => _abrirDialogoDeclararNoCompras(context, ticket),
              ),
            ],

            const SizedBox(height: 10),

            // Botones de acción
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (sinCompras) ...[
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blue.shade800,
                      side: BorderSide(color: Colors.blue.shade800),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    icon: const Icon(Icons.restore, size: 16),
                    label: const Text('Restablecer Compras', style: TextStyle(fontSize: 12)),
                    onPressed: () => _abrirDialogoRestablecerCompras(context, ticket),
                  ),
                ] else ...[
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade900,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    ),
                    icon: const Icon(Icons.remove_shopping_cart, size: 16),
                    label: const Text('NO REQUIERE COMPRAS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    onPressed: () => _abrirDialogoDeclararNoCompras(context, ticket),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
