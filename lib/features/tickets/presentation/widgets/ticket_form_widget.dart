// lib/features/tickets/presentation/widgets/ticket_form_widget.dart

import 'package:flutter/material.dart';
import '../../domain/entities/cliente_entity.dart';
import '../../domain/entities/ticket_enums.dart';
import 'custom_dropdown.dart';
import 'custom_input_field.dart';

class TicketForm extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final bool isProcessing;
  final List<ClienteEntity> listaClientes;
  final TextEditingController clienteController;
  final TextEditingController campamentoController;
  final TextEditingController nombreContactoController;
  final TextEditingController emailController;
  final TextEditingController telefonoController;
  final TextEditingController fallaController;
  final TextEditingController customEquipoController;

  final Function(ClienteEntity) onClienteSelected;
  final VoidCallback onClienteCleared;
  final Function(Sede?) onSedeChanged;
  final Function(TipoEquipo?) onEquipoChanged;
  final VoidCallback onSubmit;

  final Sede? selectedSede;
  final TipoEquipo? selectedEquipo;
  final String? selectedClienteId;

  const TicketForm({
    super.key,
    required this.formKey,
    required this.isProcessing,
    required this.listaClientes,
    required this.clienteController,
    required this.campamentoController,
    required this.nombreContactoController,
    required this.emailController,
    required this.telefonoController,
    required this.fallaController,
    required this.customEquipoController,
    required this.onClienteSelected,
    required this.onClienteCleared,
    required this.onSedeChanged,
    required this.onEquipoChanged,
    required this.onSubmit,
    this.selectedSede,
    this.selectedEquipo,
    this.selectedClienteId,
  });

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Detalles del Servicio", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const Divider(height: 30),

          CustomDropdownField<Sede>(
            label: 'Sede',
            icon: Icons.business,
            items: Sede.values,
            value: selectedSede,
            onChanged: onSedeChanged,
          ),
          const SizedBox(height: 16),

          // ==========================================================
          // 🚀 BUSCADOR PREDICTIVO EN MEMORIA LOCAL OPTIMIZADO
          // ==========================================================
          Autocomplete<ClienteEntity>(
            displayStringForOption: (ClienteEntity option) => option.camaronera,
            optionsBuilder: (TextEditingValue textEditingValue) {
              if (textEditingValue.text.isEmpty) {
                return const Iterable<ClienteEntity>.empty();
              }
              // Filtra eficientemente y limita el renderizado a 10 elementos maximo
              return listaClientes.where((ClienteEntity cliente) {
                return cliente.camaronera
                    .toLowerCase()
                    .contains(textEditingValue.text.toLowerCase());
              }).take(10); 
            },
            onSelected: onClienteSelected,
            fieldViewBuilder: (context, internalController, focusNode, onFieldSubmitted) {
              // ⚠️ IMPORTANTE: Vinculamos los objetos del framework al CustomInputField
              return CustomInputField(
                controller: internalController,
                focusNode: focusNode, // Asegúrate de que CustomInputField reciba este parámetro
                label: 'Razón Social / Cliente (Buscar...)',
                icon: Icons.search,
                validator: (value) {
                  if (value == null || value.isEmpty || selectedClienteId == null) {
                    return 'Seleccione una opción válida de la lista';
                  }
                  return null;
                },
                onChanged: (val) {
                  if (selectedClienteId != null) {
                    onClienteCleared();
                  }
                },
              );
            },
          ),

          const SizedBox(height: 16),
          CustomInputField(controller: campamentoController, label: 'Campamento / Finca', icon: Icons.map),
          CustomInputField(controller: nombreContactoController, label: 'Nombre contacto', icon: Icons.phone_android),
          CustomInputField(controller: emailController, label: 'Correo electrónico', icon: Icons.email, keyboard: TextInputType.emailAddress),
          CustomInputField(controller: telefonoController, label: 'Teléfono', icon: Icons.phone, keyboard: TextInputType.phone),
          const SizedBox(height: 16),

          CustomDropdownField<TipoEquipo>(
            label: 'Tipo de Equipo',
            icon: Icons.precision_manufacturing,
            items: TipoEquipo.values,
            value: selectedEquipo,
            onChanged: onEquipoChanged,
          ),

          // Válvula condicional para "Otros"
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: selectedEquipo == TipoEquipo.Otros
                ? Padding(
                    padding: const EdgeInsets.only(top: 16.0),
                    child: CustomInputField(
                      controller: customEquipoController, 
                      label: 'Especifique equipo', 
                      icon: Icons.edit_note,
                      validator: (value) {
                        if (selectedEquipo == TipoEquipo.Otros && (value == null || value.trim().isEmpty)) {
                          return 'Error: Debe especificar el equipo manualmente.';
                        }
                        return null;
                      },
                    ),
                  )
                : const SizedBox.shrink(),
          ),

          const SizedBox(height: 16),
          CustomInputField(controller: fallaController, label: 'Falla Reportada', icon: Icons.report_problem, maxLines: 3),
          const SizedBox(height: 32),

          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: isProcessing ? null : onSubmit,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF005A9C), 
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: isProcessing
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                        SizedBox(width: 12),
                        Text('TRANSMITIENDO...', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ],
                    )
                  : const Text('REGISTRAR INGRESO', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}