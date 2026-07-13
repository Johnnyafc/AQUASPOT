import 'package:flutter/material.dart';
import '../custom_input_field_widget.dart';
import '../section_title_widget.dart';

class ParametrosOperativosSection extends StatelessWidget {
  final TextEditingController notasRecepcionController;

  const ParametrosOperativosSection({
    super.key,
    required this.notasRecepcionController,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionTitleWidget(title: '3. Parámetros Operativos'),
        const SizedBox(height: 16),
        CustomInputFieldWidget(
          label: 'Notas de Recepción', 
          controller: notasRecepcionController, 
          icon: Icons.description_outlined, 
          lines: 3, 
          hint: 'Ej: Equipo con carcasa rayada...',
          // ⚙️ Bypass de seguridad intacto para permitir nulos
          validator: (value) => null, 
        ),
      ],
    );
  }
}