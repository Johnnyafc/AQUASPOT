import 'package:flutter/material.dart';
import '../../../../../core/enum/ticket_enums.dart';
import '../custom_dropdown.dart';
import '../custom_input_field.dart';
import '../custom_input_field_widget.dart';
import '../checklist_dinamico_widget.dart';
import '../section_title_widget.dart';

class ConfirmacionEquipoSection extends StatelessWidget {
  final TipoEquipo? selectedEquipo;
  final Map<String, bool> accesoriosSeleccionados;
  final TextEditingController customEquipoController;
  final TextEditingController serieController;
  final TextEditingController fallaController;
  final ValueChanged<TipoEquipo?> onEquipoChanged;
  final Function(String, bool) onAccesorioChanged;
  
  // 🚀 EL NUEVO RELÉ LÓGICO
  final bool mostrarAccesorios; 

  const ConfirmacionEquipoSection({
    super.key,
    required this.selectedEquipo,
    required this.accesoriosSeleccionados,
    required this.customEquipoController,
    required this.serieController,
    required this.fallaController,
    required this.onEquipoChanged,
    required this.onAccesorioChanged,
    required this.mostrarAccesorios, // ⚙️ Parámetro requerido
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionTitleWidget(title: '2. Confirmación de equipo'),
        const SizedBox(height: 16),
        CustomDropdownField<TipoEquipo>(
          label: 'Tipo de Equipo', icon: Icons.precision_manufacturing, items: TipoEquipo.values,
          value: selectedEquipo, onChanged: onEquipoChanged, validator: (value) => null,
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          child: selectedEquipo == TipoEquipo.Otros
              ? Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: CustomInputField(controller: customEquipoController, label: 'Especifique equipo', icon: Icons.edit_note),
                )
              : const SizedBox.shrink(),
        ),
        const SizedBox(height: 16),
        CustomInputFieldWidget(label: 'Número de Serie', controller: serieController, icon: Icons.qr_code_scanner,validator: (value) => null,),
        const SizedBox(height: 16),
        
        // ⚙️ COMPUERTA LÓGICA DE ENCLAVAMIENTO
        // Solo si hay un equipo seleccionado Y la bandera 'mostrarAccesorios' es verdadera
        if (selectedEquipo != null && mostrarAccesorios)
          ChecklistDinamicoWidget(
            equipo: selectedEquipo!,
            selecciones: accesoriosSeleccionados,
            onChanged: onAccesorioChanged,
          ),
          
        const SizedBox(height: 16),
        CustomInputFieldWidget(label: 'Falla Reportada', controller: fallaController, icon: Icons.report_problem_outlined, lines: 3),
      ],
    );
  }
}