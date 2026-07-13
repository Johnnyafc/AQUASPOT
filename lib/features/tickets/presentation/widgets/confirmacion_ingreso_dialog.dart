import 'package:flutter/material.dart';

class ConfirmacionIngresoDialog extends StatelessWidget {
  final bool esRegistroCompleto;

  const ConfirmacionIngresoDialog({
    super.key,
    required this.esRegistroCompleto,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
          const SizedBox(width: 8),
          // ⚙️ AMORTIGUADOR VISUAL: Previene el desbordamiento en pantallas pequeñas
          const Flexible(
            child: Text(
              'Confirmar Ingreso', 
              style: TextStyle(fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      content: RichText(
        text: TextSpan(
          style: const TextStyle(color: Colors.black87, fontSize: 16, height: 1.5),
          children: [
            const TextSpan(text: 'El reporte técnico actual ha sido categorizado como:\n\n'),
            TextSpan(
              text: esRegistroCompleto ? '✅ REGISTRO COMPLETO' : '⚠️ REGISTRO INCOMPLETO',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 18,
                color: esRegistroCompleto ? Colors.green[700] : Colors.deepOrange,
              ),
            ),
            const TextSpan(text: '\n\n¿Está seguro que desea transmitir estos datos al sistema central?'),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('NO, CANCELAR', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF005A9C),
            elevation: 2, // ⚙️ Ligero relieve para mejorar la interacción táctil (Hitbox)
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('SÍ, TRANSMITIR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}