import 'dart:io'; 
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import '../bloc/ticket_bloc.dart';
import '../bloc/ticket_event.dart';
import '../bloc/ticket_state.dart';
import '../../../../core/enum/ticket_enums.dart'; 
import '../../../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../../../features/auth/presentation/bloc/auth_state.dart';
import '../../domain/entities/cliente_entity.dart';
import '../widgets/ticket_form_widget.dart';
import '../../../clientes/presentation/widgets/registro_cliente_bottom_sheet.dart'; 
import '../widgets/confirmacion_ingreso_dialog.dart';
import 'package:printing/printing.dart';

class CreacionTicketPage extends StatefulWidget {
  const CreacionTicketPage({super.key});

  @override
  State<CreacionTicketPage> createState() => _CreacionTicketPageState();
}

class _CreacionTicketPageState extends State<CreacionTicketPage> {
  final _formKey = GlobalKey<FormState>();
  
  // Banco de Controladores (Controller Bank)
  final TextEditingController _clienteController = TextEditingController();
  final TextEditingController _customEquipoController = TextEditingController();
  final TextEditingController _campamentoController = TextEditingController();
  final TextEditingController _nombreContactoController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _telefonoController = TextEditingController();
  final TextEditingController _fallaController = TextEditingController();
  final TextEditingController _serieController = TextEditingController();
  final TextEditingController _notasController = TextEditingController();

  // Memoria Volátil (Volatile Memory)
  String? _selectedClienteId; 
  Sede? _selectedSede;
  TipoEquipo? _selectedEquipo;
  Prioridad? _prioridad;
  final Map<String, bool> _accesoriosSeleccionados = {};
  final List<XFile> _archivosEvidencia = [];

  @override
  void initState() {
    super.initState();
    context.read<TicketBloc>().add(ObtenerClientesEvent()); 
  }

  @override
  void dispose() {
    _clienteController.dispose();
    _customEquipoController.dispose();
    _campamentoController.dispose();
    _nombreContactoController.dispose();
    _emailController.dispose();
    _telefonoController.dispose();
    _fallaController.dispose();
    _serieController.dispose();
    _notasController.dispose();
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
    
    setState(() {
      _selectedSede = null;
      _selectedEquipo = null;
      _selectedClienteId = null;
      _prioridad = null;
      _accesoriosSeleccionados.clear();
      _archivosEvidencia.clear();
    });
    
    context.read<TicketBloc>().add(const SeleccionarTipoRequerimientoEvent(TipoRequerimiento.ninguno));
    _formKey.currentState?.reset();
  }


 // Este método ahora recibe la señal de completitud como parámetro

 // ⚙️ Convertimos la función a asíncrona
  void _submitForm() async {
    // =========================================================
    // 🛑 1. VALIDACIÓN ESTRICTA (Hard Interlocks)
    // =========================================================
    // Corrección del árbol de validación visual de Flutter
    if (!_formKey.currentState!.validate()) return;

    // Guardas de seguridad explícitas para prevenir NullCheckErrors crónicos
    if (_selectedClienteId == null || _selectedClienteId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('⚠️ Seleccione un Cliente.'), backgroundColor: Colors.orange));
      return;
    }

    if (_selectedSede == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('⚠️ Especifique la Sede Operativa.'), backgroundColor: Colors.orange));
      return;
    }

    if (_selectedEquipo == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('⚠️ Seleccione el Tipo de Equipo.'), backgroundColor: Colors.orange));
      return;
    }

    final currentState = context.read<TicketBloc>().state;
    
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
    // 🧠 2. ALGORITMO DE COMPLETITUD (TRIAGE)
    // =========================================================
    final bool tieneSerie = _serieController.text.trim().isNotEmpty;
    final bool tieneEvidencia = _archivosEvidencia.isNotEmpty;
    
    // Ecuación lógica limpia (eliminamos la variable muerta de prioridad)
    final bool esRegistroCompleto = tieneSerie && tieneEvidencia;
    

    // =========================================================
    // 🛑 3. ENCLAVAMIENTO DE CONFIRMACIÓN MODULAR
    // =========================================================
    // Pausamos el hilo de ejecución hasta recibir señal del pop-up externo
    final bool? operadorConfirma = await showDialog<bool>(
      context: context,
      barrierDismissible: false, 
      builder: (context) => ConfirmacionIngresoDialog(esRegistroCompleto: esRegistroCompleto),
    );

    // Si el operador cancela, cortamos el suministro eléctrico de la función
    if (operadorConfirma != true) return;

    // Verificación obligatoria anti-fugas de memoria en procesos asíncronos
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

    // Despacho de la trama de datos limpia y tipada al BLoC
    context.read<TicketBloc>().add(CrearTicketEvent(
      sede: _selectedSede!, // Ahora es 100% seguro usar el operador !
      clienteId: _selectedClienteId!, 
      campamento: _campamentoController.text.trim(),
      nombreContacto: _nombreContactoController.text.trim(),
      telefonoContacto: _telefonoController.text.trim(),
      emailContacto: _emailController.text.trim(),
      equipo: _selectedEquipo!, // Ahora es 100% seguro usar el operador !
      equipoDetalle: (_selectedEquipo == TipoEquipo.Otros) ? _customEquipoController.text.trim() : null, 
      fallaReportada: _fallaController.text.trim(),
      nombreUsuario: nombreOperario,
      rolUsuario: rolOperario,
      notasRecepcion: _notasController.text.trim(),
      numeroSerie: tieneSerie ? _serieController.text.trim() : null,
      accesoriosRecibidos: _accesoriosSeleccionados.isEmpty ? null : Map<String, bool>.from(_accesoriosSeleccionados), 
      evidencias: List<XFile>.from(_archivosEvidencia), 
      
      tipoRequerimiento: currentState.tipoSeleccionado,
      lugarAtencion: currentState.lugarAtencion,
      esRegistroCompleto: esRegistroCompleto, 
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
          // 🛑 MANEJO DE ERRORES
          if (state.status == TicketStatus.error) {
             ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.message), backgroundColor: Colors.red));
          
          // ✅ MANEJO DE ÉXITO
          } else if (state.status == TicketStatus.operationSuccess) { 
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Registro Exitoso'), backgroundColor: Colors.green));
            
            // ⚙️ COMPUERTA LÓGICA DE SEGURIDAD
            final ticketReciente = state.currentTicket;
            final bool esTicketCompleto = ticketReciente != null && ticketReciente.esRegistroCompleto;

            // 🖨️ INTERLOCK DE IMPRESIÓN
            if (esTicketCompleto && state.pdfBytes != null && state.pdfBytes!.isNotEmpty) {
              await Printing.layoutPdf(
                onLayout: (format) async => state.pdfBytes!,
                name: 'Acta_Ingreso_Directo.pdf',
              );
            }

            // 🚪 EVACUACIÓN DE LA PANTALLA
            // 1. Revisamos que el contexto exista (OBLIGATORIO DESPUÉS DE UN AWAIT)
            if (!context.mounted) return; 
            
            // 2. Demolición de la ruta (NO uses _limpiarFormulario, deja que el Garbage Collector de Flutter libere la RAM)
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
                        selectedSede: _selectedSede,
                        selectedEquipo: _selectedEquipo,
                        selectedClienteId: _selectedClienteId,
                        prioridadSeleccionada: _prioridad,
                        accesoriosSeleccionados: _accesoriosSeleccionados,
                        archivosEvidencia: _archivosEvidencia,
                        tipoRequerimiento: state.tipoSeleccionado,
                        lugarAtencion: state.lugarAtencion,
                        onSedeChanged: (val) => setState(() => _selectedSede = val),
                        onEquipoChanged: (val) => setState(() {
                          _selectedEquipo = val;
                          if (val != TipoEquipo.Otros) _customEquipoController.clear();
                        }),
                        onClienteSelected: (seleccion) => setState(() {
                          _selectedClienteId = seleccion.camaronera;
                          _clienteController.text = seleccion.camaronera;
                          _campamentoController.text = seleccion.direccion;
                          _nombreContactoController.text = seleccion.nombreContacto;
                          _emailController.text = seleccion.emailContacto;
                          _telefonoController.text = seleccion.celular;
                        }),
                        onClienteCleared: () => setState(() => _selectedClienteId = null),
                        onPrioridadChanged: (val) => setState(() => _prioridad = val),
                        onAccesorioChanged: (pieza, valor) => setState(() => _accesoriosSeleccionados[pieza] = valor),
                        onArchivosActualizados: (archivos) => setState(() {
                          _archivosEvidencia.clear();
                          _archivosEvidencia.addAll(archivos);
                        }),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final operacionExitosa = await RegistroClienteBottomSheet.show(context);
          if (operacionExitosa == true && context.mounted) {
            context.read<TicketBloc>().add(ObtenerClientesEvent()); 
          }
        },
        backgroundColor: Colors.orange, foregroundColor: Colors.white, elevation: 4,
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('NUEVO CLIENTE', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
      ),
    );
  }
}