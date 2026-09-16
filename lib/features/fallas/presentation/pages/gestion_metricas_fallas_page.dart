// lib/features/fallas/presentation/pages/gestion_metricas_fallas_page.dart

import 'package:flutter/material.dart';
import '../../domain/entities/metrica_falla_entity.dart';
import '../../data/datasources/metrica_falla_remote_datasource.dart';

class GestionMetricasFallasPage extends StatefulWidget {
  const GestionMetricasFallasPage({super.key});

  @override
  State<GestionMetricasFallasPage> createState() => _GestionMetricasFallasPageState();
}

class _GestionMetricasFallasPageState extends State<GestionMetricasFallasPage>
    with SingleTickerProviderStateMixin {
  final MetricaFallaRemoteDataSource _dataSource = MetricaFallaRemoteDataSource();
  late TabController _tabController;

  final List<String> _equipos = ['Contador', 'Caracol', 'Cosechadora'];
  String _filtroTexto = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _equipos.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // =========================================================================
  // 1. CATEGORÍA: CREAR Y EDITAR (Nivel 1)
  // =========================================================================
  void _abrirModalNuevaCategoria(String tipoEquipo) {
    final catCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.create_new_folder_outlined, color: Color(0xFF005A9C)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Nueva Categoría ($tipoEquipo)',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: catCtrl,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Nombre de la Categoría',
                hintText: 'Ej: Eléctrico, Mecánico, Hidráulico...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Ingrese el nombre de la categoría' : null,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF005A9C),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final cat = catCtrl.text.trim();
                  final messenger = ScaffoldMessenger.of(context);
                  Navigator.pop(ctx);
                  try {
                    await _dataSource.agregarCategoria(
                      tipoEquipo: tipoEquipo,
                      nombreCategoria: cat,
                    );
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text('Categoría "$cat" creada con éxito'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } catch (e) {
                    messenger.showSnackBar(
                      SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );
  }

  void _abrirModalEditarCategoria(String tipoEquipo, String nombreActual) {
    final catCtrl = TextEditingController(text: nombreActual);
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.edit, color: Color(0xFF005A9C)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Editar Nombre de Categoría',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: catCtrl,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Nombre de la Categoría',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Ingrese el nuevo nombre' : null,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF005A9C),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final nuevoNombre = catCtrl.text.trim();
                  final messenger = ScaffoldMessenger.of(context);
                  Navigator.pop(ctx);
                  try {
                    await _dataSource.editarCategoria(
                      tipoEquipo: tipoEquipo,
                      nombreActual: nombreActual,
                      nuevoNombre: nuevoNombre,
                    );
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text('Categoría actualizada a "$nuevoNombre"'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } catch (e) {
                    messenger.showSnackBar(
                      SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              child: const Text('Actualizar'),
            ),
          ],
        );
      },
    );
  }

  // =========================================================================
  // 2. SUBCATEGORÍA / COMPONENTE: CREAR Y EDITAR (Nivel 2)
  // =========================================================================
  void _abrirModalNuevaSubcategoria(String tipoEquipo, String nombreCategoria) {
    final subCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.account_tree_outlined, color: Color(0xFF005A9C)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Nuevo Componente en "$nombreCategoria"',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: subCtrl,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Nombre del Componente o Módulo',
                hintText: 'Ej: Comap, Relé, Cableado...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Ingrese el nombre del componente' : null,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF005A9C),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final sub = subCtrl.text.trim();
                  final messenger = ScaffoldMessenger.of(context);
                  Navigator.pop(ctx);
                  try {
                    await _dataSource.agregarSubcategoria(
                      tipoEquipo: tipoEquipo,
                      nombreCategoria: nombreCategoria,
                      nombreSubcategoria: sub,
                    );
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text('Componente "$sub" agregado con éxito'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } catch (e) {
                    messenger.showSnackBar(
                      SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );
  }

  void _abrirModalEditarSubcategoria({
    required String tipoEquipo,
    required String nombreCategoria,
    required String nombreActual,
  }) {
    final subCtrl = TextEditingController(text: nombreActual);
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.edit, color: Color(0xFF003057)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Editar Nombre de Componente',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: subCtrl,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Nombre del Componente',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Ingrese el nuevo nombre' : null,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF003057),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final nuevoNombre = subCtrl.text.trim();
                  final messenger = ScaffoldMessenger.of(context);
                  Navigator.pop(ctx);
                  try {
                    await _dataSource.editarSubcategoria(
                      tipoEquipo: tipoEquipo,
                      nombreCategoria: nombreCategoria,
                      nombreActual: nombreActual,
                      nuevoNombre: nuevoNombre,
                    );
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text('Componente actualizado a "$nuevoNombre"'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } catch (e) {
                    messenger.showSnackBar(
                      SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              child: const Text('Actualizar'),
            ),
          ],
        );
      },
    );
  }

  // =========================================================================
  // 3. FALLA ESPECÍFICA: CREAR Y EDITAR (Nivel 3)
  // =========================================================================
  /// Abre el modal directo para agregar una falla dentro de un componente ya seleccionado
  void _abrirModalNuevaFallaDirecta({
    required String tipoEquipo,
    required String nombreCategoria,
    required String nombreSubcategoria,
  }) {
    final fallaCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.add_task, color: Colors.deepOrange),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Nueva Falla Específica', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    Text(
                      '$nombreCategoria > $nombreSubcategoria',
                      style: const TextStyle(fontSize: 12, color: Colors.blueGrey),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: fallaCtrl,
              maxLines: 2,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Descripción de la Falla',
                hintText: 'Ej: Falla en tarjeta electrónica, Fallo en borneras...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Ingrese la descripción de la falla' : null,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.check, size: 18),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepOrange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final falla = fallaCtrl.text.trim();
                  final messenger = ScaffoldMessenger.of(context);
                  Navigator.pop(ctx);
                  try {
                    await _dataSource.agregarFalla(
                      tipoEquipo: tipoEquipo,
                      nombreCategoria: nombreCategoria,
                      nombreSubcategoria: nombreSubcategoria,
                      nuevaFalla: falla,
                    );
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text('Falla "$falla" agregada con éxito'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } catch (e) {
                    messenger.showSnackBar(
                      SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              label: const Text('Agregar Falla'),
            ),
          ],
        );
      },
    );
  }

  void _abrirModalEditarFalla({
    required String tipoEquipo,
    required String nombreCategoria,
    required String nombreSubcategoria,
    required String fallaActual,
  }) {
    final fallaCtrl = TextEditingController(text: fallaActual);
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.edit, color: Colors.deepOrange),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Editar Falla', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    Text(
                      '$nombreCategoria > $nombreSubcategoria',
                      style: const TextStyle(fontSize: 12, color: Colors.blueGrey),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: fallaCtrl,
              maxLines: 2,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Descripción de la Falla',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Ingrese la nueva descripción' : null,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepOrange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final nuevaFalla = fallaCtrl.text.trim();
                  final messenger = ScaffoldMessenger.of(context);
                  Navigator.pop(ctx);
                  try {
                    await _dataSource.editarFalla(
                      tipoEquipo: tipoEquipo,
                      nombreCategoria: nombreCategoria,
                      nombreSubcategoria: nombreSubcategoria,
                      fallaActual: fallaActual,
                      nuevaFalla: nuevaFalla,
                    );
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text('Falla actualizada a "$nuevaFalla"'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } catch (e) {
                    messenger.showSnackBar(
                      SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              child: const Text('Actualizar'),
            ),
          ],
        );
      },
    );
  }

  /// Modal general flexible para agregar falla:
  /// Permite seleccionar o escribir Categoría, Componente y Falla sin trabas ni bloqueos.
  void _abrirModalNuevaFallaGeneral({
    required String tipoEquipo,
    required List<CategoriaFallaEntity> categoriasDisponibles,
    String? preselectedCategoria,
    String? preselectedSubcategoria,
  }) {
    bool esNuevaCategoria = categoriasDisponibles.isEmpty ||
        (preselectedCategoria != null &&
            !categoriasDisponibles.any((c) => c.nombre == preselectedCategoria));
    
    String? categoriaSeleccionada = preselectedCategoria ??
        (categoriasDisponibles.isNotEmpty ? categoriasDisponibles.first.nombre : null);

    final catTextoCtrl = TextEditingController(text: esNuevaCategoria ? (preselectedCategoria ?? '') : '');

    // Hallar componentes iniciales de la categoría seleccionada
    List<SubcategoriaFallaEntity> subsActuales() {
      if (esNuevaCategoria || categoriaSeleccionada == null) return [];
      final found = categoriasDisponibles.where((c) => c.nombre == categoriaSeleccionada);
      return found.isNotEmpty ? found.first.subcategorias : [];
    }

    bool esNuevoComponente = subsActuales().isEmpty;
    String? subcategoriaSeleccionada = preselectedSubcategoria;
    if (subcategoriaSeleccionada == null && subsActuales().isNotEmpty) {
      subcategoriaSeleccionada = subsActuales().first.nombre;
    }

    final subTextoCtrl = TextEditingController(text: preselectedSubcategoria ?? '');
    final fallaCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final listaSubs = subsActuales();

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  const Icon(Icons.add_task, color: Colors.deepOrange),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Nueva Falla ($tipoEquipo)',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. SELECCIÓN O ESCRITURA DE CATEGORÍA
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            '1. Categoría',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF003057)),
                          ),
                          if (categoriasDisponibles.isNotEmpty)
                            TextButton(
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                visualDensity: VisualDensity.compact,
                              ),
                              onPressed: () {
                                setModalState(() {
                                  esNuevaCategoria = !esNuevaCategoria;
                                  if (!esNuevaCategoria && categoriaSeleccionada == null) {
                                    categoriaSeleccionada = categoriasDisponibles.first.nombre;
                                  }
                                  esNuevoComponente = subsActuales().isEmpty;
                                });
                              },
                              child: Text(
                                esNuevaCategoria ? 'Elegir existente' : '+ Crear nueva',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      if (!esNuevaCategoria && categoriasDisponibles.isNotEmpty)
                        DropdownButtonFormField<String>(
                          key: ValueKey('cat_dropdown_$categoriaSeleccionada'),
                          initialValue: categoriaSeleccionada,
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          items: categoriasDisponibles.map((c) {
                            return DropdownMenuItem<String>(
                              value: c.nombre,
                              child: Text(c.nombre),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setModalState(() {
                                categoriaSeleccionada = val;
                                final nuevasSubs = subsActuales();
                                if (nuevasSubs.isNotEmpty) {
                                  subcategoriaSeleccionada = nuevasSubs.first.nombre;
                                  esNuevoComponente = false;
                                } else {
                                  subcategoriaSeleccionada = null;
                                  esNuevoComponente = true;
                                }
                              });
                            }
                          },
                        )
                      else
                        TextFormField(
                          controller: catTextoCtrl,
                          decoration: InputDecoration(
                            hintText: 'Ej: Eléctrico, Mecánico, Hidráulico...',
                            labelText: 'Nombre de la Categoría',
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          validator: (v) =>
                              (esNuevaCategoria && (v == null || v.trim().isEmpty))
                                  ? 'Ingrese la categoría'
                                  : null,
                        ),
                      const SizedBox(height: 16),

                      // 2. SELECCIÓN O ESCRITURA DE COMPONENTE / SUBCATEGORÍA
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            '2. Componente / Módulo',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF003057)),
                          ),
                          if (listaSubs.isNotEmpty)
                            TextButton(
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                visualDensity: VisualDensity.compact,
                              ),
                              onPressed: () {
                                setModalState(() {
                                  esNuevoComponente = !esNuevoComponente;
                                  if (!esNuevoComponente && subcategoriaSeleccionada == null) {
                                    subcategoriaSeleccionada = listaSubs.first.nombre;
                                  }
                                });
                              },
                              child: Text(
                                esNuevoComponente ? 'Elegir existente' : '+ Crear nuevo',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      if (!esNuevoComponente && listaSubs.isNotEmpty)
                        DropdownButtonFormField<String>(
                          key: ValueKey('sub_dropdown_${categoriaSeleccionada}_$subcategoriaSeleccionada'),
                          initialValue: subcategoriaSeleccionada,
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          items: listaSubs.map((s) {
                            return DropdownMenuItem<String>(
                              value: s.nombre,
                              child: Text(s.nombre),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setModalState(() {
                                subcategoriaSeleccionada = val;
                              });
                            }
                          },
                        )
                      else
                        TextFormField(
                          controller: subTextoCtrl,
                          decoration: InputDecoration(
                            hintText: 'Ej: Comap, Motor, Relé, Sensor...',
                            labelText: 'Nombre del Componente',
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          validator: (v) =>
                              ((esNuevoComponente || listaSubs.isEmpty) && (v == null || v.trim().isEmpty))
                                  ? 'Ingrese el nombre del componente'
                                  : null,
                        ),
                      const SizedBox(height: 16),

                      // 3. DESCRIPCIÓN DE LA FALLA
                      const Text(
                        '3. Descripción de la Falla',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF003057)),
                      ),
                      const SizedBox(height: 4),
                      TextFormField(
                        controller: fallaCtrl,
                        maxLines: 2,
                        decoration: InputDecoration(
                          hintText: 'Ej: Falla en tarjeta electrónica, Fallo en borneras...',
                          labelText: 'Detalle de la Falla',
                          contentPadding: const EdgeInsets.all(12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Ingrese la descripción de la falla' : null,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.check, size: 18),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepOrange,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;

                    final catFinal = esNuevaCategoria
                        ? catTextoCtrl.text.trim()
                        : (categoriaSeleccionada ?? '').trim();
                    final subFinal = (esNuevoComponente || listaSubs.isEmpty)
                        ? subTextoCtrl.text.trim()
                        : (subcategoriaSeleccionada ?? '').trim();
                    final fallaFinal = fallaCtrl.text.trim();

                    if (catFinal.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Debe indicar una categoría válida.'), backgroundColor: Colors.orange),
                      );
                      return;
                    }
                    if (subFinal.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Debe indicar un componente válido.'), backgroundColor: Colors.orange),
                      );
                      return;
                    }
                    if (fallaFinal.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Debe ingresar la descripción de la falla.'), backgroundColor: Colors.orange),
                      );
                      return;
                    }

                    final messenger = ScaffoldMessenger.of(context);
                    Navigator.pop(ctx);
                    try {
                      await _dataSource.agregarFalla(
                        tipoEquipo: tipoEquipo,
                        nombreCategoria: catFinal,
                        nombreSubcategoria: subFinal,
                        nuevaFalla: fallaFinal,
                      );
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text('Falla agregada a "$catFinal > $subFinal"'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    } catch (e) {
                      messenger.showSnackBar(
                        SnackBar(content: Text('Error al guardar: $e'), backgroundColor: Colors.red),
                      );
                    }
                  },
                  label: const Text('Guardar Falla'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // =========================================================================
  // MODALES DE CONFIRMACIÓN DE ELIMINACIÓN
  // =========================================================================
  void _confirmarEliminarCategoria({
    required String tipoEquipo,
    required String nombreCategoria,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Eliminar Categoría', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text(
          '¿Desea eliminar la categoría completa "$nombreCategoria" y todos sus componentes y fallas asociadas?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              Navigator.pop(ctx);
              try {
                await _dataSource.eliminarCategoria(
                  tipoEquipo: tipoEquipo,
                  nombreCategoria: nombreCategoria,
                );
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Categoría eliminada correctamente'),
                    backgroundColor: Colors.orange,
                  ),
                );
              } catch (e) {
                messenger.showSnackBar(
                  SnackBar(content: Text('Error al eliminar: $e'), backgroundColor: Colors.red),
                );
              }
            },
            child: const Text('Eliminar Todo'),
          ),
        ],
      ),
    );
  }

  void _confirmarEliminarSubcategoria({
    required String tipoEquipo,
    required String nombreCategoria,
    required String nombreSubcategoria,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Eliminar Componente', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text(
          '¿Desea eliminar el componente "$nombreSubcategoria" y todas sus fallas de "$nombreCategoria"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              Navigator.pop(ctx);
              try {
                await _dataSource.eliminarSubcategoria(
                  tipoEquipo: tipoEquipo,
                  nombreCategoria: nombreCategoria,
                  nombreSubcategoria: nombreSubcategoria,
                );
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Componente eliminado correctamente'),
                    backgroundColor: Colors.orange,
                  ),
                );
              } catch (e) {
                messenger.showSnackBar(
                  SnackBar(content: Text('Error al eliminar: $e'), backgroundColor: Colors.red),
                );
              }
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  void _confirmarEliminarFalla({
    required String tipoEquipo,
    required String nombreCategoria,
    required String nombreSubcategoria,
    required String falla,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Eliminar Falla', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('¿Desea eliminar la falla "$falla" del componente "$nombreSubcategoria"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              Navigator.pop(ctx);
              try {
                await _dataSource.eliminarFalla(
                  tipoEquipo: tipoEquipo,
                  nombreCategoria: nombreCategoria,
                  nombreSubcategoria: nombreSubcategoria,
                  fallaAEliminar: falla,
                );
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Falla eliminada correctamente'),
                    backgroundColor: Colors.orange,
                  ),
                );
              } catch (e) {
                messenger.showSnackBar(
                  SnackBar(content: Text('Error al eliminar: $e'), backgroundColor: Colors.red),
                );
              }
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  IconData _iconoCategoria(String nombre) {
    final lower = nombre.toLowerCase();
    if (lower.contains('mecán') || lower.contains('mecan')) return Icons.build;
    if (lower.contains('electr') || lower.contains('placa') || lower.contains('cable') || lower.contains('comap')) {
      return Icons.electrical_services;
    }
    if (lower.contains('soft') || lower.contains('licenc') || lower.contains('cámar')) return Icons.code;
    if (lower.contains('hidrául') || lower.contains('hidraul')) return Icons.water_drop;
    if (lower.contains('estruct')) return Icons.architecture;
    return Icons.settings_suggest;
  }

  Color _colorCategoria(String nombre) {
    final lower = nombre.toLowerCase();
    if (lower.contains('mecán') || lower.contains('mecan')) return Colors.blueGrey;
    if (lower.contains('electr')) return Colors.indigo;
    if (lower.contains('soft')) return Colors.deepPurple;
    if (lower.contains('hidrául') || lower.contains('hidraul')) return Colors.blue;
    if (lower.contains('estruct')) return Colors.brown;
    return const Color(0xFF005A9C);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F6),
      appBar: AppBar(
        title: const Text(
          'Métricas y Causas de Fallas',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF003057),
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.amber,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          tabs: _equipos.map((e) => Tab(text: e.toUpperCase())).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _equipos.map((tipo) => _buildEquipoTab(tipo)).toList(),
      ),
    );
  }

  Widget _buildEquipoTab(String tipoEquipo) {
    return StreamBuilder<MatrizFallasEquipoEntity>(
      stream: _dataSource.escucharMatrizEquipo(tipoEquipo),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final matriz = snapshot.data!;
        final categorias = matriz.categorias;

        return Column(
          children: [
            // Barra superior de búsqueda y acciones con botones explícitos
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      onChanged: (val) => setState(() => _filtroTexto = val.trim().toLowerCase()),
                      decoration: InputDecoration(
                        hintText: 'Buscar categoría, componente o falla...',
                        prefixIcon: const Icon(Icons.search, color: Colors.blueGrey),
                        filled: true,
                        fillColor: const Color(0xFFF4F6F9),
                        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Botón explícito: + Nueva Categoría
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF003057),
                      side: const BorderSide(color: Color(0xFF003057)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    icon: const Icon(Icons.create_new_folder_outlined, size: 18),
                    label: const Text('Nueva Categoría', style: TextStyle(fontWeight: FontWeight.w600)),
                    onPressed: () => _abrirModalNuevaCategoria(tipoEquipo),
                  ),
                  const SizedBox(width: 8),
                  // Botón explícito: + Nueva Falla
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepOrange,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                    icon: const Icon(Icons.add_task, size: 18),
                    label: const Text('Nueva Falla', style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: () => _abrirModalNuevaFallaGeneral(
                      tipoEquipo: tipoEquipo,
                      categoriasDisponibles: categorias,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Lista jerárquica de 3 niveles
            Expanded(
              child: categorias.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.rule_folder_outlined, size: 64, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          Text(
                            'No hay categorías definidas para $tipoEquipo',
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                          ),
                          const SizedBox(height: 14),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.add),
                            label: const Text('Crear Primera Categoría'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF005A9C),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                            ),
                            onPressed: () => _abrirModalNuevaCategoria(tipoEquipo),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: categorias.length,
                      itemBuilder: (context, catIdx) {
                        final cat = categorias[catIdx];
                        final colorCat = _colorCategoria(cat.nombre);

                        // Filtrado para búsqueda
                        final subcategoriasFiltradas = cat.subcategorias.where((sub) {
                          if (_filtroTexto.isEmpty) return true;
                          if (cat.nombre.toLowerCase().contains(_filtroTexto)) return true;
                          if (sub.nombre.toLowerCase().contains(_filtroTexto)) return true;
                          return sub.fallas.any((f) => f.toLowerCase().contains(_filtroTexto));
                        }).toList();

                        if (_filtroTexto.isNotEmpty &&
                            subcategoriasFiltradas.isEmpty &&
                            !cat.nombre.toLowerCase().contains(_filtroTexto)) {
                          return const SizedBox.shrink();
                        }

                        final totalFallasCat =
                            cat.subcategorias.fold<int>(0, (sum, s) => sum + s.fallas.length);

                        return Card(
                          margin: const EdgeInsets.only(bottom: 16),
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: Colors.grey.shade200),
                          ),
                          child: Theme(
                            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                            child: ExpansionTile(
                              initiallyExpanded: true,
                              leading: CircleAvatar(
                                backgroundColor: colorCat.withValues(alpha: 0.12),
                                child: Icon(_iconoCategoria(cat.nombre), color: colorCat, size: 20),
                              ),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      cat.nombre,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: Color(0xFF0D2438),
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: colorCat.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '$totalFallasCat fallas',
                                      style: TextStyle(
                                        color: colorCat,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Botón 1: Añadir Falla a esta categoría
                                  IconButton(
                                    icon: const Icon(Icons.add_task, size: 20, color: Colors.deepOrange),
                                    tooltip: 'Añadir Falla a "${cat.nombre}"',
                                    onPressed: () => _abrirModalNuevaFallaGeneral(
                                      tipoEquipo: tipoEquipo,
                                      categoriasDisponibles: categorias,
                                      preselectedCategoria: cat.nombre,
                                    ),
                                  ),
                                  // Botón 2: Editar Categoría (Nivel 1)
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined, size: 20, color: Color(0xFF005A9C)),
                                    tooltip: 'Editar Nombre de Categoría',
                                    onPressed: () => _abrirModalEditarCategoria(tipoEquipo, cat.nombre),
                                  ),
                                  // Botón 3: Añadir Componente (Nivel 2)
                                  IconButton(
                                    icon: const Icon(Icons.playlist_add, size: 22, color: Color(0xFF005A9C)),
                                    tooltip: 'Añadir Componente a ${cat.nombre}',
                                    onPressed: () => _abrirModalNuevaSubcategoria(
                                      tipoEquipo,
                                      cat.nombre,
                                    ),
                                  ),
                                  // Botón 4: Eliminar Categoría
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
                                    tooltip: 'Eliminar Categoría',
                                    onPressed: () => _confirmarEliminarCategoria(
                                      tipoEquipo: tipoEquipo,
                                      nombreCategoria: cat.nombre,
                                    ),
                                  ),
                                ],
                              ),
                              children: [
                                const Divider(height: 1),
                                if (cat.subcategorias.isEmpty)
                                  Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Column(
                                      children: [
                                        Text(
                                          'Sin componentes registrados en "${cat.nombre}".',
                                          style: TextStyle(color: Colors.grey.shade500, fontStyle: FontStyle.italic),
                                        ),
                                        const SizedBox(height: 10),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            ElevatedButton.icon(
                                              icon: const Icon(Icons.playlist_add),
                                              label: Text('Añadir Componente a ${cat.nombre} (ej: Comap)'),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: const Color(0xFF005A9C),
                                                foregroundColor: Colors.white,
                                              ),
                                              onPressed: () => _abrirModalNuevaSubcategoria(
                                                tipoEquipo,
                                                cat.nombre,
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            OutlinedButton.icon(
                                              icon: const Icon(Icons.add_task, color: Colors.deepOrange),
                                              label: const Text('Añadir Falla Directa', style: TextStyle(color: Colors.deepOrange)),
                                              style: OutlinedButton.styleFrom(
                                                side: const BorderSide(color: Colors.deepOrange),
                                              ),
                                              onPressed: () => _abrirModalNuevaFallaGeneral(
                                                tipoEquipo: tipoEquipo,
                                                categoriasDisponibles: categorias,
                                                preselectedCategoria: cat.nombre,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  )
                                else
                                  Padding(
                                    padding: const EdgeInsets.all(12.0),
                                    child: Column(
                                      children: (subcategoriasFiltradas.isNotEmpty
                                              ? subcategoriasFiltradas
                                              : cat.subcategorias)
                                          .map((sub) {
                                        return Container(
                                          margin: const EdgeInsets.only(bottom: 12),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF9FBFC),
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(color: Colors.blueGrey.shade100),
                                          ),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              // Encabezado del Componente / Subcategoría
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                decoration: BoxDecoration(
                                                  color: Colors.blueGrey.shade50,
                                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(9)),
                                                ),
                                                child: Row(
                                                  children: [
                                                    const Icon(Icons.device_hub, size: 16, color: Color(0xFF003057)),
                                                    const SizedBox(width: 8),
                                                    Expanded(
                                                      child: Text(
                                                        sub.nombre,
                                                        style: const TextStyle(
                                                          fontWeight: FontWeight.bold,
                                                          fontSize: 14,
                                                          color: Color(0xFF003057),
                                                        ),
                                                      ),
                                                    ),
                                                    Text(
                                                      '${sub.fallas.length} fallas',
                                                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                                    ),
                                                    const SizedBox(width: 10),
                                                    // Botón directo para Añadir Falla en este componente
                                                    ElevatedButton.icon(
                                                      style: ElevatedButton.styleFrom(
                                                        backgroundColor: Colors.deepOrange,
                                                        foregroundColor: Colors.white,
                                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                        minimumSize: const Size(0, 30),
                                                        elevation: 0,
                                                        shape: RoundedRectangleBorder(
                                                          borderRadius: BorderRadius.circular(6),
                                                        ),
                                                      ),
                                                      icon: const Icon(Icons.add, size: 15),
                                                      label: const Text(
                                                        'Añadir Falla',
                                                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                                      ),
                                                      onPressed: () => _abrirModalNuevaFallaDirecta(
                                                        tipoEquipo: tipoEquipo,
                                                        nombreCategoria: cat.nombre,
                                                        nombreSubcategoria: sub.nombre,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 6),
                                                    // Botón Editar Componente (Nivel 2)
                                                    IconButton(
                                                      icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF003057)),
                                                      tooltip: 'Editar Componente',
                                                      constraints: const BoxConstraints(),
                                                      padding: const EdgeInsets.all(4),
                                                      onPressed: () => _abrirModalEditarSubcategoria(
                                                        tipoEquipo: tipoEquipo,
                                                        nombreCategoria: cat.nombre,
                                                        nombreActual: sub.nombre,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 4),
                                                    // Botón Eliminar Componente
                                                    IconButton(
                                                      icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                                                      tooltip: 'Eliminar Componente',
                                                      constraints: const BoxConstraints(),
                                                      padding: const EdgeInsets.all(4),
                                                      onPressed: () => _confirmarEliminarSubcategoria(
                                                        tipoEquipo: tipoEquipo,
                                                        nombreCategoria: cat.nombre,
                                                        nombreSubcategoria: sub.nombre,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),

                                              // Lista de Fallas de la Subcategoría
                                              if (sub.fallas.isEmpty)
                                                Padding(
                                                  padding: const EdgeInsets.all(12.0),
                                                  child: Row(
                                                    children: [
                                                      Text(
                                                        'Sin fallas registradas en este componente.',
                                                        style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontStyle: FontStyle.italic),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      TextButton.icon(
                                                        icon: const Icon(Icons.add, size: 14),
                                                        label: const Text('Añadir la primera falla'),
                                                        onPressed: () => _abrirModalNuevaFallaDirecta(
                                                          tipoEquipo: tipoEquipo,
                                                          nombreCategoria: cat.nombre,
                                                          nombreSubcategoria: sub.nombre,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                )
                                              else
                                                Padding(
                                                  padding: const EdgeInsets.all(10.0),
                                                  child: Wrap(
                                                    spacing: 8,
                                                    runSpacing: 8,
                                                    children: sub.fallas.map((falla) {
                                                      return Container(
                                                        padding: const EdgeInsets.only(left: 10, right: 6, top: 4, bottom: 4),
                                                        decoration: BoxDecoration(
                                                          color: Colors.white,
                                                          borderRadius: BorderRadius.circular(8),
                                                          border: Border.all(color: Colors.deepOrange.shade200),
                                                          boxShadow: [
                                                            BoxShadow(
                                                              color: Colors.black.withValues(alpha: 0.02),
                                                              blurRadius: 2,
                                                              offset: const Offset(0, 1),
                                                            ),
                                                          ],
                                                        ),
                                                        child: Row(
                                                          mainAxisSize: MainAxisSize.min,
                                                          children: [
                                                            const Icon(Icons.error_outline, size: 14, color: Colors.deepOrange),
                                                            const SizedBox(width: 6),
                                                            Flexible(
                                                              child: Text(
                                                                falla,
                                                                style: const TextStyle(
                                                                  fontSize: 12,
                                                                  fontWeight: FontWeight.w500,
                                                                ),
                                                              ),
                                                            ),
                                                            const SizedBox(width: 6),
                                                            // Botón Editar Falla (Nivel 3)
                                                            InkWell(
                                                              borderRadius: BorderRadius.circular(12),
                                                              onTap: () => _abrirModalEditarFalla(
                                                                tipoEquipo: tipoEquipo,
                                                                nombreCategoria: cat.nombre,
                                                                nombreSubcategoria: sub.nombre,
                                                                fallaActual: falla,
                                                              ),
                                                              child: const Padding(
                                                                padding: EdgeInsets.all(3.0),
                                                                child: Icon(Icons.edit_outlined, size: 15, color: Colors.blueGrey),
                                                              ),
                                                            ),
                                                            const SizedBox(width: 4),
                                                            // Botón Eliminar Falla
                                                            InkWell(
                                                              borderRadius: BorderRadius.circular(12),
                                                              onTap: () => _confirmarEliminarFalla(
                                                                tipoEquipo: tipoEquipo,
                                                                nombreCategoria: cat.nombre,
                                                                nombreSubcategoria: sub.nombre,
                                                                falla: falla,
                                                              ),
                                                              child: const Padding(
                                                                padding: EdgeInsets.all(3.0),
                                                                child: Icon(Icons.close, size: 15, color: Colors.redAccent),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      );
                                                    }).toList(),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}
