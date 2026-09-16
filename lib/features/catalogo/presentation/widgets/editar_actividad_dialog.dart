// lib/features/catalogo/presentation/widgets/editar_actividad_dialog.dart
import 'package:flutter/material.dart';
import '../../domain/entities/actividad_catalogo_entity.dart';
import '../../domain/entities/item_catalogo_entity.dart';

class EditarActividadDialog extends StatefulWidget {
  final ActividadCatalogoEntity? actividad;
  final String equipo;
  final Function(ActividadCatalogoEntity) onGuardar;

  const EditarActividadDialog({
    super.key,
    this.actividad,
    required this.equipo,
    required this.onGuardar,
  });

  static Future<void> mostrar(
    BuildContext context, {
    ActividadCatalogoEntity? actividad,
    required String equipo,
    required Function(ActividadCatalogoEntity) onGuardar,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => EditarActividadDialog(
        actividad: actividad,
        equipo: equipo,
        onGuardar: onGuardar,
      ),
    );
  }

  @override
  State<EditarActividadDialog> createState() => _EditarActividadDialogState();
}

class _EditarActividadDialogState extends State<EditarActividadDialog> {
  late TextEditingController _codigoController;
  late TextEditingController _nombreController;
  late TextEditingController _hhController;
  late TextEditingController _incluyeController;
  late TextEditingController _descTrabajoController;
  late bool _esVariable;

  late List<ItemCatalogoEntity> _itemsInternos;
  late List<ItemCatalogoEntity> _itemsComerciales;

  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    final a = widget.actividad;
    _codigoController = TextEditingController(text: a?.codigo ?? '');
    _nombreController = TextEditingController(text: a?.nombre ?? '');
    _hhController = TextEditingController(text: a?.horasHombre != null ? a!.horasHombre.toString() : '');
    _incluyeController = TextEditingController(text: a?.incluye ?? '');
    _descTrabajoController = TextEditingController(text: a?.descripcionTrabajo ?? '');
    _esVariable = a?.esVariable ?? (a?.horasHombre == null);

    _itemsInternos = a != null ? List.from(a.itemsInternos) : [];
    _itemsComerciales = a != null ? List.from(a.itemsComerciales) : [];
  }

  @override
  void dispose() {
    _codigoController.dispose();
    _nombreController.dispose();
    _hhController.dispose();
    _incluyeController.dispose();
    _descTrabajoController.dispose();
    super.dispose();
  }

  void _agregarItem(bool esInterno) {
    final codCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final uniCtrl = TextEditingController(text: 'UNIDAD');
    final cantCtrl = TextEditingController(text: '1.0');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(esInterno ? 'Agregar Repuesto/Insumo (Taller)' : 'Agregar Ítem Comercial (Venta)'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: codCtrl,
                decoration: const InputDecoration(labelText: 'Código (ej. HID00355)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: descCtrl,
                decoration: const InputDecoration(labelText: 'Descripción del ítem', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: uniCtrl,
                      decoration: const InputDecoration(labelText: 'Unidad (UNIDAD, HH, CM)', border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: cantCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Cantidad', border: OutlineInputBorder()),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCELAR')),
          ElevatedButton(
            onPressed: () {
              if (codCtrl.text.trim().isEmpty || descCtrl.text.trim().isEmpty) return;
              final nuevo = ItemCatalogoEntity(
                codigo: codCtrl.text.trim().toUpperCase(),
                descripcion: descCtrl.text.trim(),
                unidad: uniCtrl.text.trim().toUpperCase(),
                cantidad: double.tryParse(cantCtrl.text.trim()) ?? 1.0,
              );
              setState(() {
                if (esInterno) {
                  _itemsInternos.add(nuevo);
                } else {
                  _itemsComerciales.add(nuevo);
                }
              });
              Navigator.pop(ctx);
            },
            child: const Text('AGREGAR'),
          ),
        ],
      ),
    );
  }

  void _guardar() {
    if (!_formKey.currentState!.validate()) return;

    final codigo = _codigoController.text.trim().toUpperCase();
    final nombre = _nombreController.text.trim();
    final double? hh = _esVariable ? null : double.tryParse(_hhController.text.trim());

    final docId = widget.actividad?.id.isNotEmpty == true
        ? widget.actividad!.id
        : '${widget.equipo.toLowerCase()}_${codigo.toLowerCase()}';

    final nueva = ActividadCatalogoEntity(
      id: docId,
      codigo: codigo,
      nombre: nombre,
      equipo: widget.equipo.toLowerCase(),
      horasHombre: hh,
      esVariable: _esVariable,
      descripcionTrabajo: _descTrabajoController.text.trim().isNotEmpty
          ? _descTrabajoController.text.trim()
          : nombre,
      incluye: _incluyeController.text.trim(),
      itemsInternos: _itemsInternos,
      itemsComerciales: _itemsComerciales,
      activo: true,
    );

    widget.onGuardar(nueva);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.actividad == null ? 'Nueva Actividad (${widget.equipo.toUpperCase()})' : 'Editar Actividad ${widget.actividad!.codigo}'),
      content: SizedBox(
        width: 600,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _codigoController,
                        decoration: const InputDecoration(labelText: 'Código (ej. MO001)*', border: OutlineInputBorder()),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Requerido' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 3,
                      child: Row(
                        children: [
                          Checkbox(
                            value: _esVariable,
                            onChanged: (val) {
                              setState(() {
                                _esVariable = val ?? false;
                                if (_esVariable) _hhController.clear();
                              });
                            },
                          ),
                          const Text('HH Variable'),
                        ],
                      ),
                    ),
                    if (!_esVariable)
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: _hhController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(labelText: 'HH Fijas*', border: OutlineInputBorder()),
                          validator: (v) => !_esVariable && (v == null || double.tryParse(v) == null) ? 'Inválido' : null,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _nombreController,
                  decoration: const InputDecoration(labelText: 'Nombre de la Actividad*', border: OutlineInputBorder()),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Requerido' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _incluyeController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Detalle de "Incluye:" (Alcance para PDF y Excel)',
                    hintText: 'Incluye: 1 MOTOR CHAR-LYNN, 2 ADAPTADORES...',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Repuestos e Insumos (Internos)', style: TextStyle(fontWeight: FontWeight.bold)),
                    TextButton.icon(
                      onPressed: () => _agregarItem(true),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Agregar'),
                    ),
                  ],
                ),
                if (_itemsInternos.isEmpty)
                  const Text('No hay ítems internos configurados.', style: TextStyle(fontSize: 12, color: Colors.grey))
                else
                  ..._itemsInternos.map((it) => ListTile(
                        dense: true,
                        title: Text('${it.codigo} - ${it.descripcion}'),
                        subtitle: Text('Cantidad: ${it.cantidad} ${it.unidad}'),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red, size: 18),
                          onPressed: () => setState(() => _itemsInternos.remove(it)),
                        ),
                      )),
                const SizedBox(height: 16),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Ítems para Cotización (Comercial)', style: TextStyle(fontWeight: FontWeight.bold)),
                    TextButton.icon(
                      onPressed: () => _agregarItem(false),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Agregar'),
                    ),
                  ],
                ),
                if (_itemsComerciales.isEmpty)
                  const Text('No hay ítems comerciales configurados.', style: TextStyle(fontSize: 12, color: Colors.grey))
                else
                  ..._itemsComerciales.map((it) => ListTile(
                        dense: true,
                        title: Text('${it.codigo} - ${it.descripcion}'),
                        subtitle: Text('Cantidad: ${it.cantidad} ${it.unidad}'),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red, size: 18),
                          onPressed: () => setState(() => _itemsComerciales.remove(it)),
                        ),
                      )),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCELAR')),
        ElevatedButton(
          onPressed: _guardar,
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF005A9C), foregroundColor: Colors.white),
          child: const Text('GUARDAR ACTIVIDAD'),
        ),
      ],
    );
  }
}
