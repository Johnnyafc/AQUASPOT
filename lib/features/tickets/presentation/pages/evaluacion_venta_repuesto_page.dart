// lib/features/tickets/presentation/pages/evaluacion_venta_repuesto_page.dart
//
// 🔧 Evaluación de Venta de Repuesto (supervisor), estado recepcionFisica.
// Muestra los datos de contacto, los repuestos ya definidos (solo lectura) y
// una tarjeta por cada repuesto "por determinar" con su evidencia. En cada
// una, "¿Enviar cotización?":
//   - No → buscador del inventario: la línea queda como repuesto del sistema.
//   - Sí → se sube la cotización del proveedor: la línea queda "No existe en
//          el sistema" (Compras la gestiona; Comercial ve la cotización).
// "Finalizar evaluación" recalcula el stock y enruta con
// RuteoVentaRepuestoService (todas con stock → Comercial; si no → Compras).

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/ticket_visual_theme.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../inventario/domain/entities/item_inventario_entity.dart';
import '../../../inventario/presentation/bloc/inventario_bloc.dart';
import '../../../inventario/presentation/bloc/inventario_state.dart';
import '../../domain/entities/ficha_creacion_repuesto_entity.dart';
import '../../domain/entities/linea_repuesto_venta_entity.dart';
import '../../domain/entities/ticket_entity.dart';
import '../../domain/services/evaluacion_venta_repuesto_service.dart';
import '../../domain/services/ruteo_venta_repuesto_service.dart';
import '../bloc/ticket_bloc.dart';
import '../bloc/ticket_event.dart';
import '../bloc/ticket_state.dart';
import '../widgets/copy_icon_button_widget.dart';

/// Lo que el supervisor va definiendo para una línea por determinar.
class _Definicion {
  bool? enviaCotizacion; // null = sin responder
  // No (inventario)
  ItemInventarioEntity? item;
  // Sí (proveedor): ficha de creación de código (plantilla de Costos)
  final TextEditingController codigoController = TextEditingController();
  final List<PlatformFile> cotizaciones = [];
  final Map<String, TextEditingController> ficha = {
    for (final k in _camposFichaTexto.keys) k: TextEditingController(text: _camposFichaTexto[k]!.$2),
  };
  bool comprado = true, vendido = true, activo = false, almacenado = true, gravaIva = true, fabricado = false;
  // Ambos
  final TextEditingController cantidadController = TextEditingController();

  double? get cantidad => double.tryParse(cantidadController.text.trim().replaceAll(',', '.'));

  FichaCreacionRepuestoEntity get fichaCreacion => FichaCreacionRepuestoEntity(
        nombre: ficha['nombre']!.text.trim(),
        familiaPieza: ficha['familiaPieza']!.text.trim(),
        tipo: ficha['tipo']!.text.trim(),
        atributoAcabado: ficha['atributoAcabado']!.text.trim(),
        metrica: ficha['metrica']!.text.trim(),
        equivalencia: ficha['equivalencia']!.text.trim(),
        categoria: ficha['categoria']!.text.trim(),
        udm: ficha['udm']!.text.trim(),
        tipoProducto: ficha['tipoProducto']!.text.trim(),
        linkImagen: ficha['linkImagen']!.text.trim(),
        linkDescripcion: ficha['linkDescripcion']!.text.trim(),
        comprado: comprado,
        vendido: vendido,
        activo: activo,
        almacenado: almacenado,
        gravaIva: gravaIva,
        fabricado: fabricado,
      );

  bool get resuelta {
    final c = cantidad;
    if (enviaCotizacion == null || c == null || c <= 0) return false;
    if (enviaCotizacion == false) return item != null;
    return fichaCreacion.completa && cotizaciones.isNotEmpty;
  }

  void dispose() {
    codigoController.dispose();
    cantidadController.dispose();
    for (final c in ficha.values) {
      c.dispose();
    }
  }
}

/// Campos de texto de la ficha: clave → (etiqueta, valor inicial).
/// Obligatorios (*): nombre, familia, categoría y UDM.
const Map<String, (String, String)> _camposFichaTexto = {
  'nombre': ('Nombre *', ''),
  'familiaPieza': ('Familia de pieza *', ''),
  'tipo': ('Tipo', ''),
  'atributoAcabado': ('Atributo o acab.', ''),
  'metrica': ('Métrica', ''),
  'equivalencia': ('Equivalencia', ''),
  'categoria': ('Categoría *', ''),
  'udm': ('UDM *', 'UNIDAD'),
  'tipoProducto': ('Tipo producto', 'ARTÍCULO'),
  'linkImagen': ('Link imagen', ''),
  'linkDescripcion': ('Link descripción', ''),
};

class EvaluacionVentaRepuestoPage extends StatefulWidget {
  final TicketEntity ticket;

  const EvaluacionVentaRepuestoPage({super.key, required this.ticket});

  @override
  State<EvaluacionVentaRepuestoPage> createState() => _EvaluacionVentaRepuestoPageState();
}

class _EvaluacionVentaRepuestoPageState extends State<EvaluacionVentaRepuestoPage> {
  // Una definición por cada línea por determinar (clave = índice de la línea).
  final Map<int, _Definicion> _definiciones = {};
  bool _enviando = false;

  @override
  void initState() {
    super.initState();
    final lineas = widget.ticket.lineasRepuestoVenta;
    for (int i = 0; i < lineas.length; i++) {
      if (!lineas[i].porDeterminar) continue;
      final d = _Definicion();
      d.cantidadController.text = _fmt(lineas[i].cantidad);
      _definiciones[i] = d;
    }
  }

  @override
  void dispose() {
    for (final d in _definiciones.values) {
      d.dispose();
    }
    super.dispose();
  }

  String _fmt(double v) => v % 1 == 0 ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

  bool get _todoResuelto => _definiciones.values.every((d) => d.resuelta);

  Future<void> _abrir(String url) async {
    final uri = Uri.parse(url);
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) throw Exception();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir el archivo.'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _adjuntarCotizacion(_Definicion d) async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'xlsx', 'xls'],
      allowMultiple: true,
      withData: true,
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() => d.cotizaciones.addAll(result.files));
    }
  }

  /// Líneas finales: por determinar resueltas + stock recalculado de todas.
  /// Las reglas viven en EvaluacionVentaRepuestoService (dominio).
  List<LineaRepuestoVentaEntity> _lineasFinales(Map<String, ItemInventarioEntity> mapaStock, String usuario) {
    final ahora = DateTime.now();
    final stockNeto = {
      for (final e in mapaStock.entries) EvaluacionVentaRepuestoService.claveCodigo(e.key): e.value.stockNetoDisponible,
    };
    final lineas = widget.ticket.lineasRepuestoVenta;
    final definidas = [
      for (int i = 0; i < lineas.length; i++)
        () {
          final l = lineas[i];
          final d = _definiciones[i];
          if (d == null) return l;
          if (d.enviaCotizacion == false) {
            final item = d.item!;
            return EvaluacionVentaRepuestoService.definirDesdeInventario(
              l,
              codigo: item.codigo,
              descripcion: item.descripcion,
              unidad: item.unidad,
              cantidad: d.cantidad!,
              stockNeto: item.stockNetoDisponible,
              definidoPor: usuario,
              definidoEn: ahora,
            );
          }
          return EvaluacionVentaRepuestoService.definirConCotizacionProveedor(
            l,
            codigoProveedor: d.codigoController.text,
            ficha: d.fichaCreacion,
            cantidad: d.cantidad!,
            definidoPor: usuario,
            definidoEn: ahora,
          );
        }(),
    ];
    // Stock actual de todas las líneas del sistema (las del proveedor no se tocan).
    return EvaluacionVentaRepuestoService.conStockActual(definidas, stockNeto);
  }

  Future<void> _finalizar() async {
    final inventario = context.read<InventarioBloc>().state;
    if (inventario is! InventarioLoaded) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('⏳ El inventario aún se está cargando, intente de nuevo en unos segundos.'),
        backgroundColor: Colors.orange,
      ));
      return;
    }

    final authState = context.read<AuthBloc>().state;
    String nombre = 'DESCONOCIDO';
    String rol = 'SIN_ROL';
    if (authState is Authenticated) {
      nombre = authState.usuario.nombre;
      rol = authState.usuario.rol.name.toUpperCase();
    }

    final lineas = _lineasFinales(inventario.mapaPorCodigo, nombre);
    final destino = RuteoVentaRepuestoService.destino(lineas);
    final gestion = lineas.where(RuteoVentaRepuestoService.requiereGestionCompras).length;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Finalizar evaluación?'),
        content: Text(destino == DestinoVentaRepuesto.compras
            ? 'El requerimiento pasará a COMPRAS: $gestion repuesto(s) sin stock o fuera del sistema.'
            : 'Todos los repuestos tienen stock: el requerimiento pasará a COMERCIAL para la proforma.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Finalizar')),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;

    final cotizaciones = [
      for (int i = 0; i < lineas.length; i++)
        (_definiciones[i]?.enviaCotizacion == true) ? List<PlatformFile>.from(_definiciones[i]!.cotizaciones) : <PlatformFile>[],
    ];

    setState(() => _enviando = true);
    context.read<TicketBloc>().add(FinalizarEvaluacionVentaRepuestoEvent(
          ticket: widget.ticket,
          lineas: lineas,
          cotizacionesPorLinea: cotizaciones,
          nombreUsuario: nombre,
          rolUsuario: rol,
        ));
  }

  @override
  Widget build(BuildContext context) {
    final ticket = widget.ticket;
    final lineas = ticket.lineasRepuestoVenta;

    return Scaffold(
      appBar: AppBar(
        title: Text('Evaluación de Venta: ${ticket.id}'),
        backgroundColor: Colors.teal.shade700,
        foregroundColor: Colors.white,
      ),
      body: BlocListener<TicketBloc, TicketState>(
        listener: (context, state) {
          if (!_enviando) return;
          if (state.status == TicketStatus.operationSuccess) {
            _enviando = false;
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.message), backgroundColor: Colors.green));
            Navigator.pop(context);
          } else if (state.status == TicketStatus.error) {
            setState(() => _enviando = false);
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.message), backgroundColor: Colors.red));
          }
        },
        child: BlocBuilder<TicketBloc, TicketState>(
          builder: (context, state) {
            final cargando = _enviando && state.status == TicketStatus.loading;
            return AbsorbPointer(
              absorbing: cargando,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _tarjetaContacto(ticket),
                  const SizedBox(height: 12),
                  _tarjetaDefinidos(lineas),
                  const SizedBox(height: 12),
                  for (int i = 0; i < lineas.length; i++)
                    if (_definiciones.containsKey(i)) _tarjetaPorDeterminar(lineas[i], _definiciones[i]!),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: !_todoResuelto || cargando ? null : _finalizar,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal.shade700,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: cargando
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.check_circle),
                      label: Text(
                        cargando ? state.message : (_todoResuelto ? 'FINALIZAR EVALUACIÓN' : 'Defina todos los repuestos para finalizar'),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // 👤 Datos de contacto
  Widget _tarjetaContacto(TicketEntity t) {
    Widget fila(String etiqueta, String valor) => Row(
          children: [
            Expanded(child: Text('$etiqueta $valor', style: const TextStyle(fontSize: 14))),
            CopyIconButtonWidget(etiqueta: etiqueta, valor: valor),
          ],
        );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Datos de contacto', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const Divider(),
            fila('Cliente:', t.clienteId),
            fila('Contacto:', t.nombreContacto),
            fila('Teléfono:', t.telefonoContacto),
            fila('Correo:', t.emailContacto),
            if (t.medioContacto != null) fila('Medio de contacto:', t.medioContacto!.name.toUpperCase()),
            fila('Repuesto de:', t.equipo.name.toUpperCase()),
          ],
        ),
      ),
    );
  }

  // 📦 Repuestos ya definidos al crear el requerimiento (solo lectura)
  Widget _tarjetaDefinidos(List<LineaRepuestoVentaEntity> lineas) {
    final definidos = [for (int i = 0; i < lineas.length; i++) if (!_definiciones.containsKey(i)) lineas[i]];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Repuestos ya definidos (${definidos.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const Divider(),
            if (definidos.isEmpty) const Text('Ninguno.', style: TextStyle(color: Colors.grey)),
            for (final l in definidos)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  '${l.codigo} — ${l.descripcionVisible} × ${_fmt(l.cantidad)} ${l.unidad} '
                  '(stock al registrar: ${_fmt(l.stockDisponibleAlEvaluar ?? 0)})'
                  '${l.cotizadaPorCompras ? ' · Cotizado por Compras ✓' : RuteoVentaRepuestoService.requiereGestionCompras(l) ? ' · Compras cotizando…' : ''}',
                  style: TextStyle(
                    fontSize: 13,
                    color: l.cotizadaPorCompras
                        ? kTicketExito
                        : l.tieneStockSuficiente
                            ? kTicketTextoPrincipal
                            : kTicketError,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // 🔧 Repuesto por determinar: evidencia + selector + definición
  Widget _tarjetaPorDeterminar(LineaRepuestoVentaEntity l, _Definicion d) {
    return Card(
      color: const Color(0xFFFFF8E1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: d.resuelta ? Colors.green.shade400 : Colors.orange.shade300, width: 1.5),
      ),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(d.resuelta ? Icons.check_circle : Icons.engineering,
                    color: d.resuelta ? Colors.green.shade700 : Colors.orange.shade800),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('Repuesto por determinar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text('Cliente: "${l.descripcionCliente}" × ${_fmt(l.cantidad)}', style: const TextStyle(fontStyle: FontStyle.italic)),
            const SizedBox(height: 10),
            _evidencia(l),
            const Divider(height: 24),
            const Text('¿Enviar cotización?', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            SegmentedButton<bool>(
              emptySelectionAllowed: true,
              segments: const [
                ButtonSegment(value: false, icon: Icon(Icons.search), label: Text('No — buscar en el sistema')),
                ButtonSegment(value: true, icon: Icon(Icons.upload_file), label: Text('Sí — cotización de proveedor')),
              ],
              selected: d.enviaCotizacion == null ? <bool>{} : {d.enviaCotizacion!},
              onSelectionChanged: (sel) => setState(() => d.enviaCotizacion = sel.isEmpty ? null : sel.first),
            ),
            const SizedBox(height: 12),
            if (d.enviaCotizacion == false) ..._formularioInventario(d),
            if (d.enviaCotizacion == true) ..._formularioProveedor(d),
          ],
        ),
      ),
    );
  }

  Widget _evidencia(LineaRepuestoVentaEntity l) {
    bool esVideo(String url) {
      final u = url.toLowerCase().split('?').first;
      return u.endsWith('.mp4') || u.endsWith('.mov') || u.endsWith('.webm') || u.endsWith('.3gp');
    }

    if (l.urlsEvidencia.isEmpty && l.urlsAudios.isEmpty) {
      return const Text('Sin evidencia adjunta.', style: TextStyle(color: Colors.grey));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (l.urlsEvidencia.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final url in l.urlsEvidencia)
                InkWell(
                  onTap: () => _abrir(url),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 90,
                      height: 90,
                      child: esVideo(url)
                          ? Container(
                              color: Colors.black87,
                              child: const Icon(Icons.play_circle_fill, color: Colors.white, size: 36),
                            )
                          : Image.network(
                              url,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => Container(
                                color: Colors.grey.shade300,
                                child: const Icon(Icons.broken_image),
                              ),
                            ),
                    ),
                  ),
                ),
            ],
          ),
        for (int i = 0; i < l.urlsAudios.length; i++)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.play_circle_outline, color: Colors.teal),
            title: Text('Escuchar nota de voz ${i + 1}',
                style: const TextStyle(color: Colors.teal, decoration: TextDecoration.underline)),
            onTap: () => _abrir(l.urlsAudios[i]),
          ),
      ],
    );
  }

  List<Widget> _formularioInventario(_Definicion d) {
    return [
      BlocBuilder<InventarioBloc, InventarioState>(
        builder: (context, state) {
          final items = state is InventarioLoaded ? state.items : const <ItemInventarioEntity>[];
          return Autocomplete<ItemInventarioEntity>(
            displayStringForOption: (i) => '${i.codigo} - ${i.descripcion}',
            optionsBuilder: (value) {
              if (value.text.isEmpty) return const Iterable<ItemInventarioEntity>.empty();
              final q = value.text.toLowerCase();
              return items
                  .where((i) => i.codigo.toLowerCase().contains(q) || i.descripcion.toLowerCase().contains(q))
                  .take(20);
            },
            onSelected: (item) => setState(() => d.item = item),
            fieldViewBuilder: (context, controller, focusNode, _) => TextField(
              controller: controller,
              focusNode: focusNode,
              decoration: InputDecoration(
                labelText: state is InventarioLoading ? 'Cargando inventario...' : 'Buscar repuesto por nombre o código',
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (_) {
                if (d.item != null) setState(() => d.item = null);
              },
            ),
          );
        },
      ),
      if (d.item != null) ...[
        const SizedBox(height: 8),
        Text(
          'Seleccionado: ${d.item!.codigo} — ${d.item!.descripcion} · '
          'Stock neto: ${_fmt(d.item!.stockNetoDisponible)} ${d.item!.unidad}',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: d.item!.stockNetoDisponible > 0 ? Colors.green.shade800 : kTicketError,
          ),
        ),
      ],
      const SizedBox(height: 10),
      _campoCantidad(d),
    ];
  }

  List<Widget> _formularioProveedor(_Definicion d) {
    final faltan = d.fichaCreacion.faltantes;
    Widget casilla(String etiqueta, bool valor, ValueChanged<bool> cambiar) => FilterChip(
          label: Text('$etiqueta: ${valor ? 'SI' : 'NO'}'),
          selected: valor,
          onSelected: (v) => setState(() => cambiar(v)),
        );
    return [
      // 🧾 Ficha de creación de código (la usa Costos para crearlo en el ERP)
      Text('Ficha de creación de código', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal.shade900)),
      const SizedBox(height: 4),
      Text('Este repuesto no está en el sistema: Costos creará el código con estos datos. (*) obligatorio.',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
      const SizedBox(height: 8),
      Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final e in _camposFichaTexto.entries)
            SizedBox(
              width: e.key == 'nombre' || e.key.startsWith('link') ? 520 : 255,
              child: TextField(
                controller: d.ficha[e.key],
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(labelText: e.value.$1, border: const OutlineInputBorder(), isDense: true),
              ),
            ),
        ],
      ),
      const SizedBox(height: 10),
      const Text('Parámetros', style: TextStyle(fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      Wrap(
        spacing: 8,
        runSpacing: 6,
        children: [
          casilla('Comprado', d.comprado, (v) => d.comprado = v),
          casilla('Vendido', d.vendido, (v) => d.vendido = v),
          casilla('Activo', d.activo, (v) => d.activo = v),
          casilla('Almacenado', d.almacenado, (v) => d.almacenado = v),
          casilla('Grava IVA', d.gravaIva, (v) => d.gravaIva = v),
          casilla('Fabricado', d.fabricado, (v) => d.fabricado = v),
        ],
      ),
      if (faltan.isNotEmpty) ...[
        const SizedBox(height: 6),
        Text('Falta: ${faltan.join(', ')}', style: const TextStyle(fontSize: 12, color: kTicketError)),
      ],
      const Divider(height: 24),
      TextField(
        controller: d.codigoController,
        decoration: const InputDecoration(
          labelText: 'Código del proveedor (opcional)',
          border: OutlineInputBorder(),
          isDense: true,
        ),
      ),
      const SizedBox(height: 10),
      _campoCantidad(d),
      const SizedBox(height: 10),
      OutlinedButton.icon(
        onPressed: () => _adjuntarCotizacion(d),
        icon: const Icon(Icons.attach_file),
        label: Text('Adjuntar cotización del proveedor (${d.cotizaciones.length})'),
      ),
      for (int i = 0; i < d.cotizaciones.length; i++)
        ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.description_outlined),
          title: Text(d.cotizaciones[i].name, overflow: TextOverflow.ellipsis),
          trailing: IconButton(
            icon: const Icon(Icons.close, color: Colors.redAccent),
            onPressed: () => setState(() => d.cotizaciones.removeAt(i)),
          ),
        ),
      Text('Este repuesto quedará como "No existe en el sistema" y pasará por Compras.',
          style: TextStyle(fontSize: 12, color: Colors.orange.shade900)),
    ];
  }

  Widget _campoCantidad(_Definicion d) => TextField(
        controller: d.cantidadController,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onChanged: (_) => setState(() {}),
        decoration: const InputDecoration(
          labelText: 'Cantidad',
          border: OutlineInputBorder(),
          isDense: true,
        ),
      );
}
