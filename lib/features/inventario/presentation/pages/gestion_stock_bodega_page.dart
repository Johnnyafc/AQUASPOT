import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_picker/file_picker.dart';
import '../bloc/inventario_bloc.dart';
import '../bloc/inventario_event.dart';
import '../bloc/inventario_state.dart';

class GestionStockBodegaPage extends StatefulWidget {
  const GestionStockBodegaPage({super.key});

  @override
  State<GestionStockBodegaPage> createState() => _GestionStockBodegaPageState();
}

class _GestionStockBodegaPageState extends State<GestionStockBodegaPage> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    context.read<InventarioBloc>().add(const CargarInventarioEvent());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _seleccionarYSubirExcel() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls', 'csv'],
      allowMultiple: false,
      withData: true,
    );

    if (result != null && result.files.isNotEmpty) {
      final fileBytes = result.files.first.bytes;
      if (fileBytes != null && mounted) {
        context
            .read<InventarioBloc>()
            .add(CargarStockExcelEvent(fileBytes));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        title: const Text(
          'Inventario & Stock Bodega',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: const Color(0xFF005A9C),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refrescar Stock',
            onPressed: () {
              context.read<InventarioBloc>().add(const CargarInventarioEvent());
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.upload_file),
        label: const Text('Subir Stock Excel/CSV'),
        onPressed: _seleccionarYSubirExcel,
      ),
      body: BlocConsumer<InventarioBloc, InventarioState>(
        listener: (context, state) {
          if (state is InventarioOperacionSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.mensaje),
                backgroundColor: const Color(0xFF2E7D32),
              ),
            );
          } else if (state is InventarioError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error: ${state.mensaje}'),
                backgroundColor: Colors.red.shade700,
                duration: const Duration(seconds: 5),
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is InventarioLoading) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: Color(0xFF005A9C)),
                  const SizedBox(height: 16),
                  Text(
                    state.mensaje,
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 15),
                  ),
                ],
              ),
            );
          }

          if (state is InventarioError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 70, color: Colors.red.shade400),
                    const SizedBox(height: 16),
                    const Text(
                      'No se pudo consultar el inventario',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      state.mensaje,
                      style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: () {
                        context.read<InventarioBloc>().add(const CargarInventarioEvent());
                      },
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

          if (state is InventarioLoaded) {
            final items = state.itemsFiltrados;

            return Column(
              children: [
                // Cabecera con Buscador y Resumen
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.white,
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              decoration: InputDecoration(
                                hintText: 'Buscar por código o descripción...',
                                prefixIcon: const Icon(Icons.search, color: Color(0xFF005A9C)),
                                suffixIcon: _searchController.text.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear),
                                        onPressed: () {
                                          _searchController.clear();
                                          context.read<InventarioBloc>().add(
                                                const FiltrarInventarioEvent(''),
                                              );
                                        },
                                      )
                                    : null,
                                filled: true,
                                fillColor: const Color(0xFFF0F4F8),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                              ),
                              onChanged: (val) {
                                context
                                    .read<InventarioBloc>()
                                    .add(FiltrarInventarioEvent(val));
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            onPressed: _seleccionarYSubirExcel,
                            icon: const Icon(Icons.cloud_upload_outlined, size: 20),
                            label: const Text('Cargar Excel'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF005A9C),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(Icons.inventory_2_outlined,
                              size: 18, color: Colors.grey.shade700),
                          const SizedBox(width: 6),
                          Text(
                            'Total de ítems en stock: ${state.items.length}',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade800,
                              fontSize: 13,
                            ),
                          ),
                          const Spacer(),
                          if (state.itemsFiltrados.length != state.items.length)
                            Text(
                              'Mostrando: ${state.itemsFiltrados.length}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF005A9C),
                                fontSize: 13,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),

                // Lista de Ítems
                Expanded(
                  child: items.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.inbox_outlined,
                                  size: 64, color: Colors.grey.shade400),
                              const SizedBox(height: 12),
                              Text(
                                state.items.isEmpty
                                    ? 'Aún no se ha cargado el stock de bodega.\nPresione "Subir Stock Excel/CSV" para comenzar.'
                                    : 'No se encontraron repuestos con ese término.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: items.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final item = items[index];
                            final tieneStock = item.stockDisponible > 0;

                            return Card(
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                                side: BorderSide(
                                  color: tieneStock
                                      ? Colors.grey.shade300
                                      : Colors.red.shade200,
                                ),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 6,
                                ),
                                leading: CircleAvatar(
                                  backgroundColor: tieneStock
                                      ? const Color(0xFFE8F5E9)
                                      : const Color(0xFFFFEBEE),
                                  child: Icon(
                                    tieneStock
                                        ? Icons.check_circle_outline
                                        : Icons.warning_amber_rounded,
                                    color: tieneStock
                                        ? const Color(0xFF2E7D32)
                                        : Colors.red.shade700,
                                  ),
                                ),
                                title: Text(
                                  item.codigo,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 2),
                                    Text(
                                      item.descripcion,
                                      style: TextStyle(
                                        color: Colors.grey.shade800,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 4,
                                      children: [
                                        Text(
                                          'Unidad: ${item.unidad}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                        if (item.ubicacion != null &&
                                            item.ubicacion!.isNotEmpty)
                                          Text(
                                            '• Ubicación: ${item.ubicacion}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '${item.stockDisponible.toStringAsFixed(item.stockDisponible.truncateToDouble() == item.stockDisponible ? 0 : 2)} ${item.unidad}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: tieneStock
                                            ? const Color(0xFF2E7D32)
                                            : Colors.red.shade700,
                                      ),
                                    ),
                                    Text(
                                      tieneStock ? 'Disponible' : 'Agotado',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: tieneStock
                                            ? const Color(0xFF2E7D32)
                                            : Colors.red.shade700,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          }

          return const Center(child: CircularProgressIndicator());
        },
      ),
    );
  }
}
