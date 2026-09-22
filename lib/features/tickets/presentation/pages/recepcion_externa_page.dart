// lib/features/tickets/presentation/pages/recepcion_externa_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/services/acceso_temporal_bodega_service.dart';
import '../../data/models/token_recepcion_externa_model.dart';
import '../../data/models/ticket_model.dart';
import '../../domain/entities/ticket_entity.dart';
import '../../domain/entities/orden_recepcion_repuestos_entity.dart';

enum EstadoCargaToken {
  cargando,
  noExiste,
  usado,
  expirado,
  valido,
  guardando,
  completadoExitosamente,
  error,
}

class RecepcionExternaPage extends StatefulWidget {
  final String token;

  const RecepcionExternaPage({super.key, required this.token});

  @override
  State<RecepcionExternaPage> createState() => _RecepcionExternaPageState();
}

class _RecepcionExternaPageState extends State<RecepcionExternaPage> {
  final AccesoTemporalBodegaService _accesoService = AccesoTemporalBodegaService();
  final TextEditingController _notasController = TextEditingController();

  EstadoCargaToken _estado = EstadoCargaToken.cargando;
  String _mensajeError = '';
  TokenRecepcionExternaModel? _tokenModel;
  TicketEntity? _ticket;
  OrdenRecepcionRepuestosEntity? _orden;

  final Map<String, TextEditingController> _cantidadesControllers = {};
  final Map<String, bool> _itemsValidados = {};

  @override
  void initState() {
    super.initState();
    _validarTokenYCargarDatos();
  }

  @override
  void dispose() {
    _notasController.dispose();
    for (final c in _cantidadesControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _validarTokenYCargarDatos() async {
    setState(() {
      _estado = EstadoCargaToken.cargando;
    });

    try {
      final tokenModel = await _accesoService.obtenerToken(widget.token);
      if (tokenModel == null) {
        setState(() {
          _estado = EstadoCargaToken.noExiste;
        });
        return;
      }

      if (tokenModel.usado) {
        setState(() {
          _tokenModel = tokenModel;
          _estado = EstadoCargaToken.usado;
        });
        return;
      }

      if (tokenModel.estaExpirado) {
        setState(() {
          _tokenModel = tokenModel;
          _estado = EstadoCargaToken.expirado;
        });
        return;
      }

      // Cargar ticket desde Firestore
      final ticketSnap = await FirebaseFirestore.instance
          .collection('tickets')
          .doc(tokenModel.ticketId)
          .get();

      if (!ticketSnap.exists || ticketSnap.data() == null) {
        setState(() {
          _estado = EstadoCargaToken.error;
          _mensajeError = 'El ticket ${tokenModel.ticketId} no fue encontrado.';
        });
        return;
      }

      final ticket = TicketModel.fromJson(ticketSnap.data()!);
      final orden = ticket.ordenesRecepcion.firstWhere(
        (o) => o.id == tokenModel.ordenId,
        orElse: () => throw Exception('Orden ${tokenModel.ordenId} no encontrada en el ticket.'),
      );

      if (orden.estado == EstadoOrdenRecepcion.recibidoTotal) {
        setState(() {
          _tokenModel = tokenModel;
          _estado = EstadoCargaToken.usado;
        });
        return;
      }

      // Inicializar controladores con conteo físico vacío (obligatorio contar)
      _cantidadesControllers.clear();
      _itemsValidados.clear();
      for (final item in orden.items) {
        _cantidadesControllers[item.codigo] = TextEditingController(text: '');
        _itemsValidados[item.codigo] = false;
      }

      setState(() {
        _tokenModel = tokenModel;
        _ticket = ticket;
        _orden = orden;
        _estado = EstadoCargaToken.valido;
      });
    } catch (e) {
      setState(() {
        _estado = EstadoCargaToken.error;
        _mensajeError = e.toString();
      });
    }
  }

  bool get _hayExcesos {
    if (_orden == null) return false;
    for (final item in _orden!.items) {
      final ctrl = _cantidadesControllers[item.codigo];
      final val = double.tryParse(ctrl?.text.trim() ?? '');
      if (val != null && (val > item.cantidadDespachadaBodega || val < 0)) {
        return true;
      }
    }
    return false;
  }

  bool get _estanTodosContados {
    if (_orden == null) return false;
    for (final item in _orden!.items) {
      final ctrl = _cantidadesControllers[item.codigo];
      if (ctrl == null || ctrl.text.trim().isEmpty) return false;
      final val = double.tryParse(ctrl.text.trim());
      if (val == null || val < 0 || val > item.cantidadDespachadaBodega) return false;
    }
    return true;
  }

  Future<void> _confirmarYGuardar() async {
    if (_tokenModel == null || _ticket == null || _orden == null) return;

    if (_hayExcesos) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error: Una o más cantidades superan lo alistado por bodega.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Verificar si algún ítem no está validado o cantidad es menor
    bool hayFaltantes = false;
    final List<ItemRecepcionRepuestoEntity> itemsAEnviar = [];

    for (final item in _orden!.items) {
      final ctrl = _cantidadesControllers[item.codigo];
      final cant = double.tryParse(ctrl?.text.trim() ?? '') ?? 0.0;
      if (cant < 0 || cant > item.cantidadDespachadaBodega) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: La cantidad de ${item.codigo} excede el máximo alistado (${item.cantidadDespachadaBodega} ${item.unidad}).'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      final bool val = cant == item.cantidadDespachadaBodega;

      if (cant < item.cantidadDespachadaBodega) {
        hayFaltantes = true;
      }

      itemsAEnviar.add(item.copyWith(
        cantidadRecibidaTecnico: cant,
        validado: val,
      ));
    }

    if (hayFaltantes) {
      final bool? proceder = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
              SizedBox(width: 8),
              Text('Recepción Parcial', style: TextStyle(fontSize: 16)),
            ],
          ),
          content: const Text(
            'Ha indicado cantidades menores a las alistadas por Bodega o ítems sin verificar.\n\n¿Desea confirmar la recepción como PARCIAL?',
            style: TextStyle(fontSize: 13, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Revisar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade800,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Confirmar Parcial'),
            ),
          ],
        ),
      );

      if (proceder != true) return;
    } else {
      final bool? proceder = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.check_circle_outline, color: Color(0xFF2E7D32), size: 28),
              SizedBox(width: 8),
              Text('Confirmar Retiro', style: TextStyle(fontSize: 16)),
            ],
          ),
          content: const Text(
            '¿Confirma que ha recibido físicamente todos los repuestos en Bodega y los traslada a Taller?\n\nUna vez confirmado, este enlace quedará finalizado.',
            style: TextStyle(fontSize: 13, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00796B),
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Confirmar Retiro'),
            ),
          ],
        ),
      );

      if (proceder != true) return;
    }

    setState(() {
      _estado = EstadoCargaToken.guardando;
    });

    try {
      await _accesoService.consumirTokenYConfirmarRecepcion(
        token: widget.token,
        ticketId: _tokenModel!.ticketId,
        ordenId: _tokenModel!.ordenId,
        itemsValidados: itemsAEnviar,
        nombreTecnico: _tokenModel!.tecnicoNombre,
        notas: _notasController.text.trim(),
      );

      setState(() {
        _estado = EstadoCargaToken.completadoExitosamente;
      });
    } catch (e) {
      setState(() {
        _estado = EstadoCargaToken.valido;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al confirmar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.warehouse_outlined, color: Colors.white, size: 22),
            SizedBox(width: 8),
            Text(
              'Aquaspot - Retiro Bodega',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF005A9C),
        foregroundColor: Colors.white,
        elevation: 1,
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_estado) {
      case EstadoCargaToken.cargando:
        return const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Color(0xFF005A9C)),
              SizedBox(height: 16),
              Text('Validando enlace de acceso seguro...', style: TextStyle(color: Colors.grey)),
            ],
          ),
        );

      case EstadoCargaToken.noExiste:
        return _buildCardEstado(
          icono: Icons.link_off,
          colorIcono: Colors.red,
          titulo: 'Enlace no válido',
          descripcion: 'El enlace de retiro no existe, ha sido revocado o la dirección es incorrecta.',
        );

      case EstadoCargaToken.usado:
        return _buildCardEstado(
          icono: Icons.lock_clock,
          colorIcono: Colors.amber.shade900,
          titulo: 'Enlace ya utilizado',
          descripcion: 'Esta orden de retiro ya fue confirmada previamente. Por motivos de seguridad, el enlace ha quedado invalidado.',
        );

      case EstadoCargaToken.expirado:
        return _buildCardEstado(
          icono: Icons.timer_off_outlined,
          colorIcono: Colors.orange.shade800,
          titulo: 'Enlace expirado',
          descripcion: 'Este enlace temporal ha superado el tiempo máximo de validez (24 horas). Por favor solicite un nuevo enlace a Supervisión.',
        );

      case EstadoCargaToken.error:
        return _buildCardEstado(
          icono: Icons.error_outline,
          colorIcono: Colors.red,
          titulo: 'Error de carga',
          descripcion: _mensajeError.isNotEmpty ? _mensajeError : 'Ocurrió un error al procesar el enlace.',
        );

      case EstadoCargaToken.guardando:
        return const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Color(0xFF00796B)),
              SizedBox(height: 16),
              Text('Registrando recepción física y cerrando enlace...', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
        );

      case EstadoCargaToken.completadoExitosamente:
        return _buildCardExito();

      case EstadoCargaToken.valido:
        return _buildFormularioRecepcion();
    }
  }

  Widget _buildCardEstado({
    required IconData icono,
    required Color colorIcono,
    required String titulo,
    required String descripcion,
  }) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(28.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 36,
                backgroundColor: colorIcono.withValues(alpha: 0.1),
                child: Icon(icono, size: 40, color: colorIcono),
              ),
              const SizedBox(height: 18),
              Text(
                titulo,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0D2438)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                descripcion,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700, height: 1.4),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              const Text(
                'Aquaspot Postventa - Cadena de Custodia',
                style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCardExito() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(28.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircleAvatar(
                radius: 40,
                backgroundColor: Color(0xFFE8F5E9),
                child: Icon(Icons.check_circle, size: 50, color: Color(0xFF2E7D32)),
              ),
              const SizedBox(height: 20),
              const Text(
                '¡Retiro Confirmado!',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                'Muchas gracias, ${_tokenModel?.tecnicoNombre}. Los repuestos han sido registrados físicamente como recibidos y trasladados a Taller.',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade800, height: 1.4),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade300),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.lock, size: 18, color: Colors.orange),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Por motivos de seguridad, este enlace ha expirado y no admite más modificaciones.',
                        style: TextStyle(fontSize: 11, color: Color(0xFFE65100), fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Ya puede cerrar esta pestaña del navegador.',
                style: TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormularioRecepcion() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner de Identificación
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Color(0xFF005A9C), width: 1.5),
            ),
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF3E0),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.orange.shade400),
                        ),
                        child: Text(
                          _orden!.id,
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.orange.shade900),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Ticket: ${_ticket!.id}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF005A9C)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.handshake_outlined, size: 18, color: Colors.orange),
                      const SizedBox(width: 6),
                      Text(
                        'Técnico Externo: ${_tokenModel?.tecnicoNombre}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Equipo: ${_ticket!.equipo.name.toUpperCase()} - Cliente: ${_ticket!.clienteId}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                  const Divider(height: 20),
                  const Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: Color(0xFF00796B)),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Verifique físicamente cada repuesto entregado por Bodega antes de confirmar.',
                          style: TextStyle(fontSize: 11, color: Color(0xFF00796B), fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Lista de repuestos
          Text(
            'Repuestos a Retirar (${_orden!.items.length} ítems):',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF003057)),
          ),
          const SizedBox(height: 8),

          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _orden!.items.length,
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final item = _orden!.items[index];
              final ctrl = _cantidadesControllers[item.codigo];
              final text = ctrl?.text.trim() ?? '';
              final double? parsedVal = double.tryParse(text);
              final bool tieneConteo = text.isNotEmpty && parsedVal != null;
              final double cantidadContada = parsedVal ?? 0.0;
              final bool excedeMaximo = tieneConteo && (cantidadContada > item.cantidadDespachadaBodega);
              final bool esInvalido = tieneConteo && (cantidadContada < 0);
              final bool esConforme = tieneConteo && !excedeMaximo && !esInvalido && (cantidadContada == item.cantidadDespachadaBodega);
              final bool hayDiscrepancia = tieneConteo && !excedeMaximo && !esInvalido && (cantidadContada < item.cantidadDespachadaBodega);

              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(
                    color: !tieneConteo
                        ? Colors.grey.shade300
                        : (excedeMaximo || esInvalido)
                            ? Colors.red.shade600
                            : esConforme
                                ? Colors.green.shade400
                                : Colors.orange.shade400,
                    width: (excedeMaximo || esInvalido) ? 2.0 : 1.5,
                  ),
                ),
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE3F2FD),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              item.codigo,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF0D47A1)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              item.descripcion,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: !tieneConteo
                                  ? Colors.grey.shade100
                                  : (excedeMaximo || esInvalido)
                                      ? const Color(0xFFFFEBEE)
                                      : esConforme
                                          ? const Color(0xFFE8F5E9)
                                          : const Color(0xFFFFF3E0),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              !tieneConteo
                                  ? 'SIN CONTEO'
                                  : (excedeMaximo || esInvalido)
                                      ? 'EXCEDE MÁXIMO'
                                      : esConforme
                                          ? 'CONFORME'
                                          : 'DISCREPANCIA',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: !tieneConteo
                                    ? Colors.grey.shade600
                                    : (excedeMaximo || esInvalido)
                                        ? const Color(0xFFC62828)
                                        : esConforme
                                            ? const Color(0xFF2E7D32)
                                            : Colors.orange.shade900,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Alistado por Bodega: ${item.cantidadDespachadaBodega} ${item.unidad}',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: ctrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: 'Conteo Físico Real (${item.unidad}) *',
                          hintText: 'Digita la cantidad real contada',
                          helperText: 'Máximo alistado: ${item.cantidadDespachadaBodega} ${item.unidad}',
                          errorText: excedeMaximo
                              ? 'No puede superar ${item.cantidadDespachadaBodega} ${item.unidad} (máx. alistado)'
                              : esInvalido
                                  ? 'No puede ser un valor negativo'
                                  : null,
                          prefixIcon: Icon(
                            (excedeMaximo || esInvalido) ? Icons.error_outline : Icons.pin,
                            size: 18,
                            color: (excedeMaximo || esInvalido) ? Colors.red : const Color(0xFF00796B),
                          ),
                          suffixText: item.unidad,
                          isDense: true,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          filled: true,
                          fillColor: !tieneConteo
                              ? Colors.amber.shade50.withValues(alpha: 0.3)
                              : (excedeMaximo || esInvalido)
                                  ? Colors.red.shade50.withValues(alpha: 0.3)
                                  : Colors.white,
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      if (excedeMaximo) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFEBEE),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.red.shade300),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.error_outline, color: Colors.red.shade800, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Error: Ha digitado $cantidadContada ${item.unidad}. Bodega solo alistó un máximo de ${item.cantidadDespachadaBodega} ${item.unidad}. No puede recibir más de lo alistado.',
                                  style: TextStyle(fontSize: 11, color: Colors.red.shade900, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else if (hayDiscrepancia) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade50,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.amber.shade300),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.warning_amber_rounded, color: Colors.orange.shade800, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Discrepancia: Bodega alistó ${item.cantidadDespachadaBodega} ${item.unidad}, pero contaste $cantidadContada ${item.unidad}. Faltante: ${(item.cantidadDespachadaBodega - cantidadContada).toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '')} ${item.unidad}.',
                                  style: TextStyle(fontSize: 11, color: Colors.orange.shade900, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),

          // Observaciones
          TextField(
            controller: _notasController,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: 'Observaciones del retiro (Opcional)',
              hintText: 'Ej: Todo recibido en caja sellada, sin novedades...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
          const SizedBox(height: 24),

          // Botón Confirmar
          Builder(
            builder: (context) {
              final bool puedeConfirmar = _estanTodosContados && !_hayExcesos;
              final String textoBoton = _hayExcesos
                  ? 'HAY CANTIDADES QUE EXCEDEN EL MÁXIMO ALISTADO'
                  : !_estanTodosContados
                      ? 'DEBE INGRESAR EL CONTEO DE TODOS LOS REPUESTOS'
                      : 'CONFIRMAR Y FINALIZAR RETIRO';

              return SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  icon: Icon(puedeConfirmar ? Icons.check_circle_outline : Icons.pending_actions, size: 22),
                  label: Text(
                    textoBoton,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: puedeConfirmar ? const Color(0xFF00796B) : Colors.grey.shade400,
                    foregroundColor: Colors.white,
                    elevation: puedeConfirmar ? 3 : 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: puedeConfirmar ? _confirmarYGuardar : null,
                ),
              );
            },
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}
