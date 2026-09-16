import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../domain/entities/ticket_entity.dart';

class MaterialesDespachadosTallerPage extends StatelessWidget {
  final TicketEntity ticket;

  const MaterialesDespachadosTallerPage({super.key, required this.ticket});

  void _copiarTexto(BuildContext context, String texto, String mensaje) {
    Clipboard.setData(ClipboardData(text: texto));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: const Color(0xFF005A9C),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final enviados = ticket.itemsDespachados;
    final faltantes = ticket.itemsFaltantesDespacho;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F6F9),
        appBar: AppBar(
          title: Text(
            'Materiales Bodega - ${ticket.id}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          backgroundColor: const Color(0xFF005A9C),
          foregroundColor: Colors.white,
          bottom: const TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(
                icon: Icon(Icons.check_circle_outline),
                text: 'Materiales Enviados',
              ),
              Tab(
                icon: Icon(Icons.pending_actions_outlined),
                text: 'Materiales Faltantes',
              ),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // TABLA 1: ENVIADOS DE BODEGA
            _buildTablaEnviados(context, enviados),

            // TABLA 2: FALTANTES POR DESPACHAR
            _buildTablaFaltantes(context, faltantes),
          ],
        ),
      ),
    );
  }

  Widget _buildTablaEnviados(BuildContext context, List items) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            const Text(
              'Aún no se han despachado repuestos desde Bodega para este ticket.',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: const Color(0xFFE8F5E9),
          child: Row(
            children: [
              const Icon(Icons.local_shipping_outlined, color: Color(0xFF2E7D32)),
              const SizedBox(width: 8),
              Text(
                'Total repuestos entregados por Bodega: ${items.length}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2E7D32),
                ),
              ),
              const Spacer(),
              TextButton.icon(
                icon: const Icon(Icons.copy, size: 14),
                label: const Text('Copiar Enviados', style: TextStyle(fontSize: 12)),
                onPressed: () {
                  final text = items
                      .map((i) => '${i.codigo} - ${i.descripcion}: ${i.cantidadDespachada} ${i.unidad}')
                      .join('\n');
                  _copiarTexto(context, text, 'Listado de repuestos enviados copiado');
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final item = items[index];

              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(color: Colors.green.shade200),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFE8F5E9),
                    child: Icon(Icons.check, color: Color(0xFF2E7D32)),
                  ),
                  title: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE3F2FD),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          item.codigo,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                            color: Color(0xFF0D47A1),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item.descripcion,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Despachado: ${item.cantidadDespachada} ${item.unidad} (Solicitado: ${item.cantidadSolicitada})',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: item.despachadoCompletamente
                          ? const Color(0xFFE8F5E9)
                          : const Color(0xFFFFF3E0),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      item.despachadoCompletamente ? 'COMPLETO' : 'PARCIAL',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: item.despachadoCompletamente
                            ? const Color(0xFF2E7D32)
                            : Colors.orange.shade900,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTablaFaltantes(BuildContext context, List items) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle_outline, size: 64, color: Color(0xFF2E7D32)),
            const SizedBox(height: 12),
            const Text(
              '¡Todos los materiales requeridos han sido entregados por Bodega!',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF2E7D32),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: const Color(0xFFFFF3E0),
          child: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange.shade900),
              const SizedBox(width: 8),
              Text(
                'Repuestos pendientes de entrega: ${items.length}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.orange.shade900,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                icon: const Icon(Icons.copy, size: 14),
                label: const Text('Copiar Faltantes', style: TextStyle(fontSize: 12)),
                onPressed: () {
                  final text = items
                      .map((i) => '${i.codigo} - ${i.descripcion}: Falta ${i.cantidadFaltante} ${i.unidad}')
                      .join('\n');
                  _copiarTexto(context, text, 'Listado de repuestos faltantes copiado');
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final item = items[index];

              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(color: Colors.orange.shade200),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFFFF3E0),
                    child: Icon(Icons.pending, color: Colors.orange),
                  ),
                  title: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE3F2FD),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          item.codigo,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                            color: Color(0xFF0D47A1),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item.descripcion,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Falta: ${item.cantidadFaltante} ${item.unidad} (Solicitado: ${item.cantidadSolicitada}, Despachado: ${item.cantidadDespachada})',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.red.shade700,
                      ),
                    ),
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.orange.shade300),
                    ),
                    child: Text(
                      'Pendiente Bodega',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange.shade900,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
