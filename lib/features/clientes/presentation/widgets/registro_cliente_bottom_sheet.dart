import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/cliente_bloc.dart';
import '../bloc/cliente_event.dart';
import '../bloc/cliente_state.dart';
import '../../../../injection_container.dart';

class RegistroClienteBottomSheet extends StatefulWidget {
  const RegistroClienteBottomSheet({super.key});

  // ⚙️ LLAVE MAESTRA: Método estático para invocar el panel desde cualquier pantalla
// ⚙️ LLAVE MAESTRA: Ahora devuelve un Future<bool?>
  static Future<bool?> show(BuildContext context) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true, 
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => BlocProvider<ClienteBloc>(
        create: (context) => sl<ClienteBloc>(), 
        child: const RegistroClienteBottomSheet(),
      ),
    );
  }

  @override
  State<RegistroClienteBottomSheet> createState() => _RegistroClienteBottomSheetState();
}

class _RegistroClienteBottomSheetState extends State<RegistroClienteBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  
  // Buffers de memoria de los sensores (Inputs)
  String _direccion = ''; // Razón Social
  String _camaronera = '';
  String _nombreContacto = '';
  String _emailContacto = '';
  String _celular = '';
  String _subSector = 'DURAN'; // Valor nominal por defecto

  final List<String> _sedesDisponibles = ['EL_GUABO', 'DURAN'];

  void _submitForm() {
    // ⚙️ Enclavamiento: Si el formulario es inválido, abortamos
    if (!_formKey.currentState!.validate()) return;
    
    _formKey.currentState!.save();
    
    // Disparamos la señal al autómata
    context.read<ClienteBloc>().add(
      RegistrarClienteSubmitEvent(
        camaronera: _camaronera,
        celular: _celular,
        direccion: _direccion,
        emailContacto: _emailContacto,
        nombreContacto: _nombreContacto,
        subSector: _subSector,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ⚙️ Consumidor: Escucha al BLoC y dibuja la interfaz simultáneamente
    return BlocConsumer<ClienteBloc, ClienteState>(
     listener: (context, state) {
        if (state is ClienteSuccess) {
          // ⚙️ SEÑAL DE RETORNO: Cerramos la escotilla y mandamos un 'true' por el cable
          Navigator.pop(context, true); 
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✅ Cliente registrado exitosamente en la red.'), backgroundColor: Colors.green),
          );
        } else if (state is ClienteError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('🛑 ALARMA: ${state.message}'), backgroundColor: Colors.red),
          );
        }
      },
      builder: (context, state) {
        return Padding(
          // ⚙️ Amortiguación adaptativa para el teclado del teléfono
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
                  const Text(
                    'Alta de Nuevo Cliente',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF005A9C)),
                    textAlign: TextAlign.center,
                  ),
                  const Divider(thickness: 2),
                  const SizedBox(height: 10),

                  // 1. SEDE (SubSector)
                  DropdownButtonFormField<String>(
                    decoration: _inputStyle('Sede Operativa', Icons.business),
                    value: _subSector,
                    items: _sedesDisponibles.map((sede) {
                      return DropdownMenuItem(value: sede, child: Text(sede));
                    }).toList(),
                    onChanged: (value) => setState(() => _subSector = value!),
                  ),
                  const SizedBox(height: 16),

                  // 2. RAZÓN SOCIAL (Dirección en Firestore)
                  TextFormField(
                    decoration: _inputStyle('Razón Social / Cliente', Icons.search),
                    textCapitalization: TextCapitalization.words,
                    validator: (val) => val == null || val.isEmpty ? 'Requerido' : null,
                    onSaved: (val) => _camaronera = val!,
                  ),
                  const SizedBox(height: 16),

                  // 3. CAMARONERA
                  TextFormField(
                    decoration: _inputStyle('Campamento / Finca', Icons.map),
                    textCapitalization: TextCapitalization.words,
                    validator: (val) => val == null || val.isEmpty ? 'Requerido' : null,
                    onSaved: (val) => _direccion = val!,
                  ),
                  const SizedBox(height: 16),

                  // 4. NOMBRE CONTACTO
                  TextFormField(
                    decoration: _inputStyle('Nombre Contacto', Icons.person),
                    textCapitalization: TextCapitalization.words,
                    onSaved: (val) => _nombreContacto = val ?? '',
                  ),
                  const SizedBox(height: 16),

                  // 5. TELÉFONO
                  TextFormField(
                    decoration: _inputStyle('Teléfono', Icons.phone),
                    keyboardType: TextInputType.phone,
                    onSaved: (val) => _celular = val ?? '',
                  ),
                  const SizedBox(height: 16),

                  // 6. CORREO
                  TextFormField(
                    decoration: _inputStyle('Correo electrónico', Icons.email),
                    keyboardType: TextInputType.emailAddress,
                    onSaved: (val) => _emailContacto = val ?? '',
                  ),
                  const SizedBox(height: 24),

                  // ⚙️ BOTÓN DE ACCIONAMIENTO
                  SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF005A9C),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: state is ClienteLoading ? null : _submitForm,
                      child: state is ClienteLoading
                          ? const CircularProgressIndicator(color: Colors.orange)
                          : const Text('REGISTRAR CLIENTE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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

  // ⚙️ Módulo de estandarización visual (Previene código espagueti en la UI)
  InputDecoration _inputStyle(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: Colors.grey),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.orange, width: 2),
      ),
      filled: true,
      fillColor: Colors.grey[100],
    );
  }
}