# Tarea: Agregar Fallas a Tickets Antiguos (Aquaspot Postventa)

Proyecto Flutter/Firebase. Repo: `https://github.com/Johnnyafc/AQUASPOT.git`, rama `aquaspot_optimizado`.
Carpeta raíz del proyecto en disco: `aquaspot_postventa/`.

## Qué hace esta funcionalidad

Agrega una tarjeta nueva en el menú principal, visible SOLO para el rol `supervisor` (y `admin`), que lista los tickets antiguos que todavía no tienen diagnóstico de fallas registrado (`ticket.diagnosticoFallas` vacío), filtrados por el segmento operativo del supervisor logueado (caracol/cosechadora/contador). Al tocar un ticket, se abre un selector categoría→subcategoría→falla, y al guardar dispara el evento `GuardarDiagnosticoFallasEvent`, que ya existía completo en `ticket_bloc.dart` pero nunca se usaba desde ninguna pantalla.

Hay que tocar **3 archivos**: 2 nuevos y 1 existente modificado.

---

## 1. ARCHIVO NUEVO: `lib/features/tickets/presentation/pages/bandeja_fallas_pendientes_page.dart`

Crear este archivo con el siguiente contenido completo:

```dart
// lib/features/tickets/presentation/pages/bandeja_fallas_pendientes_page.dart
//
// 🆕 Tarjeta de supervisión: lista los tickets antiguos que aún NO tienen
// diagnóstico de fallas registrado (ticket.diagnosticoFallas vacío), para
// que el supervisor los complete retroactivamente. Filtrado por el mismo
// segmento operativo del supervisor logueado (caracol/cosechadora/contador),
// igual que el resto de bandejas de supervisión (ver bandeja_revisiones_garantias_page.dart).

import 'package:aquaspot_postventa/core/enum/segmento_operativo.dart';
import 'package:aquaspot_postventa/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:aquaspot_postventa/features/auth/presentation/bloc/auth_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/ticket_bloc.dart';
import '../bloc/ticket_event.dart';
import '../bloc/ticket_state.dart';
import '../../../../core/theme/ticket_visual_theme.dart';
import 'agregar_diagnostico_falla_page.dart';

class BandejaFallasPendientesPage extends StatefulWidget {
  const BandejaFallasPendientesPage({super.key});

  @override
  State<BandejaFallasPendientesPage> createState() => _BandejaFallasPendientesPageState();
}

class _BandejaFallasPendientesPageState extends State<BandejaFallasPendientesPage> {
  @override
  void initState() {
    super.initState();

    // 1. EXTRAEMOS EL SEGMENTO DEL SUPERVISOR LOGUEADO
    final authState = context.read<AuthBloc>().state;
    SegmentoOperativo segmentoActivo = SegmentoOperativo.ninguno;

    if (authState is Authenticated) {
      segmentoActivo = authState.usuario.segmento;
    } else {
      debugPrint("⚠️ ALERTA: Intento de acceso sin autenticación en panel de fallas pendientes.");
    }

    // 2. DISPARAMOS EL EVENTO CON EL SEGMENTO ASIGNADO (misma partición que el resto de bandejas de supervisión)
    context.read<TicketBloc>().add(ObtenerHistorialTicketsEvent(segmento: segmentoActivo));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Fallas Pendientes por Diagnosticar"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: BlocBuilder<TicketBloc, TicketState>(
        builder: (context, state) {
          if (state.status == TicketStatus.loading) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(state.message.isNotEmpty ? state.message : 'Consultando tickets pendientes...', style: const TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          if (state.status == TicketStatus.error) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Text("Falla de sistema:\n${state.message}", textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
              ),
            );
          }

          if (state.status == TicketStatus.loaded || state.status == TicketStatus.operationSuccess) {
            // ✅ FILTRO: solo tickets sin diagnóstico de fallas registrado aún
            final pendientes = state.historial.where((t) => t.diagnosticoFallas.isEmpty).toList();

            if (pendientes.isEmpty) {
              return const Center(child: Text("No hay tickets pendientes de diagnóstico de fallas.", style: TextStyle(color: Colors.grey)));
            }

            return ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: pendientes.length,
              itemBuilder: (context, index) {
                final ticket = pendientes[index];
                return Card(
                  key: ValueKey(ticket.id),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: Colors.grey.shade300, width: 1),
                  ),
                  child: ListTile(
                    leading: const AvatarSuave(color: kTicketAlerta, icono: Icons.troubleshoot),
                    title: Text(ticket.id, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                      'Equipo: ${ticket.equipo.name.toUpperCase()} • Marca: ${ticket.marca.toUpperCase()}'
                      '${ticket.clienteId.trim().isNotEmpty ? '\nCliente: ${ticket.clienteId}' : ''}'
                      '\nContacto: ${ticket.nombreContacto}'
                      '\nEstado: ${ticket.estadoActual.name}',
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => AgregarDiagnosticoFallaPage(ticket: ticket)));
                    },
                  ),
                );
              },
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }
}
```

---

## 2. ARCHIVO NUEVO: `lib/features/tickets/presentation/pages/agregar_diagnostico_falla_page.dart`

Crear este archivo con el siguiente contenido completo:

```dart
// lib/features/tickets/presentation/pages/agregar_diagnostico_falla_page.dart
//
// 🆕 Pantalla de carga retroactiva de diagnóstico de fallas para tickets
// antiguos. Reutiliza el mismo árbol categoría > subcategoría > falla que
// ya existe en subir_evidencia_trabajo_page.dart (_mostrarModalDiagnosticoFallas),
// pero como pantalla completa en vez de modal, y dispara por primera vez
// el evento GuardarDiagnosticoFallasEvent (ya existía en el bloc, nunca
// se usaba desde ninguna pantalla).

import 'package:aquaspot_postventa/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:aquaspot_postventa/features/auth/presentation/bloc/auth_state.dart';
import 'package:aquaspot_postventa/features/fallas/data/datasources/metrica_falla_remote_datasource.dart';
import 'package:aquaspot_postventa/features/fallas/domain/entities/metrica_falla_entity.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/ticket_bloc.dart';
import '../bloc/ticket_event.dart';
import '../bloc/ticket_state.dart';
import '../../domain/entities/ticket_entity.dart';

class AgregarDiagnosticoFallaPage extends StatefulWidget {
  final TicketEntity ticket;
  const AgregarDiagnosticoFallaPage({super.key, required this.ticket});

  @override
  State<AgregarDiagnosticoFallaPage> createState() => _AgregarDiagnosticoFallaPageState();
}

class _AgregarDiagnosticoFallaPageState extends State<AgregarDiagnosticoFallaPage> {
  final MetricaFallaRemoteDataSource _fallasDataSource = MetricaFallaRemoteDataSource();
  late List<DiagnosticoFallaEntity> _seleccionadas;

  @override
  void initState() {
    super.initState();
    _seleccionadas = List<DiagnosticoFallaEntity>.from(widget.ticket.diagnosticoFallas);
  }

  void _guardar() {
    if (_seleccionadas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona al menos una falla antes de guardar.'), backgroundColor: Colors.orange),
      );
      return;
    }

    final authState = context.read<AuthBloc>().state;
    String nombreUsuario = 'SISTEMA';
    String rolUsuario = 'DESCONOCIDO';
    if (authState is Authenticated) {
      nombreUsuario = authState.usuario.nombre;
      rolUsuario = authState.usuario.rol.name.toUpperCase();
    }

    context.read<TicketBloc>().add(
      GuardarDiagnosticoFallasEvent(
        ticket: widget.ticket,
        fallas: _seleccionadas,
        nombreUsuario: nombreUsuario,
        rolUsuario: rolUsuario,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<TicketBloc, TicketState>(
      listenWhen: (previous, current) =>
          previous.status != current.status &&
          (current.status == TicketStatus.operationSuccess || current.status == TicketStatus.error),
      listener: (context, state) {
        if (state.status == TicketStatus.operationSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message.isNotEmpty ? state.message : 'Diagnóstico guardado.'), backgroundColor: Colors.green),
          );
          Navigator.pop(context);
        } else if (state.status == TicketStatus.error) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message.isNotEmpty ? state.message : 'No se pudo guardar el diagnóstico.'), backgroundColor: Colors.red),
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('Diagnóstico de Fallas: ${widget.ticket.equipo.name}'),
          backgroundColor: const Color(0xFF003057),
          foregroundColor: Colors.white,
        ),
        body: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: const Color(0xFFF1F5F9),
              child: Text('Ticket ${widget.ticket.id}', style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF003057))),
            ),
            Expanded(
              child: StreamBuilder<MatrizFallasEquipoEntity>(
                stream: _fallasDataSource.escucharMatrizEquipo(widget.ticket.equipo.name),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final matriz = snapshot.data!;
                  final categorias = matriz.categorias;

                  if (categorias.isEmpty) {
                    return const Center(
                      child: Text('No hay catálogo de fallas configurado para este equipo.'),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: categorias.length,
                    itemBuilder: (context, catIdx) {
                      final cat = categorias[catIdx];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 1,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(color: Colors.grey.shade300),
                        ),
                        child: ExpansionTile(
                          initiallyExpanded: true,
                          title: Text(
                            cat.nombre,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: Color(0xFF003057),
                            ),
                          ),
                          children: [
                            if (cat.subcategorias.isEmpty)
                              const Padding(
                                padding: EdgeInsets.all(12.0),
                                child: Text(
                                  'Sin componentes configurados en esta categoría.',
                                  style: TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic),
                                ),
                              )
                            else
                              ...cat.subcategorias.map((sub) {
                                return Container(
                                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF9FBFC),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.blueGrey.shade100),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: Colors.blueGrey.shade50,
                                          borderRadius: const BorderRadius.vertical(top: Radius.circular(7)),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.device_hub, size: 15, color: Color(0xFF003057)),
                                            const SizedBox(width: 6),
                                            Text(
                                              sub.nombre,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                                color: Color(0xFF003057),
                                              ),
                                            ),
                                            const Spacer(),
                                            Text(
                                              '${sub.fallas.length} fallas',
                                              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (sub.fallas.isEmpty)
                                        const Padding(
                                          padding: EdgeInsets.all(8.0),
                                          child: Text(
                                            'Sin fallas definidas en este componente.',
                                            style: TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic),
                                          ),
                                        )
                                      else
                                        ...sub.fallas.map((falla) {
                                          final isChecked = _seleccionadas.any(
                                            (f) =>
                                                f.categoria == cat.nombre &&
                                                f.subcategoria == sub.nombre &&
                                                f.falla == falla,
                                          );

                                          return CheckboxListTile(
                                            dense: true,
                                            value: isChecked,
                                            title: Text(falla, style: const TextStyle(fontSize: 13)),
                                            activeColor: Colors.deepOrange,
                                            onChanged: (val) {
                                              setState(() {
                                                if (val == true) {
                                                  _seleccionadas.add(DiagnosticoFallaEntity(
                                                    categoria: cat.nombre,
                                                    subcategoria: sub.nombre,
                                                    falla: falla,
                                                  ));
                                                } else {
                                                  _seleccionadas.removeWhere(
                                                    (f) =>
                                                        f.categoria == cat.nombre &&
                                                        f.subcategoria == sub.nombre &&
                                                        f.falla == falla,
                                                  );
                                                }
                                              });
                                            },
                                          );
                                        }),
                                    ],
                                  ),
                                );
                              }),
                            const SizedBox(height: 6),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    offset: const Offset(0, -2),
                    blurRadius: 5,
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${_seleccionadas.length} fallas seleccionadas',
                        style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.blueGrey),
                      ),
                    ),
                    BlocBuilder<TicketBloc, TicketState>(
                      builder: (context, state) {
                        final guardando = state.status == TicketStatus.loading;
                        return ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepOrange,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: guardando
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.check, size: 18),
                          label: const Text('Guardar Diagnóstico'),
                          onPressed: guardando ? null : _guardar,
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

---

## 3. ARCHIVO EXISTENTE A REEMPLAZAR: `lib/features/auth/presentation/pages/main_menu_page.dart`

Este archivo YA EXISTE en el proyecto. Reemplaza su contenido completo por el siguiente (incluye todo lo que ya tenía, más el import y la tarjeta nueva):

```dart
// lib/features/tickets/presentation/pages/main_menu_page.dart

import 'package:aquaspot_postventa/core/enum/segmento_operativo.dart';
import 'package:aquaspot_postventa/features/clientes/presentation/pages/gestion_clientes_page.dart';
import 'package:aquaspot_postventa/features/clientes/presentation/widgets/registro_cliente_bottom_sheet.dart';
import 'package:aquaspot_postventa/features/tickets/presentation/bloc/ticket_bloc.dart';
import 'package:aquaspot_postventa/features/tickets/presentation/bloc/ticket_event.dart';
import 'package:aquaspot_postventa/features/tickets/presentation/pages/BandejaBodegaPage.dart';
import 'package:aquaspot_postventa/features/tickets/presentation/pages/BandejaCostosPage.dart';
import 'package:aquaspot_postventa/features/tickets/presentation/pages/BandejaProformasEnviadasPage.dart';
import 'package:aquaspot_postventa/features/tickets/presentation/pages/BandejaRecepcionGuaboPage.dart';
import 'package:aquaspot_postventa/features/tickets/presentation/pages/BandejaTrabajosPage.dart';
import 'package:aquaspot_postventa/features/tickets/presentation/pages/ValidacionFacturacionPage.dart';
import 'package:aquaspot_postventa/features/tickets/presentation/pages/bandeja_comercial_Page.dart';
import 'package:aquaspot_postventa/features/tickets/presentation/pages/bandeja_compras_page.dart';
import 'package:aquaspot_postventa/features/tickets/presentation/pages/bandeja_entregas_page.dart';
import 'package:aquaspot_postventa/features/tickets/presentation/pages/bandeja_revisiones_garantias_page.dart';
import 'package:aquaspot_postventa/features/tickets/presentation/pages/bandeja_despacho_bodega_page.dart';
import 'package:aquaspot_postventa/features/tickets/presentation/pages/bandeja_recepcion_bodega_page.dart';
import 'package:aquaspot_postventa/features/inventario/presentation/pages/gestion_stock_bodega_page.dart';
import 'package:aquaspot_postventa/features/catalogo/presentation/pages/gestion_catalogo_actividades_page.dart';
import 'package:aquaspot_postventa/features/tecnicos/presentation/pages/gestion_tecnicos_page.dart';
import 'package:aquaspot_postventa/features/fallas/presentation/pages/gestion_metricas_fallas_page.dart';
import 'package:aquaspot_postventa/features/tickets/presentation/pages/bandeja_fallas_pendientes_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';
import '../../domain/entities/usuario_entity.dart';
import '../../../tickets/presentation/pages/creacion_ticket_page.dart';
import '../../../tickets/presentation/pages/historial_tickets_page.dart';
import '../../../tickets/presentation/pages/bandeja_evaluaciones_page.dart';
import '../../../tickets/presentation/pages/bandeja_recepcion_page.dart';
import '../../../tickets/presentation/pages/biblioteca_documentos_page.dart';
import '../../../../core/enum/rol_usuario.dart';
import '../pages/registro_usuario_page.dart';

class MainMenuPage extends StatefulWidget {
  const MainMenuPage({super.key});

  @override
  State<MainMenuPage> createState() => _MainMenuPageState();
}

class _MainMenuPageState extends State<MainMenuPage> {
  int _selectedIndex = 0;

  void _logout() {
    context.read<AuthBloc>().add(CerrarSesionEvent());
  }

 @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is Unauthenticated) {
          Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
        }
      },
      builder: (context, state) {
        if (state is! Authenticated) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final operador = state.usuario;
        final bool isAdmin = operador.rol == RolUsuario.admin;
        final bool esTecnico = operador.rol == RolUsuario.tecnico;

        // ✅ EL MULTIPLEXOR DE VISTAS 
        // Para técnicos internos, solo se habilita el módulo de recepción sin historial
        final List<Widget> modulosHMI = [
          _InicioView(operador: operador),
          if (!esTecnico) const HistorialTicketsPage(),
        ];

      return Scaffold(
          backgroundColor: const Color(0xFFF4F7F6),
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            title: Text(
              esTecnico
                  ? "Recepción Bodega - Aquaspot"
                  : (_selectedIndex == 1 ? "Panel de Historial" : "Aquaspot"),
              style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
            ),
            actions: [
              // 🚪 Botón directo de cerrar sesión para técnicos
              if (esTecnico)
                IconButton(
                  icon: const Icon(Icons.logout, color: Colors.red),
                  tooltip: 'Cerrar Sesión',
                  onPressed: _logout,
                ),

              // ⚙️ COMPUERTA LÓGICA: Acceso restringido a Comerciales y Administradores
              if (operador.rol.name.toLowerCase() == 'comercial' || isAdmin)
                IconButton(
                  icon: const Icon(Icons.person_add_alt_1, color: Colors.black54), // Color atenuado para no ser invasivo
                  tooltip: 'Registrar Cliente',
                  onPressed: () async {
                    // 🚀 DISPARO DEL BOTTOM SHEET (USANDO EL MÉTODO ESTÁTICO CORREGIDO)
                    // Esto evita el ProviderNotFoundException al inyectar su propio BLoC.
                    await RegistroClienteBottomSheet.show(context);
                  },
                ),
                
              if (!esTecnico)
                IconButton(icon: const Icon(Icons.notifications_none, color: Colors.black), onPressed: () {}),
              Padding(
                padding: const EdgeInsets.only(right: 16.0),
                child: CircleAvatar(
                  backgroundColor: const Color(0xFF005A9C),
                  child: Text(operador.email.isNotEmpty ? operador.email[0].toUpperCase() : 'U', style: const TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
          // ✅ EL CONMUTADOR
          body: IndexedStack(
            index: esTecnico ? 0 : _selectedIndex,
            children: modulosHMI,
          ),
          bottomNavigationBar: esTecnico
              ? SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                    child: SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.logout, size: 20),
                        label: const Text(
                          'Cerrar Sesión',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade700,
                          foregroundColor: Colors.white,
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: _logout,
                      ),
                    ),
                  ),
                )
              : BottomNavigationBar(
            currentIndex: _selectedIndex,
            selectedItemColor: const Color(0xFF005A9C),
            unselectedItemColor: Colors.grey,
            onTap: (index) {
              // 1. Condición de salida (Acción sin cambio de vista)
              if (index == 2) {
                _logout();
                return; // <-- CRÍTICO: Abortamos la ejecución aquí. El estado no se toca.
              }

              // 2. Disparos de eventos específicos por módulo
              if (index == 1) {
                // DISPARO DE ORDEN DE RECARGA GLOBAL
                context.read<TicketBloc>().add(
                  const ObtenerHistorialTicketsEvent(segmento: SegmentoOperativo.ninguno)
                );
              }

              // 3. Mutación de estado controlada (Solo llegará aquí si index es 0 o 1)
              setState(() {
                _selectedIndex = index;
              });
            },
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Inicio'),
              BottomNavigationBarItem(icon: Icon(Icons.history), label: 'Historial'),
              BottomNavigationBarItem(icon: Icon(Icons.exit_to_app), label: 'Salir'),
            ],
          ),
        );
      },
    );
  }
}

// =====================================================================
// SUB-RUTINA 1: PANEL DE INICIO (El Dashboard principal)
// =====================================================================
class _InicioView extends StatelessWidget {
  final UsuarioEntity operador;

  const _InicioView({required this.operador});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Hola, ${operador.rol.name.toUpperCase()}", 
               style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          ..._getModules(context, operador),
        ],
      ),
    );
  }

  List<Widget> _getModules(BuildContext context, UsuarioEntity operador) {
    List<Widget> modules = [];
    final bool isAdmin = operador.rol == RolUsuario.admin;

    // 📚 BIBLIOTECA DE DOCUMENTOS — no disponible para rol técnico
    if (operador.rol != RolUsuario.tecnico) {
      modules.add(_buildCardOption(
        title: 'Biblioteca de Documentos',
        icon: Icons.perm_media_outlined,
        color: Colors.indigo,
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BibliotecaDocumentosPage())),
      ));
    }

    // 🔒 ACCESO EXCLUSIVO PARA SUPER ADMINISTRADORES
    if (isAdmin) {
      modules.add(_buildCardOption(
        title: 'Gestión de Operarios',
        icon: Icons.admin_panel_settings,
        color: Colors.blueGrey, // Color sobrio para módulos administrativos
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RegistroUsuarioPage())),
      ));
    }

    // 🚀 MÓDULOS DE REQUERIMIENTO Y RECEPCIÓN
    if (isAdmin || operador.rol == RolUsuario.requerimiento || operador.rol == RolUsuario.supervisor) {
      modules.add(_buildCardOption(
        title: 'Crear Ticket',
        icon: Icons.add_box,
        color: Colors.blue,
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CreacionTicketPage())),
      ));
    }

    if (isAdmin || operador.rol == RolUsuario.supervisor || operador.rol == RolUsuario.recepcion ) {
      modules.add(_buildCardOption(
        title: 'Tickets',
        icon: Icons.inventory_outlined, 
        color: Colors.teal, 
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BandejaRecepcionPage())),
      ));
    }

    // 🔧 MÓDULOS TÉCNICOS (Reservados para Supervisión y Administración)
    if (isAdmin || operador.rol == RolUsuario.supervisor) {
      modules.add(_buildCardOption(
        title: 'Recepción del Guabo',
        icon: Icons.car_rental,
        color: Colors.lightBlue,
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BandejaRecepcionGuaboPage())),
      ));

      modules.add(_buildCardOption(
        title: 'Evaluaciones Técnicas',
        icon: Icons.handyman,
        color: Colors.orange,
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BandejaEvaluacionesPage())),
      ));

      modules.add(_buildCardOption(
        title: 'Proceso de trabajo',
        icon: Icons.toll,
        color: Colors.orange.shade800,
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BandejaTrabajosPage())),
      ));
    }

    // 📦 MÓDULO DE RECEPCIÓN EN BODEGA
    if (isAdmin ||
        operador.rol == RolUsuario.tecnico ||
        operador.rol == RolUsuario.supervisor) {
      modules.add(_buildCardOption(
        title: 'Recepción Bodega',
        icon: Icons.assignment_turned_in_outlined,
        color: const Color(0xFF00796B),
        onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const BandejaRecepcionBodegaPage())),
      ));
    }

    // 📋 MÓDULOS DE SUPERVISIÓN
    if (isAdmin || operador.rol == RolUsuario.supervisor) {
      modules.add(_buildCardOption(
        title: 'Revisión de garantias',
        icon: Icons.perm_contact_cal_outlined,
        color: Colors.green,
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BandejaRevisionesGarantiasPage())),
      ));

      modules.add(_buildCardOption(
        title: 'Catálogo de Actividades y Repuestos',
        icon: Icons.menu_book,
        color: const Color(0xFF005A9C),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const GestionCatalogoActividadesPage())),
      ));

      modules.add(_buildCardOption(
        title: 'Catálogo de Técnicos',
        icon: Icons.badge_outlined,
        color: const Color(0xFF003057),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const GestionTecnicosPage())),
      ));

      modules.add(_buildCardOption(
        title: 'Métricas de Fallas',
        icon: Icons.troubleshoot_outlined,
        color: Colors.blueGrey.shade700,
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const GestionMetricasFallasPage())),
      ));

      modules.add(_buildCardOption(
        title: 'Agregar Fallas a Tickets Antiguos',
        icon: Icons.playlist_add_check_circle_outlined,
        color: Colors.deepOrange,
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BandejaFallasPendientesPage())),
      ));
    }

    // 💼 MÓDULOS COMERCIALES
    if (isAdmin || operador.rol == RolUsuario.comercial) {
      modules.add(_buildCardOption(
        title: 'Gestión y Edición de Clientes',
        icon: Icons.people_alt,
        color: const Color(0xFF005A9C), 
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const GestionClientesPage())),
      ));

      modules.add(_buildCardOption(
        title: 'Crear proforma',
        icon: Icons.business_center,
        color: Colors.green, 
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BandejaComercialPage())),
      ));
      
      modules.add(_buildCardOption(
        title: 'Proformas enviadas',
        icon: Icons.access_alarm,
        color: Colors.blue, 
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BandejaProformasEnviadasPage())),
      ));

      modules.add(_buildCardOption(
        title: 'Validación entregas comercial',
        icon: Icons.access_alarm,
        color: Colors.blue, 
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BandejaValidacionFacturacionPage())),
      ));

    modules.add(_buildCardOption(
        title: 'Entrega y facturación',
        icon: Icons.access_alarm,
        color: Colors.blue, 
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BandejaEntregasPage())),
      ));
    }

    // 💰 MÓDULOS DE COSTOS
    if (isAdmin || operador.rol == RolUsuario.costos) {
      modules.add(_buildCardOption(
        title: 'Crear proyecto',
        icon: Icons.account_balance_wallet, 
        color: Colors.orange[800]!, 
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BandejaCostosPage())),
      ));
    }

    // 🛒 MÓDULOS DE COMPRAS Y BODEGA
    if (isAdmin || operador.rol == RolUsuario.compras) {
      modules.add(_buildCardOption(
        title: 'Compras',
        icon: Icons.account_balance_wallet, 
        color: Colors.orange[800]!, 
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BandejaComprasPage())),
      ));

      modules.add(_buildCardOption(
        title: 'Validación Bodega (Compras)',
        icon: Icons.factory, 
        color: Colors.blue[800]!, 
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BandejaBodegaPage())),
      ));
    }

    // 📦 MÓDULOS DE BODEGA / DESPACHO
    if (isAdmin || operador.rol == RolUsuario.bodega) {
      modules.add(_buildCardOption(
        title: 'Despacho Bodega',
        icon: Icons.local_shipping_outlined,
        color: const Color(0xFF005A9C),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BandejaDespachoBodegaPage())),
      ));

      modules.add(_buildCardOption(
        title: 'Inventario y Stock Bodega',
        icon: Icons.inventory_2_outlined,
        color: const Color(0xFF2E7D32),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const GestionStockBodegaPage())),
      ));
    }

    return modules;
  } 

  Widget _buildCardOption({required String title, required IconData icon, required Color color, required VoidCallback onTap}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: Icon(icon, color: color, size: 30),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }
}
```

---

## Después de crear/reemplazar los 3 archivos

Desde la carpeta raíz del proyecto (`aquaspot_postventa/`), en una terminal:

```bash
git add lib/features/auth/presentation/pages/main_menu_page.dart lib/features/tickets/presentation/pages/bandeja_fallas_pendientes_page.dart lib/features/tickets/presentation/pages/agregar_diagnostico_falla_page.dart
git commit -m "feat: agregar diagnostico de fallas retroactivo a tickets antiguos (solo supervisor)"
git push origin aquaspot_optimizado
```

**Importante:** estos 2 archivos nuevos y esta modificación de `main_menu_page.dart` NO tocan nada de proceso de trabajo, compras ni bodega (áreas de otro colaborador en este proyecto) — son completamente aislados a esta funcionalidad nueva.

Nota: en la máquina `desktop-se26q63` estos mismos 3 archivos ya están creados/modificados y ya tienen 2 commits locales hechos (`3a593e8` y `7a1652f`) sobre la rama `aquaspot_optimizado`, pendientes solo de `git push` por falta de credenciales interactivas en esa sesión. Si terminas subiéndolos desde otra máquina primero, en `desktop-se26q63` bastará con hacer `git pull` (o descartar esos 2 commits locales si genera conflicto) para quedar sincronizado.
