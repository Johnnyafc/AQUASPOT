import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../injection_container.dart';
import '../../domain/entities/cliente_entity.dart';
import '../bloc/cliente_bloc.dart';
import '../bloc/cliente_event.dart';
import '../bloc/cliente_state.dart';

class EditarClienteBottomSheet extends StatefulWidget {
  final ClienteEntity cliente;

  const EditarClienteBottomSheet({super.key, required this.cliente});

  static Future<bool?> show(BuildContext context, {required ClienteEntity cliente}) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => BlocProvider<ClienteBloc>(
        create: (context) => sl<ClienteBloc>(),
        child: EditarClienteBottomSheet(cliente: cliente),
      ),
    );
  }

  @override
  State<EditarClienteBottomSheet> createState() => _EditarClienteBottomSheetState();
}

class _EditarClienteBottomSheetState extends State<EditarClienteBottomSheet> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _grupoController;
  late TextEditingController _fincaController;
  late TextEditingController _nombreContactoController;
  late TextEditingController _emailContactoController;
  late TextEditingController _celularController;
  late String _subSector;
  late String _estadoActual;

  final List<String> _sedesDisponibles = ['GUAYAS', 'EL ORO', 'SANTA ELENA', 'ESMERALDA', 'PERU'];
  final List<String> _estadosDisponibles = ['activo', 'inactivo'];

  @override
  void initState() {
    super.initState();
    _grupoController = TextEditingController(text: widget.cliente.camaronera);
    _fincaController = TextEditingController(text: widget.cliente.direccion);
    _nombreContactoController = TextEditingController(text: widget.cliente.nombreContacto);
    _emailContactoController = TextEditingController(text: widget.cliente.emailContacto);
    _celularController = TextEditingController(text: widget.cliente.celular);

    _subSector = _sedesDisponibles.contains(widget.cliente.subSector.toUpperCase())
        ? widget.cliente.subSector.toUpperCase()
        : _sedesDisponibles.first;

    _estadoActual = _estadosDisponibles.contains(widget.cliente.estadoActual.toLowerCase())
        ? widget.cliente.estadoActual.toLowerCase()
        : 'activo';
  }

  @override
  void dispose() {
    _grupoController.dispose();
    _fincaController.dispose();
    _nombreContactoController.dispose();
    _emailContactoController.dispose();
    _celularController.dispose();
    super.dispose();
  }

  void _submitUpdate() {
    if (!_formKey.currentState!.validate()) return;

    final updatedCliente = widget.cliente.copyWith(
      camaronera: _grupoController.text.trim(),
      direccion: _fincaController.text.trim(),
      nombreContacto: _nombreContactoController.text.trim(),
      emailContacto: _emailContactoController.text.trim(),
      celular: _celularController.text.trim(),
      subSector: _subSector,
      estadoActual: _estadoActual,
    );

    context.read<ClienteBloc>().add(
      ActualizarClienteSubmitEvent(cliente: updatedCliente),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ClienteBloc, ClienteState>(
      listener: (context, state) {
        if (state is ClienteActualizadoSuccess) {
          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Cliente actualizado correctamente.'),
              backgroundColor: Colors.green,
            ),
          );
        } else if (state is ClienteError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('🛑 Error: ${state.message}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
      builder: (context, state) {
        final isLoading = state is ClienteLoading;

        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Editar Cliente',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF005A9C),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.grey),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const Divider(thickness: 1.5),
                  const SizedBox(height: 10),

                  // 1. SEDE (SubSector)
                  DropdownButtonFormField<String>(
                    decoration: _inputStyle('Sede camaronera', Icons.business),
                    initialValue: _subSector,
                    items: _sedesDisponibles.map((sede) {
                      return DropdownMenuItem(value: sede, child: Text(sede));
                    }).toList(),
                    onChanged: isLoading ? null : (val) => setState(() => _subSector = val!),
                  ),
                  const SizedBox(height: 14),

                  // 2. GRUPO / RAZÓN SOCIAL (camaronera)
                  TextFormField(
                    controller: _grupoController,
                    decoration: _inputStyle('Grupo / Razón Social', Icons.search),
                    textCapitalization: TextCapitalization.words,
                    enabled: !isLoading,
                    validator: (val) => val == null || val.trim().isEmpty ? 'Requerido' : null,
                  ),
                  const SizedBox(height: 14),

                  // 3. CAMPO FINCA (direccion)
                  TextFormField(
                    controller: _fincaController,
                    decoration: _inputStyle('Campamento / Finca', Icons.map),
                    textCapitalization: TextCapitalization.words,
                    enabled: !isLoading,
                    validator: (val) => val == null || val.trim().isEmpty ? 'Requerido' : null,
                  ),
                  const SizedBox(height: 14),

                  // 4. NOMBRE CONTACTO
                  TextFormField(
                    controller: _nombreContactoController,
                    decoration: _inputStyle('Nombre Contacto', Icons.person),
                    textCapitalization: TextCapitalization.words,
                    enabled: !isLoading,
                  ),
                  const SizedBox(height: 14),

                  // 5. TELÉFONO
                  TextFormField(
                    controller: _celularController,
                    decoration: _inputStyle('Teléfono', Icons.phone),
                    keyboardType: TextInputType.phone,
                    enabled: !isLoading,
                  ),
                  const SizedBox(height: 14),

                  // 6. CORREO
                  TextFormField(
                    controller: _emailContactoController,
                    decoration: _inputStyle('Correo electrónico', Icons.email),
                    keyboardType: TextInputType.emailAddress,
                    enabled: !isLoading,
                  ),
                  const SizedBox(height: 14),

                  // 7. ESTADO (Activo / Inactivo)
                  DropdownButtonFormField<String>(
                    decoration: _inputStyle('Estado del Cliente', Icons.toggle_on),
                    initialValue: _estadoActual,
                    items: const [
                      DropdownMenuItem(value: 'activo', child: Text('Activo (Habilitado)')),
                      DropdownMenuItem(value: 'inactivo', child: Text('Inactivo (Deshabilitado)')),
                    ],
                    onChanged: isLoading ? null : (val) => setState(() => _estadoActual = val!),
                  ),
                  const SizedBox(height: 24),

                  // BOTÓN GUARDAR
                  SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF005A9C),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: isLoading ? null : _submitUpdate,
                      child: isLoading
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                            )
                          : const Text(
                              'GUARDAR CAMBIOS',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  InputDecoration _inputStyle(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: const Color(0xFF005A9C)),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.orange, width: 2),
      ),
      filled: true,
      fillColor: Colors.grey[50],
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );
  }
}
