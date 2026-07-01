import 'package:flutter/material.dart';

class ReadOnlyFieldWidget extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final int lines;

  const ReadOnlyFieldWidget({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.lines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: TextFormField(
        initialValue: value,
        maxLines: lines,
        readOnly: true,
        style: const TextStyle(color: Colors.black54), 
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: Colors.grey),
          filled: true,
          fillColor: Colors.grey.shade100,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8), 
            borderSide: BorderSide.none
          ),
        ),
      ),
    );
  }
}