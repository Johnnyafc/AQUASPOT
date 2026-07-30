import 'package:flutter/material.dart';

class CustomInputField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType keyboard;
  final int maxLines;
  
  final FocusNode? focusNode;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  
  // 🔒 Pin de control de enmascaramiento (Privacidad de datos)
  final bool obscureText;

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
    this.obscureText = false, // Por defecto visible
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        focusNode: focusNode,
        keyboardType: keyboard,
        maxLines: maxLines,
        onChanged: onChanged,
        obscureText: obscureText, // 🔗 Conexión directa al motor del input
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
        validator: validator ?? (v) => (v == null || v.isEmpty) ? 'Requerido' : null,
      ),
    );
  }
}