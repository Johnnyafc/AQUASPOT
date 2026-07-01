import 'package:flutter/material.dart';

class SectionTitleWidget extends StatelessWidget {
  final String title;

  const SectionTitleWidget({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0, top: 8.0),
      child: Text(
        title, 
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.teal)
      ),
    );
  }
}