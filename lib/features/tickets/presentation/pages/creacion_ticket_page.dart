import 'dart:async';
import 'package:aquaspot_postventa/core/enum/marca_equipo.dart';
import 'package:aquaspot_postventa/core/services/borrador_storage_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import '../bloc/ticket_bloc.dart';
import '../bloc/ticket_event.dart';
import '../bloc/ticket_state.dart';
import '../../../../core/enum/ticket_enums.dart'; 
import '../../../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../../../features/auth/presentation/bloc/auth_state.dart';
import '../widgets/ticket_form_widget.dart';
import '../widgets/confirmacion_ingreso_dialog.dart';
import 'package:printing/printing.dart';

class CreacionTicketPage extends StatefulWidget {
  const CreacionTicketPage({super.key});

  @override
  State<CreacionTicketPage> createState() => _CreacionTicketPageState();
}

class _CreacionTicketPageState extends State<CreacionTicketPage> {
  final _formKey = GlobalKey<FormState>();
  
  // =========================================================
  // 🗄️ BANCO DE CONTROLADORES (Controller Bank)
  // =========================================================
  final TextEditingController _clienteController = TextEditingController();
  final TextEditingController _customEquipoController = TextEditingController();
  final TextEditingController _campamentoController = TextEditingController();
  final TextEditingController _nombreContactoController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _telefonoController = TextEditingController();
  final TextEditingController _fallaController = TextEditingController();
  final TextEditingController _serieController = TextEditingController();
  final TextEditingController _notasController = TextEditingController();
  
  // 🔌 NUEVO SENSOR: Controlador para el horómetro de maquinaria agrícola
  final TextEditingController _horometroController = TextEditingController();

  // Memoria Volátil (Volatile Memory)
  String? _selectedClienteId; 
  Sede? _selectedSede;
  TipoEquipo? _selectedEquipo;
  MarcaEquipo? _selectedMarca;
  Prioridad? _prioridad;
  final Map<String, bool> _accesoriosSeleccionados = {};
  final List<XFile> _archivosEvidencia = [];
  final List<XFile> _archivosEvidenciaGarantia = [];

  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    context.read<TicketBloc>().add(ObtenerClientesEvent());
    _conectarAutoGuardadoBorrador();
    _cargarBorradorLocal();
  }

  void _onTextoModificado() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 600), () {
      _guardarBorrador();
    });
  }

  void _conectarAutoGuardadoBorrador() {
    _clienteController.addListener(_onTextoModificado);
    _customEquipoController.addListener(_onTextoModificado);
    _campamentoController.addListener(_onTextoModificado);
    _nombreContactoController.addListener(_onTextoModificado);
    _emailController.addListener(_onTextoModificado);
    _telefonoController.addListener(_onTextoModificado);
    _fallaController.addListener(_onTextoModificado);
    _serieController.addListener(_onTextoModificado);
    _notasController.addListener(_onTextoModificado);
    _horometroController.addListener(_onTextoModificado);
  }

  void _desconectarAutoGuardadoBorrador() {
    _clienteController.removeListener(_onTextoModificado);
    _customEquipoController.removeListener(_onTextoModificado);
    _campamentoController.removeListener(_onTextoModificado);
    _nombreContactoController.removeListener(_onTextoModificado);
    _emailController.removeListener(_onTextoModificado);
    _telefonoController.removeListener(_onTextoModificado);
    _fallaController.removeListener(_onTextoModificado);
    _serieController.removeListener(_onTextoModificado);
    _notasController.removeListener(_onTextoModificado);
    _horometroController.removeListener(_onTextoModificado);
  }

  Future<void> _guardarBorrador() async {
    if (!mounted) return;
    final currentState = context.read<TicketBloc>().state;

    final evidenciasJson = await BorradorStorageService.xFilesToJson(_archivosEvidencia);
    final evidenciasGarantiaJson = await BorradorStorageService.xFilesToJson(_archivosEvidenciaGarantia);

    await BorradorStorageService.guardarBorrador(
      clave: BorradorStorageService.kClaveDraftCreacionTicket,
      datos: {
        'cliente': _clienteController.text,
        'customEquipo': _customEquipoController.text,
        'campamento': _campamentoController.text,
        'nombreContacto': _nombreContactoController.text,
        'email': _emailController.text,
        'telefono': _telefonoController.text,
        'falla': _fallaController.text,
        'serie': _serieController.text,
        'notas': _notasController.text,
        'horometro': _horometroController.text,
        'selectedClienteId': _selectedClienteId,
        'selectedSede': _selectedSede?.name,
        'selectedEquipo': _selectedEquipo?.name,
        'selectedMarca': _selectedMarca?.name,
        'prioridad': _prioridad?.name,
        'accesorios': _accesoriosSeleccionados,
        // Persistencia del flujo seleccionado (Reparación / Garantía, Taller / Campo, etc.)
        'tipoRequerimiento': currentState.tipoSeleccionado.name,
        'lugarAtencion': currentState.lugarAtencion.name,
        'tipoGarantia': currentState.tipoGarantia.name,
        // Evidencias fotográficas completas con Base64
        'evidencias': evidenciasJson,
        'evidenciasGarantia': evidenciasGarantiaJson,
        'evidenciasPaths': BorradorStorageService.xFilesToPaths(_archivosEvidencia),
        'evidenciasGarantiaPaths': BorradorStorageService.xFilesToPaths(_archivosEvidenciaGarantia),
      },
    );
  }

  Future<void> _cargarBorradorLocal() async {
    final draft = await BorradorStorageService.obtenerBorrador(
      BorradorStorageService.kClaveDraftCreacionTicket,
    );
    if (draft != null && mounted) {
      // 1. Restaurar flujo en TicketBloc (Reparación/Garantía, Taller/Campo, Tipo Garantía)
      if (draft['tipoRequerimiento'] != null) {
        final tipoStr = draft['tipoRequerimiento'] as String;
        final tipo = TipoRequerimiento.values.cast<TipoRequerimiento?>().firstWhere(
          (e) => e?.name == tipoStr,
          orElse: () => null,
        );
        if (tipo != null && tipo != TipoRequerimiento.ninguno) {
          context.read<TicketBloc>().add(SeleccionarTipoRequerimientoEvent(tipo));

          if (draft['lugarAtencion'] != null) {
            final lugarStr = draft['lugarAtencion'] as String;
            final lugar = LugarAtencion.values.cast<LugarAtencion?>().firstWhere(
              (e) => e?.name == lugarStr,
              orElse: () => null,
            );
            if (lugar != null && lugar != LugarAtencion.noAplica) {
              context.read<TicketBloc>().add(SeleccionarLugarAtencionEvent(lugar));
            }
          }

          if (draft['tipoGarantia'] != null) {
            final garStr = draft['tipoGarantia'] as String;
            final gar = TipoGarantia.values.cast<TipoGarantia?>().firstWhere(
              (e) => e?.name == garStr,
              orElse: () => null,
            );
            if (gar != null && gar != TipoGarantia.pendiente) {
              context.read<TicketBloc>().add(SeleccionarTipoGarantiaEvent(gar));
            }
          }
        }
      }

      // 2. Restaurar campos de texto y controladores
      setState(() {
        if (draft['cliente'] != null && (draft['cliente'] as String).isNotEmpty) {
          _clienteController.text = draft['cliente'];
        }
        if (draft['customEquipo'] != null) _customEquipoController.text = draft['customEquipo'];
        if (draft['campamento'] != null) _campamentoController.text = draft['campamento'];
        if (draft['nombreContacto'] != null) _nombreContactoController.text = draft['nombreContacto'];
        if (draft['email'] != null) _emailController.text = draft['email'];
        if (draft['telefono'] != null) _telefonoController.text = draft['telefono'];
        if (draft['falla'] != null) _fallaController.text = draft['falla'];
        if (draft['serie'] != null) _serieController.text = draft['serie'];
        if (draft['notas'] != null) _notasController.text = draft['notas'];
        if (draft['horometro'] != null) _horometroController.text = draft['horometro'];
        if (draft['selectedClienteId'] != null) _selectedClienteId = draft['selectedClienteId'];

        if (draft['selectedSede'] != null) {
          final s = draft['selectedSede'] as String;
          _selectedSede = Sede.values.cast<Sede?>().firstWhere((e) => e?.name == s, orElse: () => null);
        }
        if (draft['selectedEquipo'] != null) {
          final eq = draft['selectedEquipo'] as String;
          _selectedEquipo = TipoEquipo.values.cast<TipoEquipo?>().firstWhere((e) => e?.name == eq, orElse: () => null);
        }
        if (draft['selectedMarca'] != null) {
          final m = draft['selectedMarca'] as String;
          _selectedMarca = MarcaEquipo.values.cast<MarcaEquipo?>().firstWhere((e) => e?.name == m, orElse: () => null);
        }
        if (draft['prioridad'] != null) {
          final p = draft['prioridad'] as String;
          _prioridad = Prioridad.values.cast<Prioridad?>().firstWhere((e) => e?.name == p, orElse: () => null);
        }
        if (draft['accesorios'] != null && draft['accesorios'] is Map) {
          final mapAcc = Map<String, dynamic>.from(draft['accesorios'] as Map);
          mapAcc.forEach((k, v) {
            _accesoriosSeleccionados[k] = v == true;
          });
        }

        // 3. Restaurar fotos
        if (draft['evidencias'] != null && draft['evidencias'] is List) {
          final restauradas = BorradorStorageService.jsonToXFiles(draft['evidencias'] as List);
          _archivosEvidencia.clear();
          _archivosEvidencia.addAll(restauradas);
        } else if (draft['evidenciasPaths'] != null && draft['evidenciasPaths'] is List) {
          final restauradas = BorradorStorageService.pathsToXFiles(draft['evidenciasPaths'] as List);
          _archivosEvidencia.clear();
          _archivosEvidencia.addAll(restauradas);
        }

        if (draft['evidenciasGarantia'] != null && draft['evidenciasGarantia'] is List) {
          final restauradas = BorradorStorageService.jsonToXFiles(draft['evidenciasGarantia'] as List);
          _archivosEvidenciaGarantia.clear();
          _archivosEvidenciaGarantia.addAll(restauradas);
        } else if (draft['evidenciasGarantiaPaths'] != null && draft['evidenciasGarantiaPaths'] is List) {
          final restauradas = BorradorStorageService.pathsToXFiles(draft['evidenciasGarantiaPaths'] as List);
          _archivosEvidenciaGarantia.clear();
          _archivosEvidenciaGarantia.addAll(restauradas);
        }
      });

      // 4. Notificación discreta y no invasiva (flotante, 2 segundos)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          duration: const Duration(seconds: 2),
          backgroundColor: const Color(0xFF005A9C),
          content: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.save_as_outlined, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text('Borrador restaurado', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _desconectarAutoGuardadoBorrador();
    _clienteController.dispose();
    _customEquipoController.dispose();
    _campamentoController.dispose();
    _nombreContactoController.dispose();
    _emailController.dispose();
    _telefonoController.dispose();
    _fallaController.dispose();
    _serieController.dispose();
    _notasController.dispose();
    _horometroController.dispose();
    super.dispose();
  }

  void _limpiarFormulario() {
    _debounceTimer?.cancel();
    FocusScope.of(context).unfocus();
    
    _clienteController.clear();
    _customEquipoController.clear();
    _campamentoController.clear();
    _nombreContactoController.clear();
    _telefonoController.clear();
    _emailController.clear();
    _fallaController.clear();
    _serieController.clear();
    _notasController.clear();
    _horometroController.clear();
    
    setState(() {
      _selectedSede = null;
      _selectedEquipo = null;
      _selectedClienteId = null;
      _selectedMarca = null;
      _prioridad = null;
      _accesoriosSeleccionados.clear();
      _archivosEvidencia.clear();
      _archivosEvidenciaGarantia.clear();
    });
    
    context.read<TicketBloc>().add(ResetearRequerimientoEvent());
    _formKey.currentState?.reset();
    BorradorStorageService.eliminarBorrador(BorradorStorageService.kClaveDraftCreacionTicket);
  }

  Future<void> _confirmarDescartarBorrador() async {
    final bool? confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Text('Descartar Borrador'),
          ],
        ),
        content: const Text(
          '¿Desea eliminar el borrador guardado localmente? Se restablecerán todos los campos, fotos y selecciones.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Descartar'),
          ),
        ],
      ),
    );

    if (confirmar == true && mounted) {
      _limpiarFormulario();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.blueGrey.shade800,
            content: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.delete_outline, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text('Borrador descartado', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        );
      }
    }
  }

  // 📷 SUBRUTINA DE ACTUADOR MULTIMEDIA
  Future<void> _abrirSelectorMultimedia() async {
    try {
      final ImagePicker picker = ImagePicker();
      final List<XFile> fotos = await picker.pickMultiImage(
        imageQuality: 70,
      );

      if (fotos.isNotEmpty) {
        setState(() {
          _archivosEvidenciaGarantia.addAll(fotos);
        });
        _guardarBorrador();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
              content: Text('✅ ${fotos.length} foto(s) de garantía adjuntada(s).'),
              backgroundColor: Colors.green.shade700,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text('🛑 Error en el selector de fotos: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _submitForm() async {
    final currentState = context.read<TicketBloc>().state;

    if (!_formKey.currentState!.validate()) return;

    if (_selectedClienteId == null || _selectedClienteId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('⚠️ Seleccione un Cliente.'), backgroundColor: Colors.orange));
      return;
    }
    
    if (_selectedMarca == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('⚠️ Especifique la Marca del Equipo.'), 
        backgroundColor: Colors.orange
      ));
      return;
    }

    if (currentState.lugarAtencion != LugarAtencion.campo && _selectedSede == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('⚠️ Especifique el lugar de recepción.'), backgroundColor: Colors.orange));
      return;
    }

    if (_selectedEquipo == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('⚠️ Seleccione el Tipo de Equipo.'), backgroundColor: Colors.orange));
      return;
    }

    if (currentState.tipoSeleccionado == TipoRequerimiento.ninguno) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('🛑 Seleccione el Tipo de Requerimiento.'), backgroundColor: Colors.red));
      return;
    }

    if ((currentState.tipoSeleccionado == TipoRequerimiento.reparacion || 
         currentState.tipoSeleccionado == TipoRequerimiento.reclamoGarantia) && 
        currentState.lugarAtencion == LugarAtencion.pendiente) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('🛑 Especifique si es en TALLER o CAMPO.'), backgroundColor: Colors.red));
      return;
    }

    final bool esOperacionEnCampo = currentState.lugarAtencion == LugarAtencion.campo;
    final bool tieneSerie = _serieController.text.trim().isNotEmpty;
    final bool tieneEvidencia = _archivosEvidencia.isNotEmpty;
    
    final bool esRegistroCompleto = esOperacionEnCampo 
        ? tieneSerie 
        : (tieneSerie && tieneEvidencia);
        
    ResponsableFacturacion responsableAsignado = ResponsableFacturacion.cliente;

    if (currentState.tipoSeleccionado == TipoRequerimiento.reclamoGarantia) {
      if (currentState.tipoGarantia == TipoGarantia.maquinaNueva) {
        responsableAsignado = ResponsableFacturacion.agrispotsa;
      } else if (currentState.tipoGarantia == TipoGarantia.servicio) {
        responsableAsignado = ResponsableFacturacion.tallerInterno;
      }
    }

    final bool? operadorConfirma = await showDialog<bool>(
      context: context,
      barrierDismissible: false, 
      builder: (context) => ConfirmacionIngresoDialog(esRegistroCompleto: esRegistroCompleto),
    );

    if (operadorConfirma != true) return;
    if (!mounted) return;

    final authState = context.read<AuthBloc>().state;
    String nombreOperario = 'SISTEMA';
    String rolOperario = 'DESCONOCIDO';
    
    if (authState is Authenticated) {
      nombreOperario = authState.usuario.nombre; 
      rolOperario = authState.usuario.rol.name.toUpperCase();
    }

    final double? lecturaHorometro = _horometroController.text.trim().isNotEmpty
        ? double.tryParse(_horometroController.text.trim())
        : null;

    context.read<TicketBloc>().add(CrearTicketEvent(
      sede: _selectedSede ?? Sede.NINGUNO, 
      clienteId: _selectedClienteId!, 
      campamento: _campamentoController.text.trim(),
      nombreContacto: _nombreContactoController.text.trim(),
      telefonoContacto: _telefonoController.text.trim(),
      emailContacto: _emailController.text.trim(),
      equipo: _selectedEquipo!, 
      equipoDetalle: (_selectedEquipo == TipoEquipo.Otros) ? _customEquipoController.text.trim() : null, 
      fallaReportada: _fallaController.text.trim(),
      nombreUsuario: nombreOperario,
      rolUsuario: rolOperario,
      notasRecepcion: _notasController.text.trim(),
      numeroSerie: tieneSerie ? _serieController.text.trim() : null,
      accesoriosRecibidos: _accesoriosSeleccionados.isEmpty ? null : Map<String, bool>.from(_accesoriosSeleccionados), 
      evidencias: List<XFile>.from(_archivosEvidencia), 
      marcaEquipo: _selectedMarca,
      tipoRequerimiento: currentState.tipoSeleccionado,
      lugarAtencion: currentState.lugarAtencion,
      esRegistroCompleto: esRegistroCompleto, 
      tipoGarantia: currentState.tipoGarantia.name,
      resposableFacturacion: responsableAsignado.name,
      horometro: lecturaHorometro,
      evidenciasGarantia: _archivosEvidenciaGarantia.isNotEmpty 
          ? List<XFile>.from(_archivosEvidenciaGarantia) 
          : null,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Nuevo Requerimiento', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text('Autoguardado local activo 💾', style: TextStyle(fontSize: 11, color: Colors.black54)),
          ],
        ),
        elevation: 0, 
        backgroundColor: Colors.white, 
        foregroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined, color: Colors.redAccent),
            tooltip: 'Descartar Borrador',
            onPressed: _confirmarDescartarBorrador,
          ),
        ],
      ),
      body: BlocConsumer<TicketBloc, TicketState>(
        listenWhen: (previous, current) =>
            previous.status != current.status ||
            previous.tipoSeleccionado != current.tipoSeleccionado ||
            previous.lugarAtencion != current.lugarAtencion ||
            previous.tipoGarantia != current.tipoGarantia,
        listener: (context, state) async {
          if (state.status == TicketStatus.error) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.message), backgroundColor: Colors.red));
          } else if (state.status == TicketStatus.operationSuccess) { 
            unawaited(BorradorStorageService.eliminarBorrador(BorradorStorageService.kClaveDraftCreacionTicket));
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Registro Exitoso'), backgroundColor: Colors.green));
            
            final ticketReciente = state.currentTicket;
            final bool esTicketCompleto = ticketReciente != null && ticketReciente.esRegistroCompleto;
            final bool esOperacionEnCampo = state.lugarAtencion == LugarAtencion.campo;

            if (esTicketCompleto && !esOperacionEnCampo && state.pdfBytes != null && state.pdfBytes!.isNotEmpty) {
              await Printing.layoutPdf(
                onLayout: (format) async => state.pdfBytes!,
                name: 'Acta_Ingreso_Directo.pdf',
              );
            }

            if (!context.mounted) return; 
            Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
          } else if (state.status != TicketStatus.loading) {
            _guardarBorrador();
          }
        },
        builder: (context, state) {
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: AbsorbPointer(
                absorbing: state.status == TicketStatus.loading,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Card(
                    elevation: 2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: TicketForm(
                        formKey: _formKey,
                        isProcessing: state.status == TicketStatus.loading,
                        listaClientes: state.clientes,
                        clienteController: _clienteController,
                        campamentoController: _campamentoController,
                        nombreContactoController: _nombreContactoController,
                        emailController: _emailController,
                        telefonoController: _telefonoController,
                        fallaController: _fallaController,
                        customEquipoController: _customEquipoController,
                        serieController: _serieController,
                        notasRecepcionController: _notasController,
                        horometroController: _horometroController,
                        onAddMedia: _abrirSelectorMultimedia,
                        archivosGarantia: _archivosEvidenciaGarantia,
                        onRemoveArchivoGarantia: (index) {
                          setState(() {
                            _archivosEvidenciaGarantia.removeAt(index);
                          });
                          _guardarBorrador();
                        },
                        selectedSede: _selectedSede,
                        selectedEquipo: _selectedEquipo,
                        selectedClienteId: _selectedClienteId,
                        prioridadSeleccionada: _prioridad,
                        accesoriosSeleccionados: _accesoriosSeleccionados,
                        archivosEvidencia: _archivosEvidencia,
                        tipoRequerimiento: state.tipoSeleccionado,
                        lugarAtencion: state.lugarAtencion,
                        tipoGarantia: state.tipoGarantia,
                        marcaSeleccionada: _selectedMarca,
                        onMarcaChanged: (val) {
                          setState(() => _selectedMarca = val);
                          _guardarBorrador();
                        },
                        onSedeChanged: (val) {
                          setState(() => _selectedSede = val);
                          _guardarBorrador();
                        },
                        onEquipoChanged: (val) {
                          setState(() {
                            _selectedEquipo = val;
                            if (val != TipoEquipo.Otros) _customEquipoController.clear();
                          });
                          _guardarBorrador();
                        },
                        onClienteSelected: (seleccion) {
                          setState(() {
                            _selectedClienteId = seleccion.camaronera;
                            _clienteController.text = seleccion.camaronera;
                            _campamentoController.text = seleccion.direccion;
                            _nombreContactoController.text = seleccion.nombreContacto;
                            _emailController.text = seleccion.emailContacto;
                            _telefonoController.text = seleccion.celular;
                          });
                          _guardarBorrador();
                        },
                        onClienteCleared: () {
                          setState(() => _selectedClienteId = null);
                          _guardarBorrador();
                        },
                        onPrioridadChanged: (val) {
                          setState(() => _prioridad = val);
                          _guardarBorrador();
                        },
                        onAccesorioChanged: (pieza, valor) {
                          setState(() => _accesoriosSeleccionados[pieza] = valor);
                          _guardarBorrador();
                        },
                        onArchivosActualizados: (archivos) {
                          setState(() {
                            _archivosEvidencia.clear();
                            _archivosEvidencia.addAll(archivos);
                          });
                          _guardarBorrador();
                        },
                        onSubmit: _submitForm, 
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
