// lib/features/tickets/presentation/pages/creacion_ticket_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/ticket_bloc.dart';
import '../bloc/ticket_event.dart';
import '../bloc/ticket_state.dart';
import '../../domain/entities/ticket_entity.dart';
import '../../domain/entities/ticket_enums.dart';

class CreacionTicketPage extends StatefulWidget {
  const CreacionTicketPage({super.key});

  @override
  State<CreacionTicketPage> createState() => _CreacionTicketPageState();
}

class _CreacionTicketPageState extends State<CreacionTicketPage> {
  final _formKey = GlobalKey<FormState>();
  final _clienteController = TextEditingController();
  final _campamentoController = TextEditingController();
  final _nombreContactoController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _fallaController = TextEditingController();

  Sede? _selectedSede;
  TipoEquipo? _selectedEquipo;

  @override
  void dispose() {
    _clienteController.dispose();
    _campamentoController.dispose();
    _nombreContactoController.dispose();
    _telefonoController.dispose();
    _fallaController.dispose();
    super.dispose();
  }

  void _submitForm() {
    if (!_formKey.currentState!.validate()) return;
    
    final nuevoTicket = TicketEntity(
      id: 'TEMP-${DateTime.now().millisecondsSinceEpoch}',
      estadoActual: EstadoTicket.values.first,
      sede: _selectedSede!,
      clienteId: _clienteController.text,
      campamento: _campamentoController.text,
      nombreContacto: _nombreContactoController.text,
      telefonoContacto: _telefonoController.text,
      equipo: _selectedEquipo!,
      fallaReportada: _fallaController.text,
      historialEventos: const [],
    );

    context.read<TicketBloc>().add(CrearTicketEvent(nuevoTicket));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5), // Color tipo feed de red social
      appBar: AppBar(
        title: const Text('Nuevo Ingreso', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: BlocConsumer<TicketBloc, TicketState>(
        listener: (context, state) {
          if (state is TicketError) {
             ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.message), backgroundColor: Colors.red));
          } else if (state is TicketOperationSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Registro Exitoso'), backgroundColor: Colors.green));
             _formKey.currentState!.reset(); // Limpieza moderna
          }
        },
        builder: (context, state) {
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600), // Ancho máximo tipo feed
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Detalles del Servicio", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                          const Divider(height: 30),
                          
                          _buildDropdownField<Sede>(
                            label: 'Sede',
                            icon: Icons.business,
                            items: Sede.values,
                            value: _selectedSede,
                            onChanged: (val) => setState(() => _selectedSede = val),
                          ),
                          const SizedBox(height: 16),
                          _buildTextField(_clienteController, 'Razón Social / Cliente', Icons.person),
                          _buildTextField(_campamentoController, 'Campamento / Finca', Icons.map),
                          _buildTextField(_nombreContactoController, 'Contacto', Icons.phone_android),
                          _buildTextField(_telefonoController, 'Teléfono', Icons.phone, keyboard: TextInputType.phone),
                          
                          const SizedBox(height: 16),
                          _buildDropdownField<TipoEquipo>(
                            label: 'Tipo de Equipo',
                            icon: Icons.precision_manufacturing,
                            items: TipoEquipo.values,
                            value: _selectedEquipo,
                            onChanged: (val) => setState(() => _selectedEquipo = val),
                          ),
                          const SizedBox(height: 16),
                          _buildTextField(_fallaController, 'Falla Reportada', Icons.report_problem, maxLines: 3),
                          
                          const SizedBox(height: 32),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: _submitForm,
                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF005A9C), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                              child: const Text('REGISTRAR INGRESO', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            ),
                          )
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // Helpers para mantener el código limpio (Patrón DRY)
  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {TextInputType? keyboard, int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboard,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          filled: true,
          fillColor: Colors.grey[50],
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        ),
        validator: (v) => v!.isEmpty ? 'Requerido' : null,
      ),
    );
  }

  Widget _buildDropdownField<T>({required String label, required IconData icon, required List<T> items, T? value, required Function(T?) onChanged}) {
    return DropdownButtonFormField<T>(
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: Colors.grey[50],
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
      value: value,
      items: items.map((e) => DropdownMenuItem(value: e, child: Text(e.toString().split('.').last.toUpperCase()))).toList(),
      onChanged: onChanged,
      validator: (v) => v == null ? 'Seleccione una opción' : null,
    );
  }
}