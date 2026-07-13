import 'package:flutter/material.dart';

class CustomDropdownField<T> extends StatelessWidget {
  final String label;
  final IconData icon;
  final List<T> items;
  final T? value;
  final ValueChanged<T?> onChanged;
  final String? Function(T?)? validator;

  const CustomDropdownField({
    super.key,
    required this.label,
    required this.icon,
    required this.items,
    required this.value,
    required this.onChanged,
    this.validator
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<T>(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          filled: true,
          fillColor: Colors.grey[50],
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        ),
        value: value,
        items: items.map((e) => DropdownMenuItem(
          value: e, 
          child: Text(e.toString().split('.').last.toUpperCase())
        )).toList(),
        onChanged: onChanged,
        validator: (v) => v == null ? 'Seleccione una opción' : null,
      ),
    );
  }
}