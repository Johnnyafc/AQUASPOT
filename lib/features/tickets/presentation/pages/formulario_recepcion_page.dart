// lib/features/tickets/presentation/pages/formulario_recepcion_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/ticket_entity.dart';
import '../bloc/ticket_bloc.dart';

class FormularioRecepcionPage extends StatefulWidget {
  final TicketEntity ticket;

  const FormularioRecepcionPage({super.key, required this.ticket});

  @override
  State<FormularioRecepcionPage> createState() => _FormularioRecepcionPageState();
}

class _FormularioRecepcionPageState extends State<FormularioRecepcionPage> {
  final _formKey = GlobalKey<FormState>();
  
  // Controlador ÚNICO para la inspección física activa en recepción
  final _descripcionController = TextEditingController(); 
  
  String _tipoRequerimiento = 'Mantenimiento'; 

  @override
  void dispose() {
    _descripcionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Acta de Recepción', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle('1. Datos Heredados (Solo Lectura)'),
              // Todo esto ya viene pre-cargado desde la fase de Requerimiento
              _buildReadOnlyField('Cliente / Razón Social', widget.ticket.clienteId, Icons.business),
              _buildReadOnlyField('Contacto / Quien Entrega', widget.ticket.nombreContacto, Icons.person),
              _buildReadOnlyField('Teléfono', widget.ticket.telefonoContacto ?? 'N/A', Icons.phone),
              _buildReadOnlyField('Tipo de Equipo', widget.ticket.equipo.name.toUpperCase(), Icons.precision_manufacturing),
              
              // LA SERIE PASA A SER DE SOLO LECTURA PARA VALIDACIÓN VISUAL
              _buildReadOnlyField('Número de Serie', widget.ticket.numeroSerie ?? 'Serie no registrada', Icons.qr_code), // Cambia .id por .numeroSerie si lo tienes en otra variable
              
              _buildReadOnlyField('Falla Reportada', widget.ticket.fallaReportada, Icons.report_problem, lines: 2),
              
              const Divider(height: 32, thickness: 2),

              _buildSectionTitle('2. Datos de Ingreso Físico'),
              
              DropdownButtonFormField<String>(
                value: _tipoRequerimiento,
                decoration: InputDecoration(
                  labelText: 'Tipo de Requerimiento',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  prefixIcon: const Icon(Icons.build_circle_outlined),
                ),
                items: ['Garantía', 'Mantenimiento'].map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (newValue) {
                  setState(() {
                    _tipoRequerimiento = newValue!;
                  });
                },
              ),
              const SizedBox(height: 16),

              _buildInputField(
                label: 'Descripción / Notas de Recepción',
                controller: _descripcionController,
                icon: Icons.description_outlined,
                lines: 3,
                hint: 'Ej: Equipo llega con carcasa rayada, sin cables de alimentación...',
              ),

              const Divider(height: 32, thickness: 2),

              _buildSectionTitle('3. Evidencia Fotográfica'),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.camera_alt_outlined, size: 40, color: Colors.grey),
                    const SizedBox(height: 8),
                    const Text('Adjunte fotos del estado actual del equipo', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Módulo de cámara en construcción')),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        foregroundColor: Colors.teal,
                        backgroundColor: Colors.teal.shade50,
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.add_a_photo),
                      label: const Text('CAPTURAR FOTO'),
                    )
                  ],
                ),
              ),

              const Divider(height: 32, thickness: 2),

              _buildSectionTitle('4. Registro de Sistema'),
              _buildReadOnlyField('Timestamp de Ingreso', DateTime.now().toString().substring(0, 16), Icons.access_time),

              const SizedBox(height: 32),
              
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: _procesarRecepcion,
                  child: const Text('CONFIRMAR RECEPCIÓN', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // --- Subrutinas de Renderizado ---
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0, top: 8.0),
      child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.teal)),
    );
  }

  Widget _buildReadOnlyField(String label, String value, IconData icon, {int lines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: TextFormField(
        initialValue: value,
        maxLines: lines,
        readOnly: true,
        style: const TextStyle(color: Colors.black54), 
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: Colors.grey),
          filled: true,
          fillColor: Colors.grey.shade100,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required String label, 
    required TextEditingController controller, 
    required IconData icon, 
    int lines = 1,
    String? hint,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: lines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: Colors.teal),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.teal, width: 2),
        ),
      ),
      validator: (value) => (value == null || value.trim().isEmpty) ? 'Dato requerido para control de calidad.' : null,
    );
  }

  // --- Lógica de Control ---
  void _procesarRecepcion() {
    if (!_formKey.currentState!.validate()) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Procesando recepción y actualizando estado...')),
    );
    Navigator.pop(context); 
  }
}