// lib/features/tickets/presentation/widgets/copy_icon_button_widget.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Botoncito de copiar para un campo de solo lectura.
/// Usa el portapapeles del sistema, así que funciona igual en Android,
/// iOS y Web sin ninguna configuración extra.
class CopyIconButtonWidget extends StatelessWidget {
  final String etiqueta;
  final String valor;

  const CopyIconButtonWidget({
    super.key,
    required this.etiqueta,
    required this.valor,
  });

  @override
  Widget build(BuildContext context) {
    // Si no hay nada que copiar, no mostramos el botón
    if (valor.trim().isEmpty) return const SizedBox.shrink();

    return IconButton(
      icon: const Icon(Icons.copy_rounded, size: 16),
      color: Colors.grey.shade600,
      tooltip: 'Copiar',
      splashRadius: 18,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
      visualDensity: VisualDensity.compact,
      onPressed: () async {
        await Clipboard.setData(ClipboardData(text: valor));
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              etiqueta.endsWith(':')
                  ? '${etiqueta.substring(0, etiqueta.length - 1)} copiado'
                  : '$etiqueta copiado',
            ),
            duration: const Duration(milliseconds: 1200),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
    );
  }
}
