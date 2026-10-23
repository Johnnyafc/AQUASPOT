// lib/features/catalogo/presentation/pages/revision_codigos_plan_maestro_page.dart
//
// 🔎 "Revisión de Códigos del Plan Maestro" (tarjeta del menú principal,
// admin y supervisor): compara los ítems de bodega (repuestos e insumos,
// internos y comerciales) del plan maestro de cada equipo contra el
// inventario, y permite corregirlos con "Editar" o "Buscar coincidencias y
// asignar". Cada cambio queda en `historial_plan_maestro` y el último se
// puede deshacer. Nunca toca el inventario ni los tickets ya creados.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/enum/rol_usuario.dart';
import '../../../../core/enum/segmento_operativo.dart';
import '../../../../injection_container.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../inventario/data/datasources/inventario_remote_datasource.dart';
import '../../../inventario/domain/entities/item_inventario_entity.dart';
import '../../data/datasources/catalogo_remote_datasource.dart';
import '../../domain/entities/actividad_catalogo_entity.dart';
import '../../domain/services/revision_codigos_plan_maestro_service.dart';

typedef _Svc = RevisionCodigosPlanMaestroService;

const _equiposTodos = ['caracol', 'contador', 'cosechadora'];
const _nombresEquipo = {'caracol': 'Caracol', 'contador': 'Contador', 'cosechadora': 'Cosechadora'};

String _mensajeError(Object e) {
  if (e is FirebaseException) return e.message ?? e.code;
  return e.toString().replaceFirst('Exception: ', '');
}

String _numero(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);

Color _colorEstado(EstadoCodigoPlan e) => switch (e) {
      EstadoCodigoPlan.noExiste => Colors.red.shade700,
      EstadoCodigoPlan.descripcionDistinta => Colors.orange.shade800,
      EstadoCodigoPlan.sinCodigo => Colors.blueGrey,
      EstadoCodigoPlan.coincide => Colors.green.shade700,
    };

IconData _iconoEstado(EstadoCodigoPlan e) => switch (e) {
      EstadoCodigoPlan.noExiste => Icons.cancel_outlined,
      EstadoCodigoPlan.descripcionDistinta => Icons.warning_amber_rounded,
      EstadoCodigoPlan.sinCodigo => Icons.help_outline,
      EstadoCodigoPlan.coincide => Icons.check_circle_outline,
    };

String _textoEstado(EstadoCodigoPlan e) => switch (e) {
      EstadoCodigoPlan.noExiste => 'No existen',
      EstadoCodigoPlan.descripcionDistinta => 'Descripción distinta',
      EstadoCodigoPlan.sinCodigo => 'Sin código',
      EstadoCodigoPlan.coincide => 'Coinciden',
    };

/// Lo que se va a guardar: código nuevo y, opcionalmente, descripción y
/// unidad (null = cada ítem conserva la suya), en las actividades indicadas.
class _CambioPlan {
  final String codigo;
  final String? descripcion;
  final String? unidad;
  final List<String> actividadIds;

  const _CambioPlan({required this.codigo, this.descripcion, this.unidad, required this.actividadIds});
}

class RevisionCodigosPlanMaestroPage extends StatefulWidget {
  const RevisionCodigosPlanMaestroPage({super.key});

  @override
  State<RevisionCodigosPlanMaestroPage> createState() => _RevisionCodigosPlanMaestroPageState();
}

class _RevisionCodigosPlanMaestroPageState extends State<RevisionCodigosPlanMaestroPage>
    with SingleTickerProviderStateMixin {
  final CatalogoRemoteDataSource _catalogo = sl<CatalogoRemoteDataSource>();
  final InventarioRemoteDataSource _inventarioDs = sl<InventarioRemoteDataSource>();

  late final List<String> _equipos;
  late final TabController _tabController;
  String _usuarioEmail = '';
  String _usuarioNombre = '';

  List<ItemInventarioEntity>? _inventario;
  Map<String, ItemInventarioEntity> _inventarioPorCodigo = {};
  String? _errorInventario;
  final Map<String, List<ActividadCatalogoEntity>> _actividades = {};
  final Map<String, String> _erroresEquipo = {};
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    final authState = context.read<AuthBloc>().state;
    var equipos = _equiposTodos;
    if (authState is Authenticated) {
      final u = authState.usuario;
      _usuarioEmail = u.email;
      _usuarioNombre = u.nombre;
      // El supervisor de un equipo solo ve (y corrige) su equipo.
      final propio = u.segmento.name.toLowerCase();
      if (u.rol == RolUsuario.supervisor &&
          u.segmento != SegmentoOperativo.general &&
          u.segmento != SegmentoOperativo.ninguno &&
          _equiposTodos.contains(propio)) {
        equipos = [propio];
      }
    }
    _equipos = equipos;
    _tabController = TabController(length: _equipos.length, vsync: this);
    _cargarInventario();
    for (final e in _equipos) {
      _cargarEquipo(e);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String get _equipoActual => _equipos[_tabController.index];

  Future<void> _cargarInventario() async {
    setState(() {
      _inventario = null;
      _errorInventario = null;
    });
    try {
      final items = await _inventarioDs.obtenerTodos();
      if (!mounted) return;
      setState(() {
        _inventario = items;
        _inventarioPorCodigo = {
          for (final i in items)
            if (_Svc.normalizarCodigo(i.codigo).isNotEmpty) _Svc.normalizarCodigo(i.codigo): i,
        };
      });
    } catch (e) {
      if (mounted) setState(() => _errorInventario = _mensajeError(e));
    }
  }

  Future<void> _cargarEquipo(String equipo) async {
    setState(() {
      _actividades.remove(equipo);
      _erroresEquipo.remove(equipo);
    });
    try {
      final lista = await _catalogo.obtenerActividadesPorEquipo(equipo);
      if (mounted) setState(() => _actividades[equipo] = lista);
    } catch (e) {
      if (mounted) setState(() => _erroresEquipo[equipo] = _mensajeError(e));
    }
  }

  void _recargarTodo() {
    _cargarInventario();
    for (final e in _equipos) {
      _cargarEquipo(e);
    }
  }

  void _aviso(String texto, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(texto),
      backgroundColor: error ? Colors.red.shade700 : const Color(0xFF2E7D32),
      duration: Duration(seconds: error ? 6 : 3),
    ));
  }

  /// Actividades del equipo donde el código nuevo ya está en la misma lista
  /// (interna o comercial) que el ítem que se cambia: quedaría repetido.
  List<String> _actividadesConDuplicado(String equipo, RevisionCodigoPlan fila, _CambioPlan cambio) {
    final nuevo = _Svc.normalizarCodigo(cambio.codigo);
    final anterior = _Svc.normalizarCodigo(fila.codigo);
    if (nuevo == anterior) return const [];
    final resultado = <String>[];
    for (final act in _actividades[equipo] ?? const <ActividadCatalogoEntity>[]) {
      if (!cambio.actividadIds.contains(act.id)) continue;
      for (final lista in [act.itemsInternos, act.itemsComerciales]) {
        final tieneAnterior = fila.usos.any((u) => u.actividadId == act.id && lista.contains(u.item));
        final tieneNuevo = lista.any((i) => _Svc.normalizarCodigo(i.codigo) == nuevo);
        if (tieneAnterior && tieneNuevo) {
          resultado.add(act.codigo);
          break;
        }
      }
    }
    return resultado;
  }

  Future<void> _confirmarYGuardar(String equipo, RevisionCodigoPlan fila, _CambioPlan cambio, String tipo) async {
    final duplicados = _actividadesConDuplicado(equipo, fila, cambio);
    final codigosAct = fila.usos
        .where((u) => cambio.actividadIds.contains(u.actividadId))
        .map((u) => u.actividadCodigo)
        .toSet()
        .join(', ');
    final anterior = fila.codigo.isEmpty ? '(sin código) ${fila.descripcionPlan}' : fila.codigo;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar cambio'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$anterior → ${cambio.codigo}', style: const TextStyle(fontWeight: FontWeight.bold)),
              if (cambio.descripcion != null) Text('Descripción: ${cambio.descripcion}'),
              if (cambio.unidad != null) Text('Unidad: ${cambio.unidad}'),
              const SizedBox(height: 8),
              Text('En ${cambio.actividadIds.length} actividad(es) de ${_nombresEquipo[equipo]}: $codigosAct'),
              if (duplicados.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade300),
                  ),
                  child: Text(
                    '⚠️ ${cambio.codigo} ya existe en: ${duplicados.join(', ')}. '
                    'Si continúa, quedará repetido en esa(s) actividad(es).',
                    style: TextStyle(color: Colors.orange.shade900),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Guardar')),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _guardando = true);
    try {
      final n = await _catalogo.reemplazarItemPlanMaestro(
        equipo: equipo,
        actividadIds: cambio.actividadIds,
        codigoAnterior: fila.codigo,
        descripcionAnterior: fila.descripcionPlan,
        codigoNuevo: cambio.codigo,
        descripcionNueva: cambio.descripcion,
        unidadNueva: cambio.unidad,
        tipo: tipo,
        usuarioEmail: _usuarioEmail,
        usuarioNombre: _usuarioNombre,
      );
      if (!mounted) return;
      _aviso(n > 0
          ? 'Cambio guardado en $n actividad(es).'
          : 'No había nada que cambiar (puede que ya lo hayan corregido).');
      await _cargarEquipo(equipo);
    } catch (e) {
      if (mounted) _aviso('No se pudo guardar: ${_mensajeError(e)}', error: true);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _editar(String equipo, RevisionCodigoPlan fila) async {
    final cambio = await showDialog<_CambioPlan>(
      context: context,
      builder: (_) => _EditarItemDialog(fila: fila, inventarioPorCodigo: _inventarioPorCodigo),
    );
    if (cambio != null && mounted) await _confirmarYGuardar(equipo, fila, cambio, 'editar');
  }

  Future<void> _asignar(String equipo, RevisionCodigoPlan fila) async {
    final cambio = await showDialog<_CambioPlan>(
      context: context,
      builder: (_) => _AsignarCoincidenciaDialog(
        fila: fila,
        inventario: _inventario ?? const [],
        nombreEquipo: _nombresEquipo[equipo] ?? equipo,
      ),
    );
    if (cambio != null && mounted) await _confirmarYGuardar(equipo, fila, cambio, 'asignar');
  }

  Future<void> _deshacerUltimo() async {
    final equipo = _equipoActual;
    final nombre = _nombresEquipo[equipo];
    setState(() => _guardando = true);
    Map<String, dynamic>? ultimo;
    try {
      ultimo = await _catalogo.obtenerUltimoCambioPlanMaestro(equipo);
    } catch (e) {
      if (mounted) _aviso('No se pudo consultar el historial: ${_mensajeError(e)}', error: true);
      if (mounted) setState(() => _guardando = false);
      return;
    }
    if (!mounted) return;
    setState(() => _guardando = false);
    if (ultimo == null) {
      _aviso('No hay cambios para deshacer en $nombre.');
      return;
    }
    final cambio = ultimo;
    final fecha = cambio['fecha'] is Timestamp ? (cambio['fecha'] as Timestamp).toDate() : null;
    final fechaTexto = fecha == null
        ? ''
        : ' el ${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year} '
            '${fecha.hour.toString().padLeft(2, '0')}:${fecha.minute.toString().padLeft(2, '0')}';
    final anterior = (cambio['codigoAnterior'] as String? ?? '').isEmpty
        ? '(sin código) ${cambio['descripcionAnterior'] ?? ''}'
        : cambio['codigoAnterior'];
    final actividades = (cambio['actividadCodigos'] as List? ?? const []).join(', ');

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Deshacer último cambio ($nombre)'),
        content: Text(
          '$anterior → ${cambio['codigoNuevo']}\n'
          'Actividades: $actividades\n'
          'Hecho por ${cambio['usuarioNombre'] ?? cambio['usuarioEmail'] ?? ''}$fechaTexto\n\n'
          'Las actividades vuelven a como estaban antes de ese cambio.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Deshacer')),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _guardando = true);
    try {
      await _catalogo.deshacerCambioPlanMaestro(historialId: cambio['id'] as String, usuarioEmail: _usuarioEmail);
      if (!mounted) return;
      _aviso('Cambio deshecho.');
      await _cargarEquipo(equipo);
    } catch (e) {
      if (mounted) _aviso('No se pudo deshacer: ${_mensajeError(e)}', error: true);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Widget _vistaEquipo(String equipo) {
    if (_errorInventario != null) {
      return _MensajeCentro(
        icono: Icons.error_outline,
        texto: 'No se pudo leer el inventario:\n$_errorInventario',
        onReintentar: _cargarInventario,
      );
    }
    final error = _erroresEquipo[equipo];
    if (error != null) {
      return _MensajeCentro(
        icono: Icons.error_outline,
        texto: 'No se pudo leer el plan maestro:\n$error',
        onReintentar: () => _cargarEquipo(equipo),
      );
    }
    final actividades = _actividades[equipo];
    final inventario = _inventario;
    if (actividades == null || inventario == null) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF005A9C)));
    }
    if (actividades.isEmpty) {
      return const _MensajeCentro(
        icono: Icons.menu_book_outlined,
        texto: 'Sin plan maestro cargado para este equipo.',
      );
    }
    return _VistaEquipo(
      key: PageStorageKey('revision_$equipo'),
      actividades: actividades,
      inventario: inventario,
      habilitado: !_guardando,
      onEditar: (f) => _editar(equipo, f),
      onAsignar: (f) => _asignar(equipo, f),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        title: const Text('Revisión de Códigos del Plan Maestro'),
        backgroundColor: const Color(0xFF005A9C),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.undo),
            tooltip: 'Deshacer último cambio',
            onPressed: _guardando ? null : _deshacerUltimo,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Recargar',
            onPressed: _guardando ? null : _recargarTodo,
          ),
        ],
        bottom: _equipos.length > 1
            ? TabBar(
                controller: _tabController,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                indicatorColor: Colors.white,
                tabs: [for (final e in _equipos) Tab(text: _nombresEquipo[e])],
              )
            : null,
      ),
      body: Column(
        children: [
          if (_guardando) const LinearProgressIndicator(minHeight: 3),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [for (final e in _equipos) _vistaEquipo(e)],
            ),
          ),
        ],
      ),
    );
  }
}

class _MensajeCentro extends StatelessWidget {
  final IconData icono;
  final String texto;
  final VoidCallback? onReintentar;

  const _MensajeCentro({required this.icono, required this.texto, this.onReintentar});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, size: 60, color: Colors.grey.shade500),
            const SizedBox(height: 12),
            Text(texto, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade700, fontSize: 15)),
            if (onReintentar != null) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: onReintentar,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Contenido de una pestaña: resumen, filtros y lista de códigos del equipo.
class _VistaEquipo extends StatefulWidget {
  final List<ActividadCatalogoEntity> actividades;
  final List<ItemInventarioEntity> inventario;
  final bool habilitado;
  final ValueChanged<RevisionCodigoPlan> onEditar;
  final ValueChanged<RevisionCodigoPlan> onAsignar;

  const _VistaEquipo({
    super.key,
    required this.actividades,
    required this.inventario,
    required this.habilitado,
    required this.onEditar,
    required this.onAsignar,
  });

  @override
  State<_VistaEquipo> createState() => _VistaEquipoState();
}

class _VistaEquipoState extends State<_VistaEquipo> with AutomaticKeepAliveClientMixin {
  EstadoCodigoPlan? _filtro;
  String _busqueda = '';

  // Cálculo en memoria: solo se rehace cuando cambian los datos.
  List<ActividadCatalogoEntity>? _actCalculadas;
  List<ItemInventarioEntity>? _invCalculado;
  late ResultadoRevisionPlan _resultado;

  @override
  bool get wantKeepAlive => true;

  ResultadoRevisionPlan get _revision {
    if (!identical(widget.actividades, _actCalculadas) || !identical(widget.inventario, _invCalculado)) {
      _actCalculadas = widget.actividades;
      _invCalculado = widget.inventario;
      _resultado = _Svc.revisar(actividades: widget.actividades, inventario: widget.inventario);
    }
    return _resultado;
  }

  void _verExcluidos(ResultadoRevisionPlan r) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        builder: (ctx, scroll) => Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Excluidos (servicios / mano de obra)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            Expanded(
              child: r.excluidos.isEmpty
                  ? const Center(child: Text('No hay ítems excluidos.'))
                  : ListView.builder(
                      controller: scroll,
                      itemCount: r.excluidos.length,
                      itemBuilder: (_, i) {
                        final u = r.excluidos[i];
                        return ListTile(
                          dense: true,
                          title: Text('${u.item.codigo.isEmpty ? '(sin código)' : u.item.codigo} · ${u.item.descripcion}'),
                          subtitle: Text('${u.actividadCodigo} · ${u.esComercial ? 'comercial' : 'interno'}'),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final r = _revision;
    final q = _Svc.normalizarTexto(_busqueda);
    final filas = r.filas.where((f) {
      if (_filtro != null && f.estado != _filtro) return false;
      if (q.isEmpty) return true;
      final texto = _Svc.normalizarTexto(
          '${f.codigo} ${f.descripcionesPlan.join(' ')} ${f.inventario?.descripcion ?? ''} '
          '${f.usos.map((u) => u.actividadCodigo).join(' ')}');
      return texto.contains(q);
    }).toList();

    Widget chipEstado(EstadoCodigoPlan e) {
      final color = _colorEstado(e);
      return FilterChip(
        selected: _filtro == e,
        avatar: Icon(_iconoEstado(e), size: 18, color: color),
        label: Text('${_textoEstado(e)}: ${r.contar(e)}'),
        selectedColor: color.withValues(alpha: 0.15),
        onSelected: (sel) => setState(() => _filtro = sel ? e : null),
      );
    }

    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  FilterChip(
                    selected: _filtro == null,
                    label: Text('Total: ${r.filas.length}'),
                    onSelected: (_) => setState(() => _filtro = null),
                  ),
                  for (final e in EstadoCodigoPlan.values) chipEstado(e),
                  ActionChip(
                    avatar: const Icon(Icons.block, size: 18),
                    label: Text('Excluidos: ${r.excluidos.length}'),
                    tooltip: 'Servicios y mano de obra (no se buscan en bodega)',
                    onPressed: () => _verExcluidos(r),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                decoration: InputDecoration(
                  hintText: 'Buscar por código, descripción o actividad...',
                  prefixIcon: const Icon(Icons.search, color: Color(0xFF005A9C)),
                  filled: true,
                  fillColor: const Color(0xFFF0F4F8),
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                ),
                onChanged: (v) => setState(() => _busqueda = v),
              ),
            ],
          ),
        ),
        Expanded(
          child: filas.isEmpty
              ? const Center(child: Text('No hay códigos con este filtro.'))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                  itemCount: filas.length,
                  itemBuilder: (_, i) => _FilaRevision(
                    fila: filas[i],
                    habilitado: widget.habilitado,
                    onEditar: () => widget.onEditar(filas[i]),
                    onAsignar: () => widget.onAsignar(filas[i]),
                  ),
                ),
        ),
      ],
    );
  }
}

class _FilaRevision extends StatelessWidget {
  final RevisionCodigoPlan fila;
  final bool habilitado;
  final VoidCallback onEditar;
  final VoidCallback onAsignar;

  const _FilaRevision({required this.fila, required this.habilitado, required this.onEditar, required this.onAsignar});

  @override
  Widget build(BuildContext context) {
    final color = _colorEstado(fila.estado);
    final inv = fila.inventario;
    final usos = <String>{
      for (final u in fila.usos) '${u.actividadCodigo} (${u.esComercial ? 'comercial' : 'interno'})',
    }.join(', ');
    final puedeAsignar =
        fila.estado == EstadoCodigoPlan.noExiste || fila.estado == EstadoCodigoPlan.descripcionDistinta;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withValues(alpha: 0.4)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_iconoEstado(fila.estado), color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    fila.codigo.isEmpty ? '(sin código)' : fila.codigo,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                Text(
                  '${fila.numActividades} actividad(es)',
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text('Plan: ${fila.descripcionPlan}  ·  ${fila.unidadPlan}'),
            if (fila.descripcionesInconsistentes)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '⚠️ Descripciones distintas en el plan: ${fila.descripcionesPlan.join(' / ')}',
                  style: TextStyle(color: Colors.orange.shade900, fontSize: 13),
                ),
              ),
            const SizedBox(height: 4),
            if (inv != null)
              Text(
                'Inventario: ${inv.descripcion}  ·  Stock neto: ${_numero(inv.stockNetoDisponible)} ${inv.unidad}',
                style: TextStyle(color: color, fontWeight: FontWeight.w500),
              )
            else if (fila.estado == EstadoCodigoPlan.noExiste)
              Text('No existe en inventario', style: TextStyle(color: color, fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            Text('Usado en: $usos', style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: habilitado ? onEditar : null,
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text('Editar'),
                ),
                if (puedeAsignar)
                  TextButton.icon(
                    onPressed: habilitado ? onAsignar : null,
                    icon: const Icon(Icons.manage_search, size: 18),
                    label: const Text('Buscar coincidencias y asignar'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// ✏️ Editar código, descripción y unidad, eligiendo las actividades.
class _EditarItemDialog extends StatefulWidget {
  final RevisionCodigoPlan fila;
  final Map<String, ItemInventarioEntity> inventarioPorCodigo;

  const _EditarItemDialog({required this.fila, required this.inventarioPorCodigo});

  @override
  State<_EditarItemDialog> createState() => _EditarItemDialogState();
}

class _EditarItemDialogState extends State<_EditarItemDialog> {
  late final TextEditingController _codigo = TextEditingController(text: widget.fila.codigo);
  late final TextEditingController _descripcion = TextEditingController(text: widget.fila.descripcionPlan);
  late final TextEditingController _unidad = TextEditingController(text: widget.fila.unidadPlan);
  late final Map<String, String> _actividades = {
    for (final u in widget.fila.usos) u.actividadId: '${u.actividadCodigo} · ${u.actividadNombre}',
  };
  late final Set<String> _seleccionadas = _actividades.keys.toSet();

  @override
  void dispose() {
    _codigo.dispose();
    _descripcion.dispose();
    _unidad.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cod = _Svc.normalizarCodigo(_codigo.text);
    final enInventario = widget.inventarioPorCodigo[cod];
    final valido = cod.isNotEmpty && _descripcion.text.trim().isNotEmpty && _seleccionadas.isNotEmpty;

    return AlertDialog(
      title: const Text('Editar ítem del plan maestro'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _codigo,
                decoration: const InputDecoration(labelText: 'Código'),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 6),
              if (cod.isNotEmpty)
                Text(
                  enInventario != null
                      ? '✅ Existe en inventario: ${enInventario.descripcion} (${enInventario.unidad})'
                      : '⚠️ No existe en inventario',
                  style: TextStyle(
                    color: enInventario != null ? Colors.green.shade700 : Colors.orange.shade900,
                    fontSize: 13,
                  ),
                ),
              if (enInventario != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () => setState(() {
                      _descripcion.text = enInventario.descripcion;
                      _unidad.text = enInventario.unidad;
                    }),
                    child: const Text('Usar descripción y unidad del inventario'),
                  ),
                ),
              TextField(
                controller: _descripcion,
                decoration: const InputDecoration(labelText: 'Descripción'),
                onChanged: (_) => setState(() {}),
              ),
              TextField(
                controller: _unidad,
                decoration: const InputDecoration(labelText: 'Unidad'),
              ),
              const SizedBox(height: 16),
              const Text('Aplicar en las actividades:', style: TextStyle(fontWeight: FontWeight.bold)),
              for (final e in _actividades.entries)
                CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  value: _seleccionadas.contains(e.key),
                  title: Text(e.value),
                  onChanged: (v) => setState(() => v == true ? _seleccionadas.add(e.key) : _seleccionadas.remove(e.key)),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        ElevatedButton(
          onPressed: valido
              ? () => Navigator.pop(
                    context,
                    _CambioPlan(
                      codigo: _codigo.text.trim(),
                      descripcion: _descripcion.text.trim(),
                      unidad: _unidad.text.trim(),
                      actividadIds: _seleccionadas.toList(),
                    ),
                  )
              : null,
          child: const Text('Continuar'),
        ),
      ],
    );
  }
}

/// 🔍 Sugerencias del inventario más parecidas + buscador libre.
class _AsignarCoincidenciaDialog extends StatefulWidget {
  final RevisionCodigoPlan fila;
  final List<ItemInventarioEntity> inventario;
  final String nombreEquipo;

  const _AsignarCoincidenciaDialog({required this.fila, required this.inventario, required this.nombreEquipo});

  @override
  State<_AsignarCoincidenciaDialog> createState() => _AsignarCoincidenciaDialogState();
}

class _AsignarCoincidenciaDialogState extends State<_AsignarCoincidenciaDialog> {
  late final List<SugerenciaCodigo> _sugerencias = _Svc.sugerir(
    codigoPlan: widget.fila.codigo,
    descripcionPlan: widget.fila.descripcionPlan,
    inventario: widget.inventario,
  );
  String _busqueda = '';
  ItemInventarioEntity? _elegido;
  bool _copiarDescripcion = true;

  List<SugerenciaCodigo> get _opciones {
    final q = _Svc.normalizarTexto(_busqueda);
    if (q.isEmpty) return _sugerencias;
    final propio = _Svc.normalizarCodigo(widget.fila.codigo);
    final lista = <SugerenciaCodigo>[];
    for (final item in widget.inventario) {
      final cod = _Svc.normalizarCodigo(item.codigo);
      if (cod.isEmpty || cod == propio) continue;
      if (!_Svc.normalizarTexto('${item.codigo} ${item.descripcion}').contains(q)) continue;
      lista.add(SugerenciaCodigo(
        item: item,
        puntaje: _Svc.puntaje(
          codigoPlan: widget.fila.codigo,
          descripcionPlan: widget.fila.descripcionPlan,
          item: item,
        ),
      ));
    }
    lista.sort((a, b) => b.puntaje.compareTo(a.puntaje));
    return lista.take(20).toList();
  }

  @override
  Widget build(BuildContext context) {
    final opciones = _opciones;
    final fila = widget.fila;

    return AlertDialog(
      title: const Text('Buscar coincidencias y asignar'),
      content: SizedBox(
        width: 560,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Plan: ${fila.codigo.isEmpty ? '(sin código)' : fila.codigo} · ${fila.descripcionPlan}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              'Se cambiará en ${fila.numActividades} actividad(es) de ${widget.nombreEquipo}.',
              style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              decoration: const InputDecoration(
                hintText: 'Buscar otro repuesto del inventario...',
                prefixIcon: Icon(Icons.search),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _busqueda = v),
            ),
            const SizedBox(height: 8),
            Text(
              _busqueda.trim().isEmpty ? 'Más parecidos:' : 'Resultados de la búsqueda:',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            Flexible(
              child: opciones.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('Sin coincidencias. Use el buscador.'),
                    )
                  : ListView(
                      shrinkWrap: true,
                      children: [
                        for (final s in opciones)
                          RadioListTile<ItemInventarioEntity>(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            value: s.item,
                            // ignore: deprecated_member_use
                            groupValue: _elegido,
                            // ignore: deprecated_member_use
                            onChanged: (v) => setState(() => _elegido = v),
                            title: Text('${s.item.codigo} · ${s.item.descripcion}'),
                            subtitle: Text(
                              '${(s.puntaje * 100).round()} % · ${s.item.unidad} · '
                              'Stock neto: ${_numero(s.item.stockNetoDisponible)}',
                            ),
                          ),
                      ],
                    ),
            ),
            CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              value: _copiarDescripcion,
              title: const Text('Copiar también descripción y unidad del inventario'),
              onChanged: (v) => setState(() => _copiarDescripcion = v ?? true),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        ElevatedButton(
          onPressed: _elegido == null
              ? null
              : () {
                  final e = _elegido!;
                  Navigator.pop(
                    context,
                    _CambioPlan(
                      codigo: e.codigo.trim(),
                      descripcion: _copiarDescripcion ? e.descripcion : null,
                      unidad: _copiarDescripcion ? e.unidad : null,
                      actividadIds: fila.actividadIds,
                    ),
                  );
                },
          child: const Text('Asignar'),
        ),
      ],
    );
  }
}
