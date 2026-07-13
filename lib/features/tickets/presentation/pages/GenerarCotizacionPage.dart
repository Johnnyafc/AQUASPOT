import 'package:aquaspot_postventa/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:aquaspot_postventa/features/auth/presentation/bloc/auth_state.dart';
import 'package:aquaspot_postventa/features/tickets/domain/entities/ticket_entity.dart';
import 'package:aquaspot_postventa/features/tickets/presentation/bloc/ticket_bloc.dart';
import 'package:aquaspot_postventa/features/tickets/presentation/bloc/ticket_event.dart';
import 'package:aquaspot_postventa/features/tickets/presentation/bloc/ticket_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_picker/file_picker.dart';
import 'package:file_picker/file_picker.dart' as fp;
// Importa tus blocs, entidades y dependencias aquí

class GenerarCotizacionPage extends StatefulWidget {
  final TicketEntity ticket;
  const GenerarCotizacionPage({super.key, required this.ticket});

  @override
  State<GenerarCotizacionPage> createState() => _GenerarCotizacionPageState();
}

class _GenerarCotizacionPageState extends State<GenerarCotizacionPage> {
  final TextEditingController _observacionController = TextEditingController();
final List<fp.PlatformFile> _pdfsSeleccionados = [];
  final List<fp.PlatformFile> _excelsSeleccionados = [];

Future<void> _seleccionarPDFs() async {
    final result = await fp.FilePicker.pickFiles(
      allowMultiple: true, // 🔌 COMPUERTA LÓGICA ABIERTA PARA MÚLTIPLES ARCHIVOS
      type: fp.FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true, 
    );
    if (result != null) {
      setState(() {
        _pdfsSeleccionados.addAll(result.files);
      });
    }
  }

  Future<void> _seleccionarExcels() async {
    final result = await fp.FilePicker.pickFiles(
      allowMultiple: true, // 🔌 COMPUERTA LÓGICA ABIERTA
      type: fp.FileType.custom,
      allowedExtensions: ['xls', 'xlsx'],
      withData: true,
    );
    if (result != null) {
      setState(() {
        _excelsSeleccionados.addAll(result.files);
      });
    }
  }

  void _eliminarArchivo(List<fp.PlatformFile> lista, fp.PlatformFile archivo) {
    setState(() {
      lista.remove(archivo);
    });
  }

void _finalizarCotizacion() {
    // ⚙️ VALIDACIÓN DE TOLVA: Revisamos si ambos arreglos están vacíos
    if (_pdfsSeleccionados.isEmpty && _excelsSeleccionados.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La tolva documental está vacía. Adjunte al menos un archivo.'), 
          backgroundColor: Colors.red
        ),
      );
      return;
    }

    // 🔒 LECTURA DE SEGURIDAD
    final authState = context.read<AuthBloc>().state;
    String operador = 'DESCONOCIDO';
    String rol = 'SIN_ROL';

    if (authState is Authenticated) {
      operador = authState.usuario.nombre;
      rol = authState.usuario.rol.name.toUpperCase();
    }

    // 🚀 DISPARO HACIA EL BLOC (Señal Múltiple)
    context.read<TicketBloc>().add(
      ProcesarCotizacionEvent(
        ticket: widget.ticket,
        archivosPdf: _pdfsSeleccionados, // 🔌 Pasamos el arreglo completo
        archivosExcel: _excelsSeleccionados, // 🔌 Pasamos el arreglo completo
        observacion: _observacionController.text.trim(),
        nombreUsuario: operador,
        rolUsuario: rol,
      ),
    );
  }

 @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Cotización: ${widget.ticket.id}'), backgroundColor: Colors.green),
      body: BlocListener<TicketBloc, TicketState>(
       listener: (context, state) {
          if (state.status == TicketStatus.operationSuccess) { // O operationSuccess, el que uses
            // 1. ALARMA VISUAL (Operación exitosa)
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Cotización registrada. Sincronizando SCADA...'), 
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              )
            );
            
            // 2. PULSO DE RECARGA (Actualiza la memoria del BLoC en segundo plano)
            context.read<TicketBloc>().add(const ObtenerTicketsEvent()); 
            
            // 3. RETORNO SEGURO O(1) (Cierra la válvula y desapila la pantalla actual)
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            }
          } 
          
          // 🚨 MANEJO DE FALLOS INDEPENDIENTE
          else if (state.status == TicketStatus.error) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message), backgroundColor: Colors.red)
            );
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ListView(
            children: [
              // PANEL DE DOCUMENTOS MULTIPLES
              Card(
                elevation: 3,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Carga Documental Comercial', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      const Divider(),
                      
                      // 📁 SECCIÓN PDF
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Archivos PDF', style: TextStyle(fontWeight: FontWeight.w600)),
                          ElevatedButton.icon(
                            onPressed: _seleccionarPDFs, 
                            icon: const Icon(Icons.add), 
                            label: const Text('Añadir PDF')
                          ),
                        ],
                      ),
                      if (_pdfsSeleccionados.isEmpty)
                        const Padding(padding: EdgeInsets.symmetric(vertical: 8.0), child: Text('Sin PDFs cargados.', style: TextStyle(color: Colors.grey))),
                      ..._pdfsSeleccionados.map((file) => ListTile(
                        dense: true,
                        leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
                        title: Text(file.name, overflow: TextOverflow.ellipsis),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                          onPressed: () => _eliminarArchivo(_pdfsSeleccionados, file),
                        ),
                      )),
                      
                      const Divider(height: 30),

                      // 📊 SECCIÓN EXCEL
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Archivos Excel', style: TextStyle(fontWeight: FontWeight.w600)),
                          ElevatedButton.icon(
                            onPressed: _seleccionarExcels, 
                            icon: const Icon(Icons.add), 
                            label: const Text('Añadir Excel')
                          ),
                        ],
                      ),
                      if (_excelsSeleccionados.isEmpty)
                        const Padding(padding: EdgeInsets.symmetric(vertical: 8.0), child: Text('Sin Excels cargados.', style: TextStyle(color: Colors.grey))),
                      ..._excelsSeleccionados.map((file) => ListTile(
                        dense: true,
                        leading: const Icon(Icons.table_chart, color: Colors.green),
                        title: Text(file.name, overflow: TextOverflow.ellipsis),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                          onPressed: () => _eliminarArchivo(_excelsSeleccionados, file),
                        ),
                      )),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              
              // PANEL DE OBSERVACIONES
              TextField(
                controller: _observacionController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Observaciones Comerciales',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.comment),
                ),
              ),
              const SizedBox(height: 30),
              
              // BOTÓN ACTUADOR
              BlocBuilder<TicketBloc, TicketState>(
                builder: (context, state) {
                  if (state.status == TicketStatus.loading) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  return ElevatedButton.icon(
                    onPressed: _finalizarCotizacion,
                    icon: const Icon(Icons.check_circle),
                    label: const Text('FINALIZAR Y ENVIAR COTIZACIÓN', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}