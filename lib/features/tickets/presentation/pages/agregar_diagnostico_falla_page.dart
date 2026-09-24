// lib/features/tickets/presentation/pages/agregar_diagnostico_falla_page.dart
//
// 🆕 Pantalla de carga retroactiva de diagnóstico de fallas para tickets
// antiguos. Reutiliza el mismo árbol categoría > subcategoría > falla que
// ya existe en subir_evidencia_trabajo_page.dart (_mostrarModalDiagnosticoFallas),
// pero como pantalla completa en vez de modal, y dispara por primera vez
// el evento GuardarDiagnosticoFallasEvent (ya existía en el bloc, nunca
// se usaba desde ninguna pantalla).

import 'package:aquaspot_postventa/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:aquaspot_postventa/features/auth/presentation/bloc/auth_state.dart';
import 'package:aquaspot_postventa/features/fallas/data/datasources/metrica_falla_remote_datasource.dart';
import 'package:aquaspot_postventa/features/fallas/domain/entities/metrica_falla_entity.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/ticket_bloc.dart';
import '../bloc/ticket_event.dart';
import '../bloc/ticket_state.dart';
import '../../domain/entities/ticket_entity.dart';

class AgregarDiagnosticoFallaPage extends StatefulWidget {
  final TicketEntity ticket;
  const AgregarDiagnosticoFallaPage({super.key, required this.ticket});

  @override
  State<AgregarDiagnosticoFallaPage> createState() => _AgregarDiagnosticoFallaPageState();
}

class _AgregarDiagnosticoFallaPageState extends State<AgregarDiagnosticoFallaPage> {
  final MetricaFallaRemoteDataSource _fallasDataSource = MetricaFallaRemoteDataSource();
  late List<DiagnosticoFallaEntity> _seleccionadas;

  @override
  void initState() {
    super.initState();
    _seleccionadas = List<DiagnosticoFallaEntity>.from(widget.ticket.diagnosticoFallas);
  }

  void _guardar() {
    if (_seleccionadas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona al menos una falla antes de guardar.'), backgroundColor: Colors.orange),
      );
      return;
    }

    final authState = context.read<AuthBloc>().state;
    String nombreUsuario = 'SISTEMA';
    String rolUsuario = 'DESCONOCIDO';
    if (authState is Authenticated) {
      nombreUsuario = authState.usuario.nombre;
      rolUsuario = authState.usuario.rol.name.toUpperCase();
    }

    context.read<TicketBloc>().add(
      GuardarDiagnosticoFallasEvent(
        ticket: widget.ticket,
        fallas: _seleccionadas,
        nombreUsuario: nombreUsuario,
        rolUsuario: rolUsuario,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<TicketBloc, TicketState>(
      listenWhen: (previous, current) =>
          previous.status != current.status &&
          (current.status == TicketStatus.operationSuccess || current.status == TicketStatus.error),
      listener: (context, state) {
        if (state.status == TicketStatus.operationSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message.isNotEmpty ? state.message : 'Diagnóstico guardado.'), backgroundColor: Colors.green),
          );
          Navigator.pop(context);
        } else if (state.status == TicketStatus.error) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message.isNotEmpty ? state.message : 'No se pudo guardar el diagnóstico.'), backgroundColor: Colors.red),
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('Diagnóstico de Fallas: ${widget.ticket.equipo.name}'),
          backgroundColor: const Color(0xFF003057),
          foregroundColor: Colors.white,
        ),
        body: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: const Color(0xFFF1F5F9),
              child: Text('Ticket ${widget.ticket.id}', style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF003057))),
            ),
            Expanded(
              child: StreamBuilder<MatrizFallasEquipoEntity>(
                stream: _fallasDataSource.escucharMatrizEquipo(widget.ticket.equipo.name),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final matriz = snapshot.data!;
                  final categorias = matriz.categorias;

                  if (categorias.isEmpty) {
                    return const Center(
                      child: Text('No hay catálogo de fallas configurado para este equipo.'),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: categorias.length,
                    itemBuilder: (context, catIdx) {
                      final cat = categorias[catIdx];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 1,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(color: Colors.grey.shade300),
                        ),
                        child: ExpansionTile(
                          initiallyExpanded: true,
                          title: Text(
                            cat.nombre,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: Color(0xFF003057),
                            ),
                          ),
                          children: [
                            if (cat.subcategorias.isEmpty)
                              const Padding(
                                padding: EdgeInsets.all(12.0),
                                child: Text(
                                  'Sin componentes configurados en esta categoría.',
                                  style: TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic),
                                ),
                              )
                            else
                              ...cat.subcategorias.map((sub) {
                                return Container(
                                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF9FBFC),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.blueGrey.shade100),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: Colors.blueGrey.shade50,
                                          borderRadius: const BorderRadius.vertical(top: Radius.circular(7)),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.device_hub, size: 15, color: Color(0xFF003057)),
                                            const SizedBox(width: 6),
                                            Text(
                                              sub.nombre,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                                color: Color(0xFF003057),
                                              ),
                                            ),
                                            const Spacer(),
                                            Text(
                                              '${sub.fallas.length} fallas',
                                              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (sub.fallas.isEmpty)
                                        const Padding(
                                          padding: EdgeInsets.all(8.0),
                                          child: Text(
                                            'Sin fallas definidas en este componente.',
                                            style: TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic),
                                          ),
                                        )
                                      else
                                        ...sub.fallas.map((falla) {
                                          final isChecked = _seleccionadas.any(
                                            (f) =>
                                                f.categoria == cat.nombre &&
                                                f.subcategoria == sub.nombre &&
                                                f.falla == falla,
                                          );

                                          return CheckboxListTile(
                                            dense: true,
                                            value: isChecked,
                                            title: Text(falla, style: const TextStyle(fontSize: 13)),
                                            activeColor: Colors.deepOrange,
                                            onChanged: (val) {
                                              setState(() {
                                                if (val == true) {
                                                  _seleccionadas.add(DiagnosticoFallaEntity(
                                                    categoria: cat.nombre,
                                                    subcategoria: sub.nombre,
                                                    falla: falla,
                                                  ));
                                                } else {
                                                  _seleccionadas.removeWhere(
                                                    (f) =>
                                                        f.categoria == cat.nombre &&
                                                        f.subcategoria == sub.nombre &&
                                                        f.falla == falla,
                                                  );
                                                }
                                              });
                                            },
                                          );
                                        }),
                                    ],
                                  ),
                                );
                              }),
                            const SizedBox(height: 6),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    offset: const Offset(0, -2),
                    blurRadius: 5,
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${_seleccionadas.length} fallas seleccionadas',
                        style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.blueGrey),
                      ),
                    ),
                    BlocBuilder<TicketBloc, TicketState>(
                      builder: (context, state) {
                        final guardando = state.status == TicketStatus.loading;
                        return ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepOrange,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: guardando
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.check, size: 18),
                          label: const Text('Guardar Diagnóstico'),
                          onPressed: guardando ? null : _guardar,
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
