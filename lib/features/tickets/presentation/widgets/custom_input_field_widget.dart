import 'package:flutter/material.dart';

class CustomInputFieldWidget extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final IconData icon;
  final int lines;
  final String? hint;

  const CustomInputFieldWidget({
    super.key,
    required this.label,
    required this.controller,
    required this.icon,
    this.lines = 1,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextFormField(
        controller: controller,
        maxLines: lines,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon, color: Colors.teal),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Colors.teal, width: 2),
          ),
        ),
        validator: (value) => (value == null || value.trim().isEmpty) 
            ? 'Dato requerido para control de calidad.' 
            : null,
      ),
    );
  }
}