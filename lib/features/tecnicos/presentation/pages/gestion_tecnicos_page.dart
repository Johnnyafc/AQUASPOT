// lib/features/tecnicos/presentation/pages/gestion_tecnicos_page.dart

import 'package:flutter/material.dart';
import '../../domain/entities/tecnico_entity.dart';
import '../../data/datasources/tecnico_remote_datasource.dart';

class GestionTecnicosPage extends StatefulWidget {
  const GestionTecnicosPage({super.key});

  @override
  State<GestionTecnicosPage> createState() => _GestionTecnicosPageState();
}

class _GestionTecnicosPageState extends State<GestionTecnicosPage> {
  final TecnicoRemoteDataSource _dataSource = TecnicoRemoteDataSource();
  String _filtroTexto = '';
  bool _mostrarInactivos = false;

  void _abrirModalTecnico({TecnicoEntity? tecnicoExistente}) {
    final nombreCtrl = TextEditingController(text: tecnicoExistente?.nombre ?? '');
    final rolCtrl = TextEditingController(text: tecnicoExistente?.rol ?? '');
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        tecnicoExistente == null ? Icons.person_add : Icons.edit,
                        color: const Color(0xFF005A9C),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        tecnicoExistente == null ? 'Nuevo Técnico' : 'Editar Técnico',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0D2438),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: nombreCtrl,
                    decoration: InputDecoration(
                      labelText: 'Nombre Completo',
                      hintText: 'Ej: Carlos Mendoza',
                      prefixIcon: const Icon(Icons.badge_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingrese el nombre' : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: rolCtrl,
                    decoration: InputDecoration(
                      labelText: 'Rol / Especialidad',
                      hintText: 'Ej: Mecánico, Electricista, Soldador',
                      prefixIcon: const Icon(Icons.engineering_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingrese el rol o especialidad' : null,
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF005A9C),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.check),
                      label: Text(
                        tecnicoExistente == null ? 'Registrar Técnico' : 'Guardar Cambios',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      onPressed: () async {
                        if (formKey.currentState?.validate() ?? false) {
                          Navigator.pop(ctx);
                          final nuevo = TecnicoEntity(
                            id: tecnicoExistente?.id ?? '',
                            nombre: nombreCtrl.text.trim(),
                            rol: rolCtrl.text.trim(),
                            activo: tecnicoExistente?.activo ?? true,
                            fechaRegistro: tecnicoExistente?.fechaRegistro ?? DateTime.now(),
                          );
                          await _dataSource.registrarOActualizarTecnico(nuevo);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Técnico ${nuevo.nombre} guardado correctamente'),
                                backgroundColor: const Color(0xFF2E7D32),
                              ),
                            );
                          }
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F6),
      appBar: AppBar(
        title: const Text(
          'Catálogo de Técnicos',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        backgroundColor: const Color(0xFF005A9C),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: _mostrarInactivos ? 'Ocultar Inactivos' : 'Ver Inactivos',
            icon: Icon(_mostrarInactivos ? Icons.visibility : Icons.visibility_off),
            onPressed: () => setState(() => _mostrarInactivos = !_mostrarInactivos),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF005A9C),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add),
        label: const Text('Nuevo Técnico', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: () => _abrirModalTecnico(),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            color: Colors.white,
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Buscar técnico por nombre o especialidad...',
                prefixIcon: const Icon(Icons.search, color: Color(0xFF005A9C)),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onChanged: (v) => setState(() => _filtroTexto = v.trim().toLowerCase()),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<TecnicoEntity>>(
              stream: _dataSource.escucharTecnicos(soloActivos: !_mostrarInactivos),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFF005A9C)));
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text('Error al cargar técnicos: ${snapshot.error}'),
                    ),
                  );
                }

                final todos = snapshot.data ?? [];
                final filtrados = todos.where((t) {
                  if (_filtroTexto.isEmpty) return true;
                  return t.nombre.toLowerCase().contains(_filtroTexto) ||
                      t.rol.toLowerCase().contains(_filtroTexto);
                }).toList();

                if (filtrados.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.engineering_outlined, size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        Text(
                          todos.isEmpty
                              ? 'No hay técnicos registrados todavía.'
                              : 'No se encontraron técnicos con esa búsqueda.',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 80),
                  itemCount: filtrados.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final tec = filtrados[index];
                    return Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(color: Colors.grey.shade300),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: tec.activo ? const Color(0xFFE3F2FD) : Colors.grey.shade200,
                          child: Icon(
                            Icons.person,
                            color: tec.activo ? const Color(0xFF005A9C) : Colors.grey.shade600,
                          ),
                        ),
                        title: Text(
                          tec.nombre,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            decoration: tec.activo ? TextDecoration.none : TextDecoration.lineThrough,
                          ),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.blueGrey.shade50,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.blueGrey.shade200),
                                ),
                                child: Text(
                                  tec.rol,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.blueGrey.shade800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Switch(
                              value: tec.activo,
                              activeColor: const Color(0xFF2E7D32),
                              onChanged: (val) => _dataSource.toggleActivo(tec.id, val),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit, size: 18, color: Colors.blueGrey),
                              onPressed: () => _abrirModalTecnico(tecnicoExistente: tec),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
