import 'package:aquaspot_postventa/core/enum/ticket_enums.dart';
import 'package:aquaspot_postventa/features/tickets/presentation/bloc/ticket_bloc.dart';
import 'package:aquaspot_postventa/features/tickets/presentation/bloc/ticket_event.dart';
import 'package:aquaspot_postventa/features/tickets/presentation/bloc/ticket_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SelectorRequerimientoWidget extends StatelessWidget {
  const SelectorRequerimientoWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TicketBloc, TicketState>(
      builder: (context, state) {
        // ⚙️ EL CONMUTADOR DINÁMICO (AnimatedSwitcher)
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (Widget child, Animation<double> animation) {
            return FadeTransition(
                opacity: animation,
                child: SizeTransition(sizeFactor: animation, child: child));
          },
          child: _construirPanel(context, state),
        );
      },
    );
  }

  // ⚙️ EL CEREBRO DEL RENDERIZADO (Máquina de Estados Visual)
  Widget _construirPanel(BuildContext context, TicketState state) {
    // ESTADO 1: Menú Principal (No hay nada seleccionado)
    if (state.tipoSeleccionado == TipoRequerimiento.ninguno) {
      return _menuPrincipal(context);
    }

    // ESTADO 2: Submenú de Lugar (Eligió Reparación/Garantía pero falta el lugar)
    final requiereLugar = state.tipoSeleccionado == TipoRequerimiento.reparacion ||
                          state.tipoSeleccionado == TipoRequerimiento.reclamoGarantia;

    if (requiereLugar && state.lugarAtencion == LugarAtencion.pendiente) {
      return _subMenuLugarAtencion(context, state.tipoSeleccionado);
    }

    // ESTADO 3 (NUEVO): Submenú de Garantía (Si es garantía y ya tiene lugar, pero falta el tipo)
    final esGarantia = state.tipoSeleccionado == TipoRequerimiento.reclamoGarantia;
    
    if (esGarantia && state.tipoGarantia == TipoGarantia.pendiente) {
      return _subMenuTipoGarantia(context, state.lugarAtencion);
    }

    // ESTADO 4: Selección Completada (Mostramos resumen y botón para resetear)
    return _resumenSeleccion(context, state);
  }

  // =========================================================
  // 🧱 MÓDULOS VISUALES (COMPONENTES)
  // =========================================================

  Widget _menuPrincipal(BuildContext context) {
    return Column(
      key: const ValueKey('MenuPrincipal'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Seleccione el Tipo de Requerimiento:',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _BotonOpcion(icono: Icons.settings, texto: 'Venta Repuesto', onTap: () => _seleccionarTipo(context, TipoRequerimiento.ventaRepuesto)),
            _BotonOpcion(icono: Icons.handshake, texto: 'Alquiler/Prueba', onTap: () => _seleccionarTipo(context, TipoRequerimiento.alquilerPrueba)),
            _BotonOpcion(icono: Icons.build, texto: 'Reparación', onTap: () => _seleccionarTipo(context, TipoRequerimiento.reparacion)),
            _BotonOpcion(icono: Icons.gavel, texto: 'Reclamo/Garantía', onTap: () => _seleccionarTipo(context, TipoRequerimiento.reclamoGarantia)),
            _BotonOpcion(icono: Icons.point_of_sale, texto: 'Venta Maquina', onTap: () => _seleccionarTipo(context, TipoRequerimiento.ventaMaquina)),
          ],
        ),
      ],
    );
  }

  Widget _subMenuLugarAtencion(BuildContext context, TipoRequerimiento tipo) {
    final titulo = tipo == TipoRequerimiento.reparacion ? 'Reparación' : 'Garantía';
    return Column(
      key: const ValueKey('SubMenuLugar'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Modalidad para $titulo:',
            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _BotonOpcion(icono: Icons.home_repair_service, texto: 'En Taller', onTap: () => _seleccionarLugar(context, LugarAtencion.taller))),
            const SizedBox(width: 10),
            Expanded(child: _BotonOpcion(icono: Icons.agriculture, texto: 'En Campo', onTap: () => _seleccionarLugar(context, LugarAtencion.campo))),
          ],
        ),
        const SizedBox(height: 10),
        TextButton.icon(
          icon: const Icon(Icons.arrow_back),
          label: const Text('Volver al menú principal'),
          onPressed: () => _resetearTodo(context), // ⚙️ Purgamos la memoria de selecciones
        )
      ],
    );
  }

  // 🚀 NUEVO MÓDULO: Submenú específico para Garantías
  Widget _subMenuTipoGarantia(BuildContext context, LugarAtencion lugar) {
    final strLugar = lugar == LugarAtencion.taller ? 'en Taller' : 'en Campo';
    return Column(
      key: const ValueKey('SubMenuGarantia'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Especifique el tipo de Garantía ($strLugar):', 
            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple)),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _BotonOpcion(icono: Icons.miscellaneous_services, texto: 'De Servicio', onTap: () => _seleccionarTipoGarantia(context, TipoGarantia.servicio))),
            const SizedBox(width: 10),
            Expanded(child: _BotonOpcion(icono: Icons.precision_manufacturing, texto: 'Máquina Nueva', onTap: () => _seleccionarTipoGarantia(context, TipoGarantia.maquinaNueva))),
          ],
        ),
        const SizedBox(height: 10),
        TextButton.icon(
          icon: const Icon(Icons.arrow_back),
          label: const Text('Cambiar Modalidad (Taller/Campo)'),
          // ⚙️ Solo retrocedemos un paso: borramos el lugar y el tipo de garantía queda pendiente
          onPressed: () => _seleccionarLugar(context, LugarAtencion.pendiente),
        )
      ],
    );
  }

  Widget _resumenSeleccion(BuildContext context, TicketState state) {
    // 🧠 Derivación dinámica para inyectar el texto de garantía en el resumen
    String textoGarantia = '';
    if (state.tipoSeleccionado == TipoRequerimiento.reclamoGarantia && state.tipoGarantia != TipoGarantia.pendiente && state.tipoGarantia != TipoGarantia.noAplica) {
       textoGarantia = ' [${state.tipoGarantia.name.toUpperCase()}]';
    }

    return Container(
      key: const ValueKey('Resumen'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.green)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Requerimiento Seleccionado:',
                    style: TextStyle(fontSize: 12, color: Colors.green)),
                Text(
                  '${state.tipoSeleccionado.name.toUpperCase()} ${state.lugarAtencion != LugarAtencion.noAplica && state.lugarAtencion != LugarAtencion.pendiente ? "(${state.lugarAtencion.name.toUpperCase()})" : ""}$textoGarantia',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.blue),
            onPressed: () => _resetearTodo(context), // ⚙️ Reseteo maestro
          )
        ],
      ),
    );
  }

  // =========================================================
  // 🔌 TRANSMISORES AL BLOC
  // =========================================================
  void _seleccionarTipo(BuildContext context, TipoRequerimiento tipo) {
    context.read<TicketBloc>().add(SeleccionarTipoRequerimientoEvent(tipo));
  }

  void _seleccionarLugar(BuildContext context, LugarAtencion lugar) {
    context.read<TicketBloc>().add(SeleccionarLugarAtencionEvent(lugar));
  }

  void _seleccionarTipoGarantia(BuildContext context, TipoGarantia tipo) {
    context.read<TicketBloc>().add(SeleccionarTipoGarantiaEvent(tipo));
  }

  void _resetearTodo(BuildContext context) {
    // ⚠️ Asegúrese de que este evento en su BLoC devuelva tipoRequerimiento, lugarAtencion Y tipoGarantia a sus estados iniciales/pendientes.
    context.read<TicketBloc>().add(ResetearRequerimientoEvent());
  }
}

// ⚙️ Widget auxiliar para no repetir código de botones
class _BotonOpcion extends StatelessWidget {
  final IconData icono;
  final String texto;
  final VoidCallback onTap;

  const _BotonOpcion(
      {required this.icono, required this.texto, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        foregroundColor: Colors.black87,
        backgroundColor: Colors.white,
        elevation: 2,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      icon: Icon(icono, color: const Color(0xFF005A9C)),
      label: Text(texto),
      onPressed: onTap,
    );
  }
}