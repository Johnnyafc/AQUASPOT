import 'package:aquaspot_postventa/features/tickets/domain/constant/catalogo_equipos_constants.dart';
import 'package:flutter/material.dart';
import '../../domain/entities/ticket_enums.dart';

class ChecklistDinamicoWidget extends StatelessWidget {
  final TipoEquipo equipo;
  final Map<String, bool> selecciones;
  final Function(String, bool) onChanged;

  const ChecklistDinamicoWidget({
    super.key,
    required this.equipo,
    required this.selecciones,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final listaAccesorios = CatalogoEquiposConstants.accesoriosPorMaquina[equipo];
    
    if (listaAccesorios == null || listaAccesorios.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: listaAccesorios.map((String pieza) {
          final isChecked = selecciones[pieza] ?? false;
          return CheckboxListTile(
            title: Text(pieza, style: const TextStyle(fontWeight: FontWeight.w500)),
            value: isChecked,
            activeColor: Colors.teal,
            controlAffinity: ListTileControlAffinity.leading,
            dense: true,
            onChanged: (bool? valor) => onChanged(pieza, valor ?? false),
          );
        }).toList(),
      ),
    );
  }
}