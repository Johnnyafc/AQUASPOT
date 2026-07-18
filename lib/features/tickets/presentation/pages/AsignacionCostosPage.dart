import 'package:aquaspot_postventa/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:aquaspot_postventa/features/auth/presentation/bloc/auth_state.dart';
import 'package:aquaspot_postventa/features/tickets/domain/entities/ticket_entity.dart';
import 'package:aquaspot_postventa/features/tickets/presentation/bloc/ticket_bloc.dart';
import 'package:aquaspot_postventa/features/tickets/presentation/bloc/ticket_event.dart';
import 'package:aquaspot_postventa/features/tickets/presentation/bloc/ticket_state.dart'; // Añadido para asegurar acceso a TicketStatus
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class AsignacionCostosPage extends StatefulWidget {
  final TicketEntity ticket;
  const AsignacionCostosPage({super.key, required this.ticket});

  @override
  State<AsignacionCostosPage> createState() => _AsignacionCostosPageState();
}

class _AsignacionCostosPageState extends State<AsignacionCostosPage> {
  final _formKey = GlobalKey<FormState>();
  final _controllerProyecto = TextEditingController();

  @override
  Widget build(BuildContext context) {
    // 🚀 Sensor BLoC instalado para escuchar la telemetría del estado general (Éxito/Error)
    return BlocListener<TicketBloc, TicketState>(
      listener: (context, state) {
        if (state.status == TicketStatus.operationSuccess) {
          // 1. Confirmación visual
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message)),
          );
          
          // 2. Limpieza de memoria
          _controllerProyecto.clear();
          
          // 3. Retorno a bandeja
          Navigator.of(context).pop();
        } else if (state.status == TicketStatus.error) {
          // Manejo de fallos innegociable
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error de sistema: ${state.message}')),
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Asignación de Proyecto - Costos')),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ⚙️ Parámetros de solo lectura (Origen del Ticket)
              _buildReadOnlyField("Tipo de servicio", widget.ticket.tipoRequerimiento.name),
              _buildReadOnlyField("Orden de Venta", widget.ticket.numeroOrdenVenta ?? 'No asignado'),
              _buildReadOnlyField("Cliente", widget.ticket.clienteId),
              _buildReadOnlyField("Máquina", widget.ticket.equipo.name),
              _buildReadOnlyField("Marca", widget.ticket.marca ?? 'No especificada'), 
              _buildReadOnlyField("Ubicación", widget.ticket.lugarAtencion.name),
              
              const Divider(height: 40),
              
              // ⚙️ Entrada Crítica: Código de Proyecto (Manual)
              TextFormField(
                controller: _controllerProyecto,
                decoration: const InputDecoration(
                  labelText: 'Código de Proyecto',
                  hintText: 'Ingrese el código asignado...',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.assignment_turned_in),
                ),
                validator: (val) => (val == null || val.isEmpty) 
                    ? 'El código de proyecto es obligatorio para desbloquear Compras' 
                    : null,
              ),
              
              const SizedBox(height: 24),
              
              // ⚙️ Actuador Principal con Enclavamiento de Seguridad
              BlocBuilder<TicketBloc, TicketState>(
                builder: (context, state) {
                  final isLoading = state.status == TicketStatus.loading;

                  return ElevatedButton(
                    // 🔒 Interlock: Si está en proceso, el circuito se abre (null)
                    onPressed: isLoading ? null : _guardarAsignacion,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[800], 
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'ASIGNAR Y DESBLOQUEAR COMPRAS', 
                            style: TextStyle(color: Colors.white),
                          ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReadOnlyField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        initialValue: value,
        readOnly: true,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), filled: true, fillColor: Colors.grey[100]),
      ),
    );
  }

  void _guardarAsignacion() {
    print("lanzamos guardar asignación");
    if (_formKey.currentState!.validate()) {
      // 1. Obtenemos el estado de autenticación para la trazabilidad
      final authState = context.read<AuthBloc>().state;

      // 2. Validación de seguridad (Innegociable)
      if (authState is! Authenticated) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: No se puede asignar proyecto sin usuario autenticado.')),
        );
        return;
      }

      // 3. Disparo del evento correcto con toda la data industrial
      print("lanzamos completar fase de costo");
      context.read<TicketBloc>().add(CompletarFaseCostosEvent(
        ticket: widget.ticket,
        codigoProyecto: _controllerProyecto.text,
        nombreUsuario: authState.usuario.nombre,
        rolUsuario: authState.usuario.rol.name.toUpperCase(),
      ));
    }
  }
}