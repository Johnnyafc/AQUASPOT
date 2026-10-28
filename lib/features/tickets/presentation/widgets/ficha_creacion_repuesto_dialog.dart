// lib/features/tickets/presentation/widgets/ficha_creacion_repuesto_dialog.dart
//
// 🧾 Diálogo con la ficha "Plantilla solicitud creación de códigos" (los
// mismos campos que en la Evaluación de Venta). Lo llena el técnico para
// cada repuesto SIN CÓDIGO; Costos crea el código en el ERP con estos datos.
// Devuelve la ficha o null si se cancela. Obligatorios (*): nombre,
// familia, categoría y UDM (FichaCreacionRepuestoEntity.faltantes).

import 'package:flutter/material.dart';
import '../../domain/entities/ficha_creacion_repuesto_entity.dart';

class FichaCreacionRepuestoDialog extends StatefulWidget {
  final FichaCreacionRepuestoEntity inicial;
  final String titulo;

  const FichaCreacionRepuestoDialog({super.key, required this.inicial, required this.titulo});

  static Future<FichaCreacionRepuestoEntity?> mostrar(
    BuildContext context, {
    required FichaCreacionRepuestoEntity inicial,
    required String titulo,
  }) =>
      showDialog<FichaCreacionRepuestoEntity>(
        context: context,
        barrierDismissible: false,
        builder: (_) => FichaCreacionRepuestoDialog(inicial: inicial, titulo: titulo),
      );

  @override
  State<FichaCreacionRepuestoDialog> createState() => _FichaCreacionRepuestoDialogState();
}

class _FichaCreacionRepuestoDialogState extends State<FichaCreacionRepuestoDialog> {
  late final Map<String, TextEditingController> _texto;
  late bool _comprado, _vendido, _activo, _almacenado, _gravaIva, _fabricado;

  /// Campos de texto: clave → etiqueta (en el orden de la plantilla).
  static const Map<String, String> _etiquetas = {
    'nombre': 'Nombre *',
    'familiaPieza': 'Familia de pieza *',
    'tipo': 'Tipo',
    'atributoAcabado': 'Atributo o acab.',
    'metrica': 'Métrica',
    'equivalencia': 'Equivalencia',
    'categoria': 'Categoría *',
    'udm': 'UDM *',
    'tipoProducto': 'Tipo producto',
    'linkImagen': 'Link imagen',
    'linkDescripcion': 'Link descripción',
  };

  @override
  void initState() {
    super.initState();
    final f = widget.inicial;
    final valores = {
      'nombre': f.nombre,
      'familiaPieza': f.familiaPieza,
      'tipo': f.tipo,
      'atributoAcabado': f.atributoAcabado,
      'metrica': f.metrica,
      'equivalencia': f.equivalencia,
      'categoria': f.categoria,
      'udm': f.udm,
      'tipoProducto': f.tipoProducto,
      'linkImagen': f.linkImagen,
      'linkDescripcion': f.linkDescripcion,
    };
    _texto = {for (final k in _etiquetas.keys) k: TextEditingController(text: valores[k])};
    _comprado = f.comprado;
    _vendido = f.vendido;
    _activo = f.activo;
    _almacenado = f.almacenado;
    _gravaIva = f.gravaIva;
    _fabricado = f.fabricado;
  }

  @override
  void dispose() {
    for (final c in _texto.values) {
      c.dispose();
    }
    super.dispose();
  }

  FichaCreacionRepuestoEntity get _ficha {
    String t(String k) => _texto[k]!.text.trim();
    return FichaCreacionRepuestoEntity(
      nombre: t('nombre').toUpperCase(),
      familiaPieza: t('familiaPieza'),
      tipo: t('tipo'),
      atributoAcabado: t('atributoAcabado'),
      metrica: t('metrica'),
      equivalencia: t('equivalencia'),
      categoria: t('categoria'),
      udm: t('udm'),
      tipoProducto: t('tipoProducto'),
      linkImagen: t('linkImagen'),
      linkDescripcion: t('linkDescripcion'),
      comprado: _comprado,
      vendido: _vendido,
      activo: _activo,
      almacenado: _almacenado,
      gravaIva: _gravaIva,
      fabricado: _fabricado,
    );
  }

  Widget _casilla(String etiqueta, bool valor, ValueChanged<bool> cambiar) => FilterChip(
        label: Text('$etiqueta: ${valor ? 'SI' : 'NO'}'),
        selected: valor,
        onSelected: (v) => setState(() => cambiar(v)),
      );

  @override
  Widget build(BuildContext context) {
    final faltan = _ficha.faltantes;
    return AlertDialog(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Plantilla solicitud creación de código', style: TextStyle(fontSize: 17)),
          const SizedBox(height: 4),
          Text(widget.titulo, style: TextStyle(fontSize: 13, color: Colors.orange.shade900)),
        ],
      ),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Este repuesto no está en el inventario: Costos creará el código con estos datos. (*) obligatorio.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final e in _etiquetas.entries)
                    SizedBox(
                      width: e.key == 'nombre' || e.key.startsWith('link') ? 540 : 265,
                      child: TextField(
                        controller: _texto[e.key],
                        textCapitalization:
                            e.key.startsWith('link') ? TextCapitalization.none : TextCapitalization.characters,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(labelText: e.value, border: const OutlineInputBorder(), isDense: true),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              const Text('Parámetros', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Wrap(spacing: 8, runSpacing: 6, children: [
                _casilla('Comprado', _comprado, (v) => _comprado = v),
                _casilla('Vendido', _vendido, (v) => _vendido = v),
                _casilla('Activo', _activo, (v) => _activo = v),
                _casilla('Almacenado', _almacenado, (v) => _almacenado = v),
                _casilla('Grava IVA', _gravaIva, (v) => _gravaIva = v),
                _casilla('Fabricado', _fabricado, (v) => _fabricado = v),
              ]),
              if (faltan.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('Falta: ${faltan.join(', ')}', style: const TextStyle(fontSize: 12, color: Colors.red)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        ElevatedButton(
          onPressed: faltan.isEmpty ? () => Navigator.of(context).pop(_ficha) : null,
          child: const Text('Guardar ficha'),
        ),
      ],
    );
  }
}
