// lib/features/auth/presentation/pages/registro_usuario_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

// Asumo que tienes estos enums definidos en tu core/domain
import '../../../../core/enum/segmento_operativo.dart';
import '../../../../core/enum/rol_usuario.dart'; // Ajusta la ruta a tu enum de Rol

// El cerebro de la operación
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';

// Widgets modulares
import '../../../../features/tickets/presentation/widgets/custom_input_field_widget.dart';
import '../../../../features/tickets/presentation/widgets/section_title_widget.dart';

class RegistroUsuarioPage extends StatefulWidget {
  const RegistroUsuarioPage({super.key});

  @override
  State<RegistroUsuarioPage> createState() => _RegistroUsuarioPageState();
}

class _RegistroUsuarioPageState extends State<RegistroUsuarioPage> {
  final _formKey = GlobalKey<FormState>();
  
  // Sensores de entrada (Controllers)
  final _nombreController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  
  // Selectores de estado
  SegmentoOperativo? _selectedSegmento;
  // Reemplaza 'RolUsuario' por el nombre real de tu Enum
  RolUsuario? _selectedRol; 

  @override
  void dispose() {
    _nombreController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onRegistrarOperario() {
    // 1. Verificación de seguridad del tablero
    if (!_formKey.currentState!.validate()) return;

    if (_selectedSegmento == null || _selectedRol == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ Debe asignar un Segmento y un Rol al operario.')),
      );
      return;
    }

    // 2. Disparo de la señal al PLC (BLoC)
    // Pasamos los datos crudos, la vista no fabrica entidades.
    context.read<AuthBloc>().add(RegistrarUsuarioEvent(
      nombre: _nombreController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text.trim(),
      segmento: _selectedSegmento!,
      rol: _selectedRol!,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Alta de Nuevo Operario', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.blueGrey, // Diferenciamos el color de la sección administrativa
        foregroundColor: Colors.white,
      ),
body: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          // Monitoreo de la señal usando comprobación de tipos (is)
          if (state is AuthError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message), backgroundColor: Colors.red)
            );
          } else if (state is AuthRegistrationSuccess) { 
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('✅ ${state.message}'), 
                backgroundColor: Colors.green
              )
            );
            // Vaciamos los buffers visuales tras el alta exitosa
            _formKey.currentState?.reset();
            _nombreController.clear();
            _emailController.clear();
            _passwordController.clear();
            setState(() {
              _selectedSegmento = null;
              _selectedRol = null;
            });
          }
        },
        builder: (context, state) {
          // Enclavamiento de seguridad: Bloqueamos si el estado es tipo AuthLoading
          final isLocked = state is AuthLoading;

          return Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionTitleWidget(title: '1. Credenciales de Acceso'),
                  CustomInputFieldWidget(
                    label: 'Correo Electrónico Institucional',
                    controller: _emailController,
                    icon: Icons.email_outlined,
                  ),
                  CustomInputFieldWidget(
                    label: 'Contraseña Provisional',
                    controller: _passwordController,
                    icon: Icons.lock_outline,
                    // Nota: En un CustomInputFieldWidget ideal, deberías añadir un parámetro 'obscureText'
                  ),

                  const Divider(height: 32, thickness: 2),

                  const SectionTitleWidget(title: '2. Perfil Operativo'),
                  CustomInputFieldWidget(
                    label: 'Nombre Completo',
                    controller: _nombreController,
                    icon: Icons.person_outline,
                  ),
                  
                  // Selector de Segmento
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: DropdownButtonFormField<SegmentoOperativo>(
                      value: _selectedSegmento,
                      decoration: InputDecoration(
                        labelText: 'Segmento Asignado',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        prefixIcon: const Icon(Icons.domain),
                      ),
                      items: SegmentoOperativo.values.map((s) {
                        return DropdownMenuItem(value: s, child: Text(s.name.toUpperCase()));
                      }).toList(),
                      onChanged: (val) => setState(() => _selectedSegmento = val),
                      validator: (value) => value == null ? 'Requerido' : null,
                    ),
                  ),

                  // Selector de Rol
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: DropdownButtonFormField<RolUsuario>(
                      value: _selectedRol,
                      decoration: InputDecoration(
                        labelText: 'Rol de Sistema',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        prefixIcon: const Icon(Icons.manage_accounts),
                      ),
                      items: RolUsuario.values.map((r) {
                        return DropdownMenuItem(value: r, child: Text(r.name.toUpperCase()));
                      }).toList(),
                      onChanged: (val) => setState(() => _selectedRol = val),
                      validator: (value) => value == null ? 'Requerido' : null,
                    ),
                  ),

                  const SizedBox(height: 32),
                  
                  // Botón de Arranque
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueGrey,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: isLocked ? null : _onRegistrarOperario,
                      child: isLocked 
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            'REGISTRAR OPERARIO', 
                            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)
                          ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}