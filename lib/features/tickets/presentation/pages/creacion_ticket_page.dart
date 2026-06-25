// lib/features/tickets/presentation/pages/creacion_ticket_page.dart

import 'dart:io'; // ✅ Requerido para el buffer de evidencias
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/ticket_bloc.dart';
import '../bloc/ticket_event.dart';
import '../bloc/ticket_state.dart';
import '../../domain/entities/ticket_entity.dart';
import '../../domain/entities/ticket_enums.dart';
import '../../../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../../../features/auth/presentation/bloc/auth_state.dart';
import '../../domain/entities/cliente_entity.dart';


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
  final _emailController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _fallaController = TextEditingController();

   String? _selectedClienteId; // ⚠️ AQUI GUARDAMOS EL ID REAL DEL CLIENTE
  Sede? _selectedSede;
  TipoEquipo? _selectedEquipo;

@override
  void initState() {
    super.initState();
    // Encendemos la bomba para extraer los datos desde Firestore a la RAM
    context.read<TicketBloc>().add(ObtenerClientesEvent()); // Verifica que tu evento se llame así
  }

  @override
  void dispose() {
    _clienteController.dispose();
    _campamentoController.dispose();
    _nombreContactoController.dispose();
    _emailController.dispose();
    _telefonoController.dispose();
    _fallaController.dispose();
    super.dispose();
  }

  void _limpiarFormulario() {
    // Forzamos el cierre de cualquier teclado o focus activo
    FocusScope.of(context).unfocus();
    
    _clienteController.clear();
    _campamentoController.clear();
    _nombreContactoController.clear();
    _telefonoController.clear();
    _emailController.clear();
    _fallaController.clear();
    
    setState(() {
      _selectedSede = null;
      _selectedEquipo = null;
      _selectedClienteId = null;
    });
    
    _formKey.currentState?.reset();
  }

void _submitForm() {
    if (!_formKey.currentState!.validate()) return;

    // 🛑 COMPUERTA DE SEGURIDAD: Verificar que seleccionó un cliente de la lista
    if (_selectedClienteId == null || _selectedClienteId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ Debe seleccionar una Camaronera de la lista sugerida.')),
      );
      return;
    }
    
    final authState = context.read<AuthBloc>().state;
    String nombreOperario = 'SISTEMA';
    String rolOperario = 'DESCONOCIDO';
    
    if (authState is Authenticated) {
      nombreOperario = authState.usuario.nombre; 
      rolOperario = authState.usuario.rol.name.toUpperCase();
    }

    final ticketBorrador = TicketEntity(
      id: '',
      estadoActual: EstadoTicket.creado,
      sede: _selectedSede!,
      clienteId: _selectedClienteId!, // 🚀 USAMOS EL ID REAL, NO EL TEXTO
      campamento: _campamentoController.text,
      nombreContacto: _nombreContactoController.text,
      telefonoContacto: _telefonoController.text,
      emailContacto: _emailController.text,
      equipo: _selectedEquipo!,
      fallaReportada: _fallaController.text,
      numeroSerie: null,
      historialEventos: const [], 
      fotosUrls: const [],
    );

    context.read<TicketBloc>().add(CrearTicketEvent(
      ticket: ticketBorrador,
      nombreUsuario: nombreOperario,
      rolUsuario: rolOperario,
      evidencias: const [],
    ));
  }
@override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
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
            _limpiarFormulario(); 
            
            if (!context.mounted) return; 
            Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
          }
        },
        builder: (context, state) {
          // Extraemos la lista de clientes en RAM desde el estado
          final List<ClienteEntity> listaClientes = state is TicketLoaded ? state.clientes : [];

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
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

                          // ==========================================================
                          // 🚀 ACTUADOR PREDICTIVO DE CLIENTES (In-Memory Cache)
                          // ==========================================================
                          Autocomplete<ClienteEntity>(
                            displayStringForOption: (ClienteEntity option) => option.camaronera,
                            optionsBuilder: (TextEditingValue textEditingValue) {
                              if (textEditingValue.text.isEmpty) {
                                return const Iterable<ClienteEntity>.empty();
                              }
                              return listaClientes.where((ClienteEntity cliente) {
                                return cliente.camaronera
                                    .toLowerCase()
                                    .contains(textEditingValue.text.toLowerCase());
                              });
                            },
                            onSelected: (ClienteEntity seleccion) {
                              // Telemetría automática hacia los controladores de UI
                              setState(() {
                                _selectedClienteId = seleccion.camaronera;
                                _campamentoController.text = seleccion.direccion;
                                _nombreContactoController.text = seleccion.nombreContacto;
                                _emailController.text = seleccion.emailContacto;
                                _telefonoController.text = seleccion.celular;
                              });
                            },
                            fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                              return TextFormField(
                                controller: textEditingController,
                                focusNode: focusNode,
                                decoration: const InputDecoration(
                                  labelText: 'Razón Social / Cliente (Buscar...)',
                                  prefixIcon: Icon(Icons.search),
                                  border: OutlineInputBorder(),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty || _selectedClienteId == null) {
                                    return 'Seleccione una opción válida de la lista';
                                  }
                                  return null;
                                },
                                onChanged: (val) {
                                  if (_selectedClienteId != null) {
                                    setState(() => _selectedClienteId = null);
                                  }
                                },
                              );
                            },
                          ),
                          // ==========================================================
                          
                          const SizedBox(height: 16),
                          _buildTextField(_campamentoController, 'Campamento / Finca', Icons.map),
                          _buildTextField(_nombreContactoController, 'Nombre contacto', Icons.phone_android),
                          _buildTextField(_emailController, 'Correo electronico', Icons.email, keyboard: TextInputType.emailAddress),
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
                              onPressed: state is TicketLoading ? null : _submitForm,
                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF005A9C), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                              child: state is TicketLoading 
                                  ? const CircularProgressIndicator(color: Colors.white) 
                                  : const Text('REGISTRAR INGRESO', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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