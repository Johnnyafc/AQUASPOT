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

  @override
  void initState() {
    super.initState();
    context.read<TicketBloc>().add(ObtenerClientesEvent());
    _conectarAutoGuardadoBorrador();
    _cargarBorradorLocal();
  }

  void _conectarAutoGuardadoBorrador() {
    _clienteController.addListener(_guardarBorrador);
    _customEquipoController.addListener(_guardarBorrador);
    _campamentoController.addListener(_guardarBorrador);
    _nombreContactoController.addListener(_guardarBorrador);
    _emailController.addListener(_guardarBorrador);
    _telefonoController.addListener(_guardarBorrador);
    _fallaController.addListener(_guardarBorrador);
    _serieController.addListener(_guardarBorrador);
    _notasController.addListener(_guardarBorrador);
    _horometroController.addListener(_guardarBorrador);
  }

  void _desconectarAutoGuardadoBorrador() {
    _clienteController.removeListener(_guardarBorrador);
    _customEquipoController.removeListener(_guardarBorrador);
    _campamentoController.removeListener(_guardarBorrador);
    _nombreContactoController.removeListener(_guardarBorrador);
    _emailController.removeListener(_guardarBorrador);
    _telefonoController.removeListener(_guardarBorrador);
    _fallaController.removeListener(_guardarBorrador);
    _serieController.removeListener(_guardarBorrador);
    _notasController.removeListener(_guardarBorrador);
    _horometroController.removeListener(_guardarBorrador);
  }

  void _guardarBorrador() {
    BorradorStorageService.guardarBorrador(
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
        if (draft['evidenciasPaths'] != null && draft['evidenciasPaths'] is List) {
          final restauradas = BorradorStorageService.pathsToXFiles(draft['evidenciasPaths'] as List);
          _archivosEvidencia.clear();
          _archivosEvidencia.addAll(restauradas);
        }
        if (draft['evidenciasGarantiaPaths'] != null && draft['evidenciasGarantiaPaths'] is List) {
          final restauradas = BorradorStorageService.pathsToXFiles(draft['evidenciasGarantiaPaths'] as List);
          _archivosEvidenciaGarantia.clear();
          _archivosEvidenciaGarantia.addAll(restauradas);
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.restore, color: Colors.white),
              SizedBox(width: 8),
              Expanded(child: Text('Borrador de ticket recuperado automáticamente.')),
            ],
          ),
          backgroundColor: const Color(0xFF005A9C),
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'Descartar',
            textColor: Colors.amber,
            onPressed: () {
              _limpiarFormulario();
            },
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _desconectarAutoGuardadoBorrador();
    // Innegociable: Destrucción de todos los punteros en memoria
    _clienteController.dispose();
    _customEquipoController.dispose();
    _campamentoController.dispose();
    _nombreContactoController.dispose();
    _emailController.dispose();
    _telefonoController.dispose();
    _fallaController.dispose();
    _serieController.dispose();
    _notasController.dispose();
    _horometroController.dispose(); // 🧹 Limpieza del nuevo sensor
    super.dispose();
  }

  void _limpiarFormulario() {
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
    _horometroController.clear(); // 🧹 Purga de la lectura anterior
    
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
    
    context.read<TicketBloc>().add(const SeleccionarTipoRequerimientoEvent(TipoRequerimiento.ninguno));
    _formKey.currentState?.reset();
    BorradorStorageService.eliminarBorrador(BorradorStorageService.kClaveDraftCreacionTicket);
  }

  // 📷 SUBRUTINA DE ACTUADOR MULTIMEDIA
Future<void> _abrirSelectorMultimedia() async {
    try {
      // 1. Instanciamos el módulo de captura
      final ImagePicker picker = ImagePicker();
      
      // 2. Detonamos la interfaz de selección múltiple. 
      // ⚙️ BEST PRACTICE: Compresión de payload al 70% para no saturar el canal de telemetría IoT
      final List<XFile> fotos = await picker.pickMultiImage(
        imageQuality: 70,
      );

      // 3. Verificación de compuerta: Si el operario cancela, no hacemos nada
      if (fotos.isNotEmpty) {
        // 4. Escribimos en el búfer de memoria volátil y refrescamos el HMI
        setState(() {
          _archivosEvidenciaGarantia.addAll(fotos);
        });
        _guardarBorrador();

        // 5. Feedback visual confirming the hardware state change
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ ${fotos.length} archivos de telemetría adjuntados al búfer de garantía.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        print("⚠️ OPERACIÓN ABORTADA: El usuario cerró el sensor óptico sin capturar datos.");
      }
    } catch (e) {
      // 🛑 Manejo de fallos en el bus del sistema operativo (permisos denegados, etc.)
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🛑 Error en el módulo de cámara: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ⚙️ Convertimos la función a asíncrona
  void _submitForm() async {
    // =========================================================
    // 🧠 0. LECTURA DE SENSORES DE ESTADO
    // =========================================================
    final currentState = context.read<TicketBloc>().state;

    // =========================================================
    // 🛑 1. VALIDACIÓN ESTRICTA (Hard Interlocks)
    // =========================================================
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

    // =========================================================
    // 🧠 2. ALGORITMO DE COMPLETITUD Y COSTOS (TRIAGE)
    // =========================================================
    final bool esOperacionEnCampo = currentState.lugarAtencion == LugarAtencion.campo;
    final bool tieneSerie = _serieController.text.trim().isNotEmpty;
    final bool tieneEvidencia = _archivosEvidencia.isNotEmpty;
    
    final bool esRegistroCompleto = esOperacionEnCampo 
        ? tieneSerie 
        : (tieneSerie && tieneEvidencia);
        
    // ⚙️ ENRUTADOR DE FACTURACIÓN AUTOMÁTICA
    ResponsableFacturacion responsableAsignado = ResponsableFacturacion.cliente;

    if (currentState.tipoSeleccionado == TipoRequerimiento.reclamoGarantia) {
      if (currentState.tipoGarantia == TipoGarantia.maquinaNueva) {
        responsableAsignado = ResponsableFacturacion.agrispotsa;
      } else if (currentState.tipoGarantia == TipoGarantia.servicio) {
        responsableAsignado = ResponsableFacturacion.tallerInterno;
      }
    }

    // =========================================================
    // 🛑 3. ENCLAVAMIENTO DE CONFIRMACIÓN MODULAR
    // =========================================================
    final bool? operadorConfirma = await showDialog<bool>(
      context: context,
      barrierDismissible: false, 
      builder: (context) => ConfirmacionIngresoDialog(esRegistroCompleto: esRegistroCompleto),
    );

    if (operadorConfirma != true) return;
    if (!context.mounted) return;

    // =========================================================
    // ⚡ 4. EXTRACCIÓN DE VARIABLES DE ENTORNO Y TRANSMISIÓN
    // =========================================================
    final authState = context.read<AuthBloc>().state;
    String nombreOperario = 'SISTEMA';
    String rolOperario = 'DESCONOCIDO';
    
    if (authState is Authenticated) {
      nombreOperario = authState.usuario.nombre; 
      rolOperario = authState.usuario.rol.name.toUpperCase();
    }
    
    print('El valor es ${responsableAsignado.name}');
    
    // ⚠️ ATENCIÓN INGENIERO: El horómetro está capturando datos. 
    // Asegúrese de actualizar su evento `CrearTicketEvent` en el BLoC para recibir `_horometroController.text`
    // si necesita guardarlo en la base de datos de Firebase.
    
final double? lecturaHorometro = _horometroController.text.trim().isNotEmpty
        ? double.tryParse(_horometroController.text.trim())
        : null;

    // 🚀 DESPACHO DE LA TRAMA DE DATOS AL PLC (BLoC)
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
      
      // ==========================================
      // 🔌 PINES DE TELEMETRÍA Y GARANTÍA CONECTADOS
      // ==========================================
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
        title: const Text('Nuevo Requerimiento', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0, backgroundColor: Colors.white, foregroundColor: Colors.black,
      ),
      body: BlocConsumer<TicketBloc, TicketState>(
        listenWhen: (previous, current) => previous.status != current.status,
        listener: (context, state) async {
          if (state.status == TicketStatus.error) {
             ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.message), backgroundColor: Colors.red));
          } else if (state.status == TicketStatus.operationSuccess) { 
            BorradorStorageService.eliminarBorrador(BorradorStorageService.kClaveDraftCreacionTicket);
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
                        
                        // 🔌 CABLEADO DE NUEVOS PINES (Interlock Agrícola completado)
                        horometroController: _horometroController,
                        onAddMedia: _abrirSelectorMultimedia,
                        
                        // ⚡ TERMINALES DE BÚFER AISLADO REQUERIDOS POR EL FORMULARIO
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
