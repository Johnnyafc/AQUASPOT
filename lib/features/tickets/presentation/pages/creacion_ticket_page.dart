// lib/features/tickets/presentation/pages/creacion_ticket_page.dart

import 'dart:io'; 
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/ticket_bloc.dart';
import '../bloc/ticket_event.dart';
import '../bloc/ticket_state.dart';
import '../../domain/entities/ticket_entity.dart';
import '../../../../core/enum/ticket_enums.dart';
import '../../../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../../../features/auth/presentation/bloc/auth_state.dart';
import '../../domain/entities/cliente_entity.dart';
import '../widgets/ticket_form_widget.dart';

class CreacionTicketPage extends StatefulWidget {
  const CreacionTicketPage({super.key});

  @override
  State<CreacionTicketPage> createState() => _CreacionTicketPageState();
}

class _CreacionTicketPageState extends State<CreacionTicketPage> {
  final _formKey = GlobalKey<FormState>();
  
  final TextEditingController _clienteController = TextEditingController();
  final TextEditingController _customEquipoController = TextEditingController();
  final TextEditingController _campamentoController = TextEditingController();
  final TextEditingController _nombreContactoController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _telefonoController = TextEditingController();
  final TextEditingController _fallaController = TextEditingController();

  String? _selectedClienteId; 
  Sede? _selectedSede;
  TipoEquipo? _selectedEquipo;

  @override
  void initState() {
    super.initState();
    // ⚙️ Descarga asíncrona de datos desde Firestore a la RAM local
    context.read<TicketBloc>().add(ObtenerClientesEvent()); 
  }

  @override
  void dispose() {
    _clienteController.dispose();
    _customEquipoController.dispose();
    _campamentoController.dispose();
    _nombreContactoController.dispose();
    _emailController.dispose();
    _telefonoController.dispose();
    _fallaController.dispose();
    super.dispose();
  }

  void _limpiarFormulario() {
    FocusScope.of(context).unfocus();
    
    _clienteController.clear();
    _customEquipoController.clear();
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
    // 1. Validaciones de Interfaz (Sensores locales)
    if (!_formKey.currentState!.validate()) return;

    if (_selectedClienteId == null || _selectedClienteId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ Debe seleccionar un Cliente de la lista sugerida.')),
      );
      return;
    }
    
    // 2. Extracción de variables de entorno
    final authState = context.read<AuthBloc>().state;
    String nombreOperario = 'SISTEMA';
    String rolOperario = 'DESCONOCIDO';
    
    if (authState is Authenticated) {
      nombreOperario = authState.usuario.nombre; 
      rolOperario = authState.usuario.rol.name.toUpperCase();
    }

    final String? detalleDelEquipo = (_selectedEquipo == TipoEquipo.Otros) 
        ? _customEquipoController.text.trim() 
        : null;

    // 3. Disparo de Señal al Controlador Lógico (BLoC)
    context.read<TicketBloc>().add(CrearTicketEvent(
      sede: _selectedSede!,
      clienteId: _selectedClienteId!, 
      campamento: _campamentoController.text.trim(),
      nombreContacto: _nombreContactoController.text.trim(),
      telefonoContacto: _telefonoController.text.trim(),
      emailContacto: _emailController.text.trim(),
      equipo: _selectedEquipo!, 
      equipoDetalle: detalleDelEquipo, 
      fallaReportada: _fallaController.text.trim(),
      nombreUsuario: nombreOperario,
      rolUsuario: rolOperario,
      evidencias: const [], // O la variable donde tengas las fotos iniciales si aplica
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: const Text('Nuevo Requerimiento', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: BlocConsumer<TicketBloc, TicketState>(
        listenWhen: (previous, current) => previous.status != current.status,
        listener: (context, state) {
          if (state.status == TicketStatus.error) {
             ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.message), backgroundColor: Colors.red));
          } else if (state.status == TicketStatus.operationSuccess) { 
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Registro Exitoso'), backgroundColor: Colors.green));
            _limpiarFormulario(); 
            if (!context.mounted) return; 
            Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
          }
        },
        builder: (context, state) {
          final isProcessing = state.status == TicketStatus.loading;

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: AbsorbPointer(
                absorbing: isProcessing,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: TicketForm(
                        formKey: _formKey,
                        isProcessing: isProcessing,
                        listaClientes: state.clientes,
                        clienteController: _clienteController,
                        campamentoController: _campamentoController,
                        nombreContactoController: _nombreContactoController,
                        emailController: _emailController,
                        telefonoController: _telefonoController,
                        fallaController: _fallaController,
                        customEquipoController: _customEquipoController,
                        selectedSede: _selectedSede,
                        selectedEquipo: _selectedEquipo,
                        selectedClienteId: _selectedClienteId,
                        onSedeChanged: (val) => setState(() => _selectedSede = val),
                        onEquipoChanged: (val) {
                          setState(() {
                            _selectedEquipo = val;
                            if (val != TipoEquipo.Otros) _customEquipoController.clear();
                          });
                        },
                        onClienteSelected: (seleccion) {
                          setState(() {
                            _selectedClienteId = seleccion.camaronera;
                            _clienteController.text = seleccion.camaronera;
                            _campamentoController.text = seleccion.direccion;
                            _nombreContactoController.text = seleccion.nombreContacto;
                            _emailController.text = seleccion.emailContacto;
                            _telefonoController.text = seleccion.celular;
                          });
                        },
                        onClienteCleared: () {
                          setState(() => _selectedClienteId = null);
                        },
                        onSubmit: _submitForm,
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
}