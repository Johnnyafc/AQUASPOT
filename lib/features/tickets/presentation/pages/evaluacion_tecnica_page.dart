// lib/features/tickets/presentation/pages/evaluacion_tecnica_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/ticket_entity.dart';
import '../../domain/entities/ticket_enums.dart';
import '../../domain/entities/evaluacion_tecnica_entity.dart';
import '../../domain/entities/evento_auditoria_entity.dart';
import '../../../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../../../features/auth/presentation/bloc/auth_state.dart';
import '../bloc/ticket_bloc.dart';
import '../bloc/ticket_event.dart';

class EvaluacionTecnicaPage extends StatefulWidget {
  final TicketEntity ticket;

  const EvaluacionTecnicaPage({super.key, required this.ticket});

  @override
  State<EvaluacionTecnicaPage> createState() => _EvaluacionTecnicaPageState();
}

class _EvaluacionTecnicaPageState extends State<EvaluacionTecnicaPage> {
  final _formKey = GlobalKey<FormState>();
  final _serieController = TextEditingController();
  final _descController = TextEditingController();
  Prioridad _prioridad = Prioridad.media;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Evaluación Técnica")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _buildField("Serie del equipo", _serieController, Icons.qr_code),
              const SizedBox(height: 16),
              _buildField("Descripción técnica", _descController, Icons.description, lines: 3),
              const SizedBox(height: 16),
              DropdownButtonFormField<Prioridad>(
                value: _prioridad,
                decoration: const InputDecoration(labelText: 'Prioridad', border: OutlineInputBorder()),
                items: Prioridad.values.map((p) => DropdownMenuItem(value: p, child: Text(p.name.toUpperCase()))).toList(),
                onChanged: (v) => setState(() => _prioridad = v!),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF005A9C), padding: const EdgeInsets.all(16)),
                  onPressed: _guardarEvaluacion,
                  child: const Text("GUARDAR EVALUACIÓN", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField(String label, TextEditingController controller, IconData icon, {int lines = 1}) {
    return TextFormField(
      controller: controller,
      maxLines: lines,
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), prefixIcon: Icon(icon)),
      validator: (v) => v!.isEmpty ? 'Campo obligatorio' : null,
    );
  }

  void _guardarEvaluacion() {
    if (!_formKey.currentState!.validate()) return;

    final authState = context.read<AuthBloc>().state;
    if (authState is Authenticated) {
      final supervisor = authState.usuario;
      
      // 1. Crear el objeto de evaluación
      final evaluacion = EvaluacionTecnicaEntity(
        serieEquipo: _serieController.text.trim(),
        diagnostico: _descController.text.trim(),
        prioridad: _prioridad,
      );

      // 2. Crear evento de auditoría
      final evento = EventoAuditoriaEntity(
        accion: 'EVALUACIÓN TÉCNICA COMPLETADA',
        usuarioNombre: supervisor.nombre,
        usuarioRol: supervisor.rol.name,
        timestamp: DateTime.now(),
      );

      // 3. Clonar ticket con nuevos datos
      final ticketActualizado = widget.ticket.copyWith(
        evaluacionTecnica: evaluacion,
        estadoActual: EstadoTicket.evaluacionTecnica,
        historialEventos: [...widget.ticket.historialEventos, evento],
      );

      // 4. Disparar al PLC
      context.read<TicketBloc>().add(ActualizarEvaluacionEvent(ticket: ticketActualizado));
      Navigator.pop(context); // Regresar a la bandeja
    }
  }
}