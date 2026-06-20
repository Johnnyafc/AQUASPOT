import 'package:flutter/material.dart';

class FullPhotoPage extends StatelessWidget {
  final String imageUrl;

  const FullPhotoPage({super.key, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      // ✅ InteractiveViewer permite hacer zoom y desplazar la imagen
      body: Center(
        child: InteractiveViewer(
          panEnabled: true,
          boundaryMargin: const EdgeInsets.all(20),
          minScale: 0.5,
          maxScale: 4,
          child: Image.network(
            imageUrl,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => 
                const Icon(Icons.broken_image, color: Colors.white),
          ),
        ),
      ),
    );
  }
}