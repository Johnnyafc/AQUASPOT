// lib/features/tickets/presentation/widgets/tabla_desplazable_widget.dart
//
// 📱 Tablas en el celular: si no hay espacio para [anchoMinimo], la tabla
// conserva ese ancho y se desplaza de lado (en vez de partir los códigos
// letra por letra). En pantallas anchas ocupa todo el ancho, como antes.

import 'package:flutter/material.dart';

class TablaDesplazableWidget extends StatelessWidget {
  final Widget child;
  final double anchoMinimo;

  const TablaDesplazableWidget({super.key, required this.child, this.anchoMinimo = 560});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      if (c.maxWidth >= anchoMinimo) return child;
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(width: anchoMinimo, child: child),
      );
    });
  }
}
