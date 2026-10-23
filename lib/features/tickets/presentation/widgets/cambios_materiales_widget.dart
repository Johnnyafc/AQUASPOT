// lib/features/tickets/presentation/widgets/cambios_materiales_widget.dart
//
// 🧾 "Cambios de materiales": lo que Comercial agregó, quitó o cambió de
// cantidad (registro aparte de la auditoría). Se usa en la pantalla de
// Comercial y en el Detalle de Ticket.

import 'package:flutter/material.dart';
import '../../domain/entities/cambio_material_entity.dart';

class CambiosMaterialesWidget extends StatelessWidget {
  final List<CambioMaterialEntity> cambios;
  final bool inicialmenteExpandido;

  const CambiosMaterialesWidget({super.key, required this.cambios, this.inicialmenteExpandido = false});

  static String _cantidad(double? c) => c == null ? '—' : (c % 1 == 0 ? c.toInt().toString() : c.toString());

  static String _fecha(DateTime d) {
    String dos(int n) => n.toString().padLeft(2, '0');
    return '${dos(d.day)}/${dos(d.month)}/${d.year} ${dos(d.hour)}:${dos(d.minute)}';
  }

  Color _color(String accion) => switch (accion) {
        CambioMaterialEntity.agrego => const Color(0xFF2E7D32),
        CambioMaterialEntity.quito => Colors.red.shade700,
        _ => Colors.orange.shade800,
      };

  IconData _icono(String accion) => switch (accion) {
        CambioMaterialEntity.agrego => Icons.add_circle_outline,
        CambioMaterialEntity.quito => Icons.remove_circle_outline,
        _ => Icons.swap_vert,
      };

  @override
  Widget build(BuildContext context) {
    final lista = [...cambios]..sort((a, b) => b.fecha.compareTo(a.fecha));
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: inicialmenteExpandido,
          leading: const Icon(Icons.history_edu, color: Color(0xFF005A9C)),
          title: Text(
            'Cambios de materiales (${lista.length})',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          subtitle: const Text(
            'Lo que Comercial agregó, quitó o cambió (aparte de la auditoría)',
            style: TextStyle(fontSize: 12),
          ),
          children: [
            if (lista.isEmpty)
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Text('Sin cambios registrados.', style: TextStyle(color: Colors.grey)),
              )
            else
              for (final c in lista)
                ListTile(
                  dense: true,
                  leading: Icon(_icono(c.accion), color: _color(c.accion)),
                  title: Text(
                    '${c.accionTexto}: ${c.codigo.isNotEmpty ? '${c.codigo} · ' : ''}${c.descripcion}',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  subtitle: Text(
                    '${c.accion == CambioMaterialEntity.cambioCantidad ? 'Cantidad ${_cantidad(c.cantidadAntes)} → ${_cantidad(c.cantidadDespues)}' : 'Cantidad ${_cantidad(c.cantidadDespues ?? c.cantidadAntes)}'} ${c.unidad}'
                    ' · ${c.listaTexto} · ${c.momentoTexto}\n'
                    '${c.usuarioNombre} [${c.usuarioRol}] · ${_fecha(c.fecha)}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
