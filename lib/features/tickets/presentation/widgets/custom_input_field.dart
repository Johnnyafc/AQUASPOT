import 'package:flutter/material.dart';

class CustomInputField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType keyboard;
  final int maxLines;
  
  // 🚀 Se agregaron estos 3 parámetros clave
  final FocusNode? focusNode;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;

  const CustomInputField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboard = TextInputType.text,
    this.maxLines = 1,
    this.focusNode,
    this.validator,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        focusNode: focusNode, // 🔗 Conecta el foco del framework aquí
        keyboardType: keyboard,
        maxLines: maxLines,
        onChanged: onChanged, // 🔗 Conecta la escucha de cambios aquí
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          filled: true,
          fillColor: Colors.grey[50],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12), 
            borderSide: BorderSide.none
          ),
        ),
        // 🛡️ Si mandas un validador personalizado lo usa, si no, usa tu regla por defecto
        validator: validator ?? (v) => (v == null || v.isEmpty) ? 'Requerido' : null,
      ),
    );
  }
}