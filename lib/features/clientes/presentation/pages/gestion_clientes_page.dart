import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../injection_container.dart';
import '../../domain/entities/cliente_entity.dart';
import '../bloc/cliente_bloc.dart';
import '../bloc/cliente_event.dart';
import '../bloc/cliente_state.dart';
import '../widgets/editar_cliente_bottom_sheet.dart';
import '../widgets/registro_cliente_bottom_sheet.dart';

class GestionClientesPage extends StatelessWidget {
  const GestionClientesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ClienteBloc>(
      create: (context) => sl<ClienteBloc>()..add(CargarClientesEvent()),
      child: const _GestionClientesView(),
    );
  }
}

class _GestionClientesView extends StatefulWidget {
  const _GestionClientesView();

  @override
  State<_GestionClientesView> createState() => _GestionClientesViewState();
}

class _GestionClientesViewState extends State<_GestionClientesView> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<ClienteEntity> _filtrarClientes(List<ClienteEntity> clientes) {
    if (_searchQuery.isEmpty) return clientes;

    return clientes.where((c) {
      final camaronera = c.camaronera.toLowerCase();
      final direccion = c.direccion.toLowerCase();
      final contacto = c.nombreContacto.toLowerCase();
      final celular = c.celular.toLowerCase();
      final email = c.emailContacto.toLowerCase();
      final sede = c.subSector.toLowerCase();
      final estado = c.estadoActual.toLowerCase();

      return camaronera.contains(_searchQuery) ||
          direccion.contains(_searchQuery) ||
          contacto.contains(_searchQuery) ||
          celular.contains(_searchQuery) ||
          email.contains(_searchQuery) ||
          sede.contains(_searchQuery) ||
          estado.contains(_searchQuery);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        title: const Text(
          'Gestión de Clientes',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: const Color(0xFF005A9C),
        foregroundColor: Colors.white,
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_alt_1),
            tooltip: 'Registrar nuevo cliente',
            onPressed: () async {
              final bloc = context.read<ClienteBloc>();
              final creado = await RegistroClienteBottomSheet.show(context);
              if (creado == true) {
                bloc.add(CargarClientesEvent());
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Recargar lista',
            onPressed: () {
              context.read<ClienteBloc>().add(CargarClientesEvent());
            },
          ),
        ],
      ),
      body: BlocConsumer<ClienteBloc, ClienteState>(
        listener: (context, state) {
          if (state is ClienteError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('🛑 Error: ${state.message}'),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is ClienteLoading && state is! ClientesLoaded) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Color(0xFF005A9C)),
                  SizedBox(height: 16),
                  Text('Cargando cartera de clientes...', style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          if (state is ClienteError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 54, color: Colors.red),
                    const SizedBox(height: 12),
                    Text(
                      'Ocurrió un error al cargar clientes:\n${state.message}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.black87),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => context.read<ClienteBloc>().add(CargarClientesEvent()),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reintentar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF005A9C),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          if (state is ClientesLoaded) {
            final clientes = state.clientes;
            final filtrados = _filtrarClientes(clientes);

            return Column(
              children: [
                // 🔍 BARRA DE BÚSQUEDA Y FILTRADO
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  color: Colors.white,
                  child: Column(
                    children: [
                      TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Buscar por razón social, finca, contacto, sede...',
                          hintStyle: TextStyle(fontSize: 13, color: Colors.grey[500]),
                          prefixIcon: const Icon(Icons.search, color: Color(0xFF005A9C)),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 20),
                                  onPressed: () => _searchController.clear(),
                                )
                              : null,
                          filled: true,
                          fillColor: const Color(0xFFF0F4F8),
                          contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Mostrando ${filtrados.length} de ${clientes.length} clientes',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[600],
                            ),
                          ),
                          if (_searchQuery.isNotEmpty)
                            InkWell(
                              onTap: () => _searchController.clear(),
                              child: const Text(
                                'Limpiar filtro',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.orange,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),

                // 📋 LISTADO DE TARJETAS DE CLIENTES
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () async {
                      context.read<ClienteBloc>().add(CargarClientesEvent());
                    },
                    child: filtrados.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                              Center(
                                child: Column(
                                  children: [
                                    Icon(
                                      _searchQuery.isEmpty ? Icons.people_outline : Icons.search_off,
                                      size: 60,
                                      color: Colors.grey[400],
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      _searchQuery.isEmpty
                                          ? 'No hay clientes registrados en la base de datos'
                                          : 'No se encontraron clientes que coincidan con la búsqueda',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(fontSize: 15, color: Colors.grey[600]),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            itemCount: filtrados.length,
                            separatorBuilder: (_, index) => const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final cliente = filtrados[index];
                              return _ClienteCard(
                                cliente: cliente,
                                onTap: () async {
                                  final bloc = context.read<ClienteBloc>();
                                  final actualizado = await EditarClienteBottomSheet.show(
                                    context,
                                    cliente: cliente,
                                  );
                                  if (actualizado == true) {
                                    bloc.add(CargarClientesEvent());
                                  }
                                },
                              );
                            },
                          ),
                  ),
                ),
              ],
            );
          }

          return const Center(child: Text('Iniciando módulo de clientes...'));
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF005A9C),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Nuevo Cliente', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: () async {
          final bloc = context.read<ClienteBloc>();
          final creado = await RegistroClienteBottomSheet.show(context);
          if (creado == true) {
            bloc.add(CargarClientesEvent());
          }
        },
      ),
    );
  }
}

class _ClienteCard extends StatelessWidget {
  final ClienteEntity cliente;
  final VoidCallback onTap;

  const _ClienteCard({required this.cliente, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isActivo = cliente.estadoActual.toLowerCase() == 'activo';

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isActivo ? Colors.grey.shade200 : Colors.red.shade100,
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // CABECERA: Razón Social + Estado
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF005A9C).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.business, color: Color(0xFF005A9C), size: 22),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          cliente.camaronera.isNotEmpty ? cliente.camaronera : '(Sin grupo especificado)',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1F2937),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(Icons.map_outlined, size: 14, color: Colors.grey),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                cliente.direccion.isNotEmpty ? cliente.direccion : 'Finca no especificada',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[700],
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Badge Estado
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isActivo ? Colors.green.shade50 : Colors.red.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isActivo ? Colors.green.shade300 : Colors.red.shade300,
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      isActivo ? 'ACTIVO' : 'INACTIVO',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isActivo ? Colors.green.shade800 : Colors.red.shade800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Divider(height: 1, thickness: 0.6),
              const SizedBox(height: 8),

              // DATOS DETALLADOS: Sede, Contacto, Teléfono, Correo
              Wrap(
                spacing: 12,
                runSpacing: 6,
                children: [
                  // Sede
                  if (cliente.subSector.isNotEmpty)
                    _InfoPill(
                      icon: Icons.location_city,
                      text: cliente.subSector,
                      backgroundColor: const Color(0xFFE8F0FE),
                      textColor: const Color(0xFF1A73E8),
                    ),

                  // Contacto
                  if (cliente.nombreContacto.isNotEmpty)
                    _InfoPill(
                      icon: Icons.person_outline,
                      text: cliente.nombreContacto,
                      backgroundColor: Colors.grey.shade100,
                      textColor: Colors.grey.shade800,
                    ),

                  // Teléfono
                  if (cliente.celular.isNotEmpty)
                    _InfoPill(
                      icon: Icons.phone_outlined,
                      text: cliente.celular,
                      backgroundColor: Colors.grey.shade100,
                      textColor: Colors.grey.shade800,
                    ),

                  // Correo
                  if (cliente.emailContacto.isNotEmpty)
                    _InfoPill(
                      icon: Icons.email_outlined,
                      text: cliente.emailContacto,
                      backgroundColor: Colors.grey.shade100,
                      textColor: Colors.grey.shade800,
                    ),
                ],
              ),

              const SizedBox(height: 8),
              // PIE DE TARJETA: Indicador de acción
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'Tocar para editar',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.orange.shade800,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.edit_note, size: 16, color: Colors.orange.shade800),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color backgroundColor;
  final Color textColor;

  const _InfoPill({
    required this.icon,
    required this.text,
    required this.backgroundColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: textColor),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}
