import 'package:flutter/material.dart';
import '../../../../../core/enum/ticket_enums.dart';
import '../custom_input_field.dart';
import '../custom_dropdown.dart';
import '../section_title_widget.dart';
import '../../../domain/entities/cliente_entity.dart';

class DatosClienteSection extends StatelessWidget {
  final List<ClienteEntity> listaClientes;
  final Sede? selectedSede;
  final String? selectedClienteId;
  final TextEditingController clienteController;
  final TextEditingController campamentoController;
  final TextEditingController nombreContactoController;
  final TextEditingController emailController;
  final TextEditingController telefonoController;
  final ValueChanged<Sede?> onSedeChanged;
  final ValueChanged<ClienteEntity> onClienteSelected;
  final VoidCallback onClienteCleared;
  
  // ⚙️ EL PIN DE CONTROL (Enclavamiento lógico)
  final bool showSede;

  const DatosClienteSection({
    super.key,
    required this.listaClientes,
    required this.selectedSede,
    required this.selectedClienteId,
    required this.clienteController,
    required this.campamentoController,
    required this.nombreContactoController,
    required this.emailController,
    required this.telefonoController,
    required this.onSedeChanged,
    required this.onClienteSelected,
    required this.onClienteCleared,
    this.showSede = true, // Por defecto visible
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionTitleWidget(title: '1. Datos del Cliente y Sede'),
        const SizedBox(height: 16),

        // ⚙️ COMPUERTA LÓGICA: Solo se renderiza si el estado es 'true'
        if (showSede) ...[
          CustomDropdownField<Sede>(
            label: 'Lugar de recepción', 
            icon: Icons.business, 
            items: Sede.values,
            value: selectedSede, 
            onChanged: onSedeChanged,
          ),
          const SizedBox(height: 16),
        ],

        Autocomplete<ClienteEntity>(
          displayStringForOption: (ClienteEntity option) => 
              '${option.camaronera} - ${option.direccion}',
          optionsBuilder: (TextEditingValue textEditingValue) {
            if (textEditingValue.text.isEmpty) return const Iterable<ClienteEntity>.empty();
            
            final query = textEditingValue.text.toLowerCase();
            return listaClientes.where((cliente) => 
              cliente.camaronera.toLowerCase().contains(query) || 
              cliente.direccion.toString().toLowerCase().contains(query)
            ).take(10); 
          },
          onSelected: onClienteSelected,
          fieldViewBuilder: (context, internalController, focusNode, onFieldSubmitted) {
            return CustomInputField(
              controller: internalController, 
              focusNode: focusNode, 
              label: 'Grupo / Campamento de la camaronera', 
              icon: Icons.search,
              validator: (value) => (value == null || value.isEmpty || selectedClienteId == null) ? 'Seleccione un cliente' : null,
              onChanged: (val) { if (selectedClienteId != null) onClienteCleared(); },
            );
          },
        ),
        const SizedBox(height: 16),
        CustomInputField(controller: campamentoController, label: 'Campamento / Finca', icon: Icons.map),
        CustomInputField(controller: nombreContactoController, label: 'Nombre contacto', icon: Icons.person, obscureText: false,),
        CustomInputField(controller: emailController, label: 'Correo', icon: Icons.email, keyboard: TextInputType.emailAddress,obscureText: false,),
        CustomInputField(controller: telefonoController, label: 'Teléfono', icon: Icons.phone, keyboard: TextInputType.phone,obscureText: false,),
      ],
    );
  }
}