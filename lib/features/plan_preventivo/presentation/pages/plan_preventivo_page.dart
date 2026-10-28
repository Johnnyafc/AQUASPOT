// lib/features/plan_preventivo/presentation/pages/plan_preventivo_page.dart
//
// 🗓️ PLAN PREVENTIVO (menú → "Plan Preventivo", supervisor y admin): por
// máquina, las actividades preventivas con su frecuencia (horas, km o días),
// horas hombre y repuestos del inventario. Agregar, editar y desactivar.
// Solo dibuja: el estado está en PlanPreventivoCubit y las reglas en
// PlanPreventivoService.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/enum/rol_usuario.dart';
import '../../../../injection_container.dart' as di;
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../inventario/domain/entities/item_inventario_entity.dart';
import '../../../tickets/domain/entities/mantenimiento_interno_entity.dart';
import '../../domain/entities/actividad_preventiva_entity.dart';
import '../../domain/services/plan_preventivo_service.dart';
import '../bloc/plan_preventivo_cubit.dart';

typedef _P = PlanPreventivoService;

const _verde = Color(0xFF2E7D32);

IconData iconoMaquina(TipoActivoMantenimiento t) => switch (t) {
      TipoActivoMantenimiento.cosechadora => Icons.agriculture,
      TipoActivoMantenimiento.contador => Icons.calculate_outlined,
      TipoActivoMantenimiento.caracol => Icons.water_outlined,
      TipoActivoMantenimiento.vehiculo => Icons.local_shipping_outlined,
      TipoActivoMantenimiento.aireAcondicionado => Icons.ac_unit,
      TipoActivoMantenimiento.herramientas => Icons.handyman_outlined,
    };

String _numero(double v) => v % 1 == 0 ? v.toInt().toString() : v.toString();

({String nombre, RolUsuario rol}) _usuario(BuildContext context) {
  final auth = context.read<AuthBloc>().state;
  if (auth is Authenticated) return (nombre: auth.usuario.nombre, rol: auth.usuario.rol);
  return (nombre: 'SISTEMA', rol: RolUsuario.desconocido);
}

class PlanPreventivoPage extends StatelessWidget {
  const PlanPreventivoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => di.sl<PlanPreventivoCubit>()..iniciar(),
      child: const _Vista(),
    );
  }
}

class _Vista extends StatelessWidget {
  const _Vista();

  Future<void> _abrirEditor(BuildContext context, ActividadPreventivaEntity a) {
    final cubit = context.read<PlanPreventivoCubit>();
    return Navigator.of(context).push(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => BlocProvider.value(value: cubit, child: _EditorActividad(inicial: a)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final puede = _P.puedeAdministrar(_usuario(context).rol);
    return BlocConsumer<PlanPreventivoCubit, PlanPreventivoState>(
      listenWhen: (a, b) => a.mensaje != b.mensaje && b.mensaje.isNotEmpty,
      listener: (context, s) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.mensaje), backgroundColor: s.mensajeEsError ? Colors.red : _verde),
      ),
      builder: (context, s) {
        final cubit = context.read<PlanPreventivoCubit>();
        final unidad = _P.unidadDe(s.tipo);
        final visibles = s.visibles;
        return Scaffold(
          backgroundColor: const Color(0xFFF4F7F6),
          appBar: AppBar(
            title: const Text('Plan Preventivo'),
            backgroundColor: _verde,
            foregroundColor: Colors.white,
          ),
          floatingActionButton: puede
              ? FloatingActionButton.extended(
                  backgroundColor: _verde,
                  foregroundColor: Colors.white,
                  icon: const Icon(Icons.add),
                  label: const Text('Agregar actividad'),
                  onPressed: s.carga == CargaPlanPreventivo.lista ? () => _abrirEditor(context, cubit.nueva()) : null,
                )
              : null,
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                children: [
                  const Text('Máquina', style: TextStyle(fontWeight: FontWeight.bold, color: _verde)),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final t in TipoActivoMantenimiento.values)
                      ChoiceChip(
                        avatar: Icon(iconoMaquina(t), size: 18),
                        label: Text(t.etiqueta),
                        selected: s.tipo == t,
                        onSelected: (_) => cubit.elegirMaquina(t),
                      ),
                  ]),
                  const SizedBox(height: 10),
                  Text('Frecuencia de ${s.tipo.etiqueta.toLowerCase()}: ${unidad.etiqueta.toLowerCase()}.',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                  const SizedBox(height: 12),
                  TextField(
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      hintText: 'Buscar por código o nombre',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                    onChanged: cubit.buscar,
                  ),
                  const SizedBox(height: 12),
                  if (s.carga == CargaPlanPreventivo.cargando)
                    const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()))
                  else if (s.carga == CargaPlanPreventivo.error)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(children: [
                        Text(s.mensaje, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
                        TextButton(
                          onPressed: () => cubit.elegirMaquina(s.tipo, forzar: true),
                          child: const Text('Reintentar'),
                        ),
                      ]),
                    )
                  else if (visibles.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(children: [
                        Icon(Icons.event_note_outlined, size: 48, color: Colors.grey.shade400),
                        const SizedBox(height: 8),
                        Text(
                          s.busqueda.trim().isEmpty
                              ? '${s.tipo.etiqueta} aún no tiene actividades preventivas.'
                              : 'Sin resultados para "${s.busqueda.trim()}".',
                          style: const TextStyle(color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                      ]),
                    )
                  else
                    for (final a in visibles)
                      _TarjetaActividad(
                        actividad: a,
                        onTap: puede ? () => _abrirEditor(context, a) : null,
                      ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TarjetaActividad extends StatelessWidget {
  final ActividadPreventivaEntity actividad;
  final VoidCallback? onTap;

  const _TarjetaActividad({required this.actividad, this.onTap});

  @override
  Widget build(BuildContext context) {
    final a = actividad;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: Colors.grey.shade300)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: _verde.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
              child: Text(a.codigo, style: const TextStyle(fontWeight: FontWeight.bold, color: _verde, fontSize: 12)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(a.nombre, style: const TextStyle(fontWeight: FontWeight.bold)),
                if (a.descripcion.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(a.descripcion, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                  ),
                const SizedBox(height: 8),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  _Dato(icono: Icons.repeat, texto: _P.textoFrecuencia(a), color: Colors.indigo),
                  _Dato(icono: Icons.timer_outlined, texto: '${_numero(a.horasHombre)} HH', color: Colors.blueGrey),
                  _Dato(icono: Icons.inventory_2_outlined, texto: '${a.repuestos.length} repuesto(s)', color: Colors.brown),
                ]),
              ]),
            ),
            if (onTap != null) const Icon(Icons.edit_outlined, size: 18, color: Colors.grey),
          ]),
        ),
      ),
    );
  }
}

class _Dato extends StatelessWidget {
  final IconData icono;
  final String texto;
  final Color color;

  const _Dato({required this.icono, required this.texto, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icono, size: 14, color: color),
        const SizedBox(width: 4),
        Text(texto, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

// ============================================================ Editor
class _EditorActividad extends StatefulWidget {
  final ActividadPreventivaEntity inicial;

  const _EditorActividad({required this.inicial});

  @override
  State<_EditorActividad> createState() => _EditorActividadState();
}

class _EditorActividadState extends State<_EditorActividad> {
  late ActividadPreventivaEntity _a = widget.inicial;
  late final _nombre = TextEditingController(text: widget.inicial.nombre);
  late final _descripcion = TextEditingController(text: widget.inicial.descripcion);
  late final _horas = TextEditingController(text: widget.inicial.horasHombre > 0 ? _numero(widget.inicial.horasHombre) : '');
  late final _frecuencia =
      TextEditingController(text: widget.inicial.frecuencia > 0 ? _numero(widget.inicial.frecuencia) : '');
  List<String> _errores = const [];

  bool get _esNueva => widget.inicial.id.isEmpty;

  @override
  void dispose() {
    for (final c in [_nombre, _descripcion, _horas, _frecuencia]) {
      c.dispose();
    }
    super.dispose();
  }

  double _num(String t) => double.tryParse(t.trim().replaceAll(',', '.')) ?? 0;

  ActividadPreventivaEntity get _actual => _a.copyWith(
        nombre: _nombre.text,
        descripcion: _descripcion.text,
        horasHombre: _num(_horas.text),
        frecuencia: _num(_frecuencia.text),
      );

  Future<void> _guardar() async {
    final a = _actual;
    final errores = _P.validar(a);
    setState(() => _errores = errores);
    if (errores.isNotEmpty) return;
    final u = _usuario(context);
    final ok = await context.read<PlanPreventivoCubit>().guardar(a, usuarioNombre: u.nombre, rol: u.rol);
    if (ok && mounted) Navigator.of(context).pop();
  }

  Future<void> _desactivar() async {
    final cubit = context.read<PlanPreventivoCubit>();
    final si = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('¿Desactivar ${_a.codigo}?'),
        content: const Text('Ya no se ofrecerá en la evaluación. No se borra: el código no se vuelve a usar.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Desactivar'),
          ),
        ],
      ),
    );
    if (si != true || !mounted) return;
    final u = _usuario(context);
    final ok = await cubit.desactivar(_a, usuarioNombre: u.nombre, rol: u.rol);
    if (ok && mounted) Navigator.of(context).pop();
  }

  Future<void> _agregarRepuesto(List<ItemInventarioEntity> inventario) async {
    var texto = '';
    final item = await showDialog<ItemInventarioEntity>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          final palabras = _P.normalizar(texto).split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
          final resultados = palabras.isEmpty
              ? const <ItemInventarioEntity>[]
              : inventario
                  .where((it) => palabras.every(_P.normalizar('${it.codigo} ${it.descripcion}').contains))
                  .take(30)
                  .toList();
          return AlertDialog(
            title: const Text('Agregar repuesto del inventario'),
            content: SizedBox(
              width: 560,
              height: 460,
              child: Column(children: [
                TextField(
                  autofocus: true,
                  decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Código o descripción'),
                  onChanged: (v) => setState(() => texto = v),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: palabras.isEmpty
                      ? const Center(child: Text('Escriba para buscar en lo registrado en bodega.', style: TextStyle(color: Colors.grey)))
                      : resultados.isEmpty
                          ? const Center(child: Text('Sin resultados.', style: TextStyle(color: Colors.grey)))
                          : ListView.builder(
                              itemCount: resultados.length,
                              itemBuilder: (context, i) {
                                final it = resultados[i];
                                return ListTile(
                                  dense: true,
                                  title: Text(it.descripcion),
                                  subtitle: Text('${it.codigo} · ${it.unidad}'),
                                  onTap: () => Navigator.of(context).pop(it),
                                );
                              },
                            ),
                ),
              ]),
            ),
            actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar'))],
          );
        },
      ),
    );
    if (item != null) setState(() => _a = _P.agregarRepuesto(_a, item));
  }

  Future<void> _editarCantidad(int j) async {
    final r = _a.repuestos[j];
    final ctrl = TextEditingController(text: _numero(r.cantidad));
    final valor = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(r.descripcion, style: const TextStyle(fontSize: 15)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
          decoration: InputDecoration(labelText: 'Cantidad', suffixText: r.unidad),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(double.tryParse(ctrl.text.trim().replaceAll(',', '.'))),
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (valor != null) setState(() => _a = _P.cambiarCantidad(_a, j, valor));
  }

  @override
  Widget build(BuildContext context) {
    final unidad = _P.unidadDe(_a.tipoActivo);
    final numeros = [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))];
    return BlocBuilder<PlanPreventivoCubit, PlanPreventivoState>(
      builder: (context, s) => Scaffold(
        appBar: AppBar(
          title: Text('${_esNueva ? 'Nueva actividad' : 'Editar'} ${_a.codigo} · ${_a.tipoActivo.etiqueta}'),
          backgroundColor: _verde,
          foregroundColor: Colors.white,
          actions: [
            if (!_esNueva)
              IconButton(
                tooltip: 'Desactivar',
                icon: const Icon(Icons.delete_outline),
                onPressed: s.guardando ? null : _desactivar,
              ),
          ],
        ),
        body: AbsorbPointer(
          absorbing: s.guardando,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  TextField(
                    controller: _nombre,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(labelText: 'Nombre de la actividad *', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _descripcion,
                    maxLines: 2,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(labelText: 'Descripción (opcional)', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                      child: TextField(
                        controller: _horas,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: numeros,
                        decoration: const InputDecoration(
                            labelText: 'Horas hombre *', suffixText: 'HH', border: OutlineInputBorder()),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _frecuencia,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: numeros,
                        decoration: InputDecoration(
                          labelText: 'Cada cuánto *',
                          prefixText: 'cada ',
                          suffixText: unidad.sufijo,
                          helperText: unidad.etiqueta,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ]),
                  const Divider(height: 32),
                  Row(children: [
                    Text('Repuestos (${_a.repuestos.length})',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: _verde)),
                    const Spacer(),
                    TextButton.icon(
                      icon: const Icon(Icons.add_circle_outline, size: 18),
                      label: const Text('Agregar del inventario'),
                      onPressed: () => _agregarRepuesto(s.inventario),
                    ),
                  ]),
                  if (_a.repuestos.isEmpty)
                    const Text('Sin repuestos.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  for (var j = 0; j < _a.repuestos.length; j++)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(children: [
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(_a.repuestos[j].descripcion, style: const TextStyle(fontSize: 13)),
                            Text('${_a.repuestos[j].codigo} · ${_a.repuestos[j].unidad}',
                                style: const TextStyle(fontSize: 11, color: Colors.grey)),
                          ]),
                        ),
                        IconButton(
                          tooltip: 'Restar 1',
                          icon: const Icon(Icons.remove_circle_outline, size: 20),
                          onPressed: _a.repuestos[j].cantidad > 1
                              ? () => setState(() => _a = _P.cambiarCantidad(_a, j, _a.repuestos[j].cantidad - 1))
                              : null,
                        ),
                        InkWell(
                          onTap: () => _editarCantidad(j),
                          child: Container(
                            constraints: const BoxConstraints(minWidth: 48),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade400), borderRadius: BorderRadius.circular(4)),
                            child: Text(_numero(_a.repuestos[j].cantidad),
                                textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Sumar 1',
                          icon: const Icon(Icons.add_circle_outline, size: 20),
                          onPressed: () => setState(() => _a = _P.cambiarCantidad(_a, j, _a.repuestos[j].cantidad + 1)),
                        ),
                        IconButton(
                          tooltip: 'Quitar repuesto',
                          icon: const Icon(Icons.close, size: 20, color: Colors.red),
                          onPressed: () => setState(() => _a = _P.quitarRepuesto(_a, j)),
                        ),
                      ]),
                    ),
                  if (_errores.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Text(_errores.map((e) => '• $e').join('\n'), style: TextStyle(color: Colors.red.shade800)),
                    ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 50,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: _verde, foregroundColor: Colors.white),
                      icon: s.guardando
                          ? const SizedBox(
                              width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.save),
                      label: Text(_esNueva ? 'GUARDAR ACTIVIDAD' : 'GUARDAR CAMBIOS'),
                      onPressed: _guardar,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
