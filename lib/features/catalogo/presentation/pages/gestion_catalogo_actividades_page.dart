// lib/features/catalogo/presentation/pages/gestion_catalogo_actividades_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../../core/enum/rol_usuario.dart';
import '../../../../core/enum/segmento_operativo.dart';
import '../../domain/entities/actividad_catalogo_entity.dart';
import '../bloc/catalogo_bloc.dart';
import '../bloc/catalogo_event.dart';
import '../bloc/catalogo_state.dart';
import '../widgets/editar_actividad_dialog.dart';

class GestionCatalogoActividadesPage extends StatefulWidget {
  const GestionCatalogoActividadesPage({super.key});

  @override
  State<GestionCatalogoActividadesPage> createState() => _GestionCatalogoActividadesPageState();
}

class _GestionCatalogoActividadesPageState extends State<GestionCatalogoActividadesPage> {
  String _equipoSeleccionado = 'caracol';
  final TextEditingController _busquedaController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final authState = context.read<AuthBloc>().state;
    if (authState is Authenticated) {
      if (authState.usuario.rol == RolUsuario.supervisor &&
          authState.usuario.segmento != SegmentoOperativo.general &&
          authState.usuario.segmento != SegmentoOperativo.ninguno) {
        _equipoSeleccionado = authState.usuario.segmento.name.toLowerCase();
      }
    }
    context.read<CatalogoBloc>().add(CargarCatalogoPorEquipoEvent(_equipoSeleccionado));
  }

  @override
  void dispose() {
    _busquedaController.dispose();
    super.dispose();
  }

  void _cambiarEquipo(String nuevo) {
    if (_equipoSeleccionado == nuevo) return;
    setState(() {
      _equipoSeleccionado = nuevo;
    });
    context.read<CatalogoBloc>().add(CargarCatalogoPorEquipoEvent(nuevo));
  }

  void _abrirDialogo({ActividadCatalogoEntity? actividad}) {
    EditarActividadDialog.mostrar(
      context,
      actividad: actividad,
      equipo: _equipoSeleccionado,
      onGuardar: (nueva) {
        context.read<CatalogoBloc>().add(GuardarActividadEvent(nueva));
      },
    );
  }

  void _confirmarEliminar(ActividadCatalogoEntity act) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar Eliminación'),
        content: Text('¿Desea desactivar la actividad ${act.codigo}: ${act.nombre}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCELAR')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              context.read<CatalogoBloc>().add(EliminarActividadEvent(id: act.id, equipo: _equipoSeleccionado));
            },
            child: const Text('ELIMINAR'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    final bool isAdmin = authState is Authenticated && authState.usuario.rol == RolUsuario.admin;

    return Scaffold(
      appBar: AppBar(
        title: Text('Catálogo de Actividades (${_equipoSeleccionado.toUpperCase()})'),
        backgroundColor: const Color(0xFF005A9C),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          if (isAdmin)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.grey.shade100,
              child: Row(
                children: [
                  const Text('Equipo: ', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Caracol'),
                    selected: _equipoSeleccionado == 'caracol',
                    onSelected: (_) => _cambiarEquipo('caracol'),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Contador'),
                    selected: _equipoSeleccionado == 'contador',
                    onSelected: (_) => _cambiarEquipo('contador'),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Cosechadora'),
                    selected: _equipoSeleccionado == 'cosechadora',
                    onSelected: (_) => _cambiarEquipo('cosechadora'),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _busquedaController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Buscar por código, nombre o repuesto...',
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                suffixIcon: _busquedaController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => setState(() => _busquedaController.clear()),
                      )
                    : null,
              ),
            ),
          ),
          Expanded(
            child: BlocConsumer<CatalogoBloc, CatalogoState>(
              listener: (context, state) {
                if (state is CatalogoOperacionSuccess) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(state.mensaje), backgroundColor: Colors.green),
                  );
                } else if (state is CatalogoError) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(state.mensaje), backgroundColor: Colors.red),
                  );
                }
              },
              builder: (context, state) {
                if (state is CatalogoLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (state is CatalogoLoaded) {
                  final query = _busquedaController.text.trim().toLowerCase();
                  final filtradas = state.actividades.where((a) {
                    if (query.isEmpty) return true;
                    return a.codigo.toLowerCase().contains(query) ||
                        a.nombre.toLowerCase().contains(query) ||
                        a.incluye.toLowerCase().contains(query) ||
                        a.itemsInternos.any((it) => it.descripcion.toLowerCase().contains(query) || it.codigo.toLowerCase().contains(query));
                  }).toList();

                  if (state.actividades.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.build_circle_outlined, size: 64, color: Colors.grey),
                            const SizedBox(height: 12),
                            Text(
                              'No hay actividades registradas para ${_equipoSeleccionado.toUpperCase()}',
                              style: const TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: () => _abrirDialogo(),
                              icon: const Icon(Icons.add),
                              label: const Text('Crear Primera Actividad'),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  if (filtradas.isEmpty) {
                    return const Center(child: Text('No se encontraron actividades coincidentes.'));
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    itemCount: filtradas.length,
                    itemBuilder: (context, index) {
                      final act = filtradas[index];
                      return Card(
                        elevation: 1.5,
                        margin: const EdgeInsets.only(bottom: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        child: ExpansionTile(
                          leading: CircleAvatar(
                            backgroundColor: const Color(0xFF005A9C),
                            foregroundColor: Colors.white,
                            child: Text(
                              act.codigo.replaceAll('MO', '').padLeft(2, '0'),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ),
                          title: Text(
                            '${act.codigo} - ${act.nombre}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          subtitle: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: act.esVariable ? Colors.orange.shade100 : Colors.blue.shade100,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  act.esVariable ? 'HH Variable' : '${act.horasHombre} HH',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: act.esVariable ? Colors.orange.shade900 : Colors.blue.shade900,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${act.itemsInternos.length} repuestos taller',
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, size: 20, color: Color(0xFF005A9C)),
                                onPressed: () => _abrirDialogo(actividad: act),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                                onPressed: () => _confirmarEliminar(act),
                              ),
                            ],
                          ),
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (act.incluye.isNotEmpty) ...[
                                    const Text('Alcance formal (Incluye):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                    const SizedBox(height: 2),
                                    Text(act.incluye, style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
                                    const Divider(height: 16),
                                  ],
                                  const Text('Repuestos e Insumos de Taller:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                  const SizedBox(height: 4),
                                  if (act.itemsInternos.isEmpty)
                                    const Text('Sin despiece de taller.', style: TextStyle(fontSize: 11, color: Colors.grey))
                                  else
                                    ...act.itemsInternos.map((it) => Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 2),
                                          child: Text('• ${it.codigo} | ${it.descripcion} (${it.cantidad} ${it.unidad})', style: const TextStyle(fontSize: 12)),
                                        )),
                                  const SizedBox(height: 8),
                                  const Text('Kits y Servicios Comerciales:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                  const SizedBox(height: 4),
                                  if (act.itemsComerciales.isEmpty)
                                    const Text('Sin ítems comerciales.', style: TextStyle(fontSize: 11, color: Colors.grey))
                                  else
                                    ...act.itemsComerciales.map((it) => Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 2),
                                          child: Text('• ${it.codigo} | ${it.descripcion} (${it.cantidad} ${it.unidad})', style: const TextStyle(fontSize: 12, color: Colors.teal)),
                                        )),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                }

                return const SizedBox.shrink();
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF005A9C),
        foregroundColor: Colors.white,
        onPressed: () => _abrirDialogo(),
        icon: const Icon(Icons.add),
        label: const Text('Nueva Actividad'),
      ),
    );
  }
}
