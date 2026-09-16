// lib/core/theme/ticket_visual_theme.dart
//
// 🎨 PALETA ÚNICA para tarjetas y bandejas de tickets en toda la app.
//
// ⚙️ POR QUÉ EXISTE ESTE ARCHIVO
// Antes, cada bandeja (12 pantallas) y el Historial elegían sus propios
// colores para chips, íconos, avatares y insignias — cada pantalla con su
// propia paleta, sin relación entre ellas, y casi siempre como RELLENO
// SÓLIDO y muy saturado (ej. un círculo naranja/verde/marrón/teal entero).
// El resultado, con las tarjetas mostrando cada vez más datos (equipo,
// cliente, contacto, proyecto, falla, tiempo en vivo), era "ruido visual":
// demasiados colores fuertes compitiendo por la atención sin que ninguno
// signifique realmente algo distinto.
//
// Con este archivo:
//   1) el color deja de ser decorativo — se reserva para lo que de verdad
//      importa: el estado del ticket, y una sola acción/alerta por
//      pantalla;
//   2) en vez de relleno sólido ("chip naranja con texto blanco"), se usa
//      una insignia SUAVE (fondo del color muy diluido + texto/ícono en el
//      color puro) — el mismo color, mucho menos "grito";
//   3) todo lo que es solo un dato (ícono de "equipo", "cliente", etc.) usa
//      un único gris azulado neutro, en vez de un color distinto por
//      pantalla;
//   4) si mañana hay que ajustar un tono, se cambia en un solo lugar en vez
//      de en 13 archivos.

import 'package:flutter/material.dart';
import '../enum/ticket_enums.dart';

// ---------------------------------------------------------------------------
// 🖋️ NEUTROS — para todo lo que es solo un dato, no una alerta ni una acción.
// ---------------------------------------------------------------------------
const Color kTicketTextoPrincipal = Color(0xFF1F2937); // casi negro, cálido
const Color kTicketTextoSecundario = Color(0xFF6B7280); // gris medio
const Color kTicketIcono = Color(0xFF8A97A8); // gris azulado — TODOS los íconos de dato (equipo/cliente/contacto/proyecto) usan este mismo tono

// ---------------------------------------------------------------------------
// 🎯 ACENTO ÚNICO DE MARCA — mismo teal que ya usa el Dashboard, para que
// botones primarios e insignias "en proceso" se sientan parte de una sola
// app, no de 13 pantallas con paletas distintas.
// ---------------------------------------------------------------------------
const Color kTicketAcento = Color(0xFF0F6E6B);

// ---------------------------------------------------------------------------
// 🚦 SEMÁFORO — solo para lo que de verdad es una alerta, una confirmación o
// un rechazo. No decorativo: si aparece este color, algo real está pasando.
// ---------------------------------------------------------------------------
const Color kTicketExito = Color(0xFF2F8F6B); // finalizado / aprobado
const Color kTicketAlerta = Color(0xFFC98A2E); // pendiente / advertencia
const Color kTicketError = Color(0xFFC0503C); // anulado / rechazo

// ---------------------------------------------------------------------------
// 🔧 Un solo color por grupo de ESTADO (antes: 12 colores muy saturados y
// sin relación entre sí, uno por cada EstadoTicket). Con solo 4 grupos
// semánticos (nuevo / en proceso / finalizado / anulado), Historial —que
// mezcla tickets en cualquier estado en una misma pantalla— deja de verse
// como un arcoíris: el texto del estado (ej. "COMPRAS", "BODEGA") sigue
// siendo distinto ticket a ticket, pero el color ya no compite por
// atención en cada tarjeta.
// ---------------------------------------------------------------------------
Color colorPorEstadoTicket(EstadoTicket estado) {
  switch (estado) {
    case EstadoTicket.finalizado:
      return kTicketExito;
    case EstadoTicket.anulado:
      return kTicketError;
    case EstadoTicket.creado:
      return kTicketTextoSecundario;
    default:
      return kTicketAcento; // todos los pasos intermedios comparten un solo acento
  }
}

// ---------------------------------------------------------------------------
// 🏷️ INSIGNIA SUAVE — reemplaza el patrón de "relleno sólido + texto
// blanco" por "fondo diluido + texto/ícono en el color puro". Mismo color,
// mucho menos saturación visual. Se usa para chips de estado, badges de
// "pendiente", etc. en toda la app.
// ---------------------------------------------------------------------------
class InsigniaSuave extends StatelessWidget {
  final Color color;
  final String texto;
  final IconData? icono;
  final double tamanoTexto;

  const InsigniaSuave({
    super.key,
    required this.color,
    required this.texto,
    this.icono,
    this.tamanoTexto = 11,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icono != null) ...[
            Icon(icono, color: color, size: 12),
            const SizedBox(width: 4),
          ],
          Text(
            texto,
            style: TextStyle(color: color, fontSize: tamanoTexto, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// ⭕ AVATAR SUAVE — reemplaza el círculo de relleno sólido (ej. un círculo
// naranja entero con un ícono blanco) por un círculo de fondo diluido con
// el ícono en el color puro. Mismo propósito (identificar de un vistazo el
// tipo de tarjeta), mucho menos "grito".
// ---------------------------------------------------------------------------
class AvatarSuave extends StatelessWidget {
  final Color color;
  final IconData icono;
  final double radio;

  const AvatarSuave({
    super.key,
    required this.color,
    required this.icono,
    this.radio = 20,
  });

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radio,
      backgroundColor: color.withOpacity(0.12),
      child: Icon(icono, color: color, size: radio * 0.9),
    );
  }
}
