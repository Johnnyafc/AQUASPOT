import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class PanelDocumentosComerciales extends StatelessWidget {
  // ⚙️ PINES DE ENTRADA: El módulo solo necesita la lista cruda, no le importa de qué ticket viene.
  final List<String> urls;

  const PanelDocumentosComerciales({
    super.key,
    required this.urls,
  });

  // ⚙️ MOTOR INTERNO: Aislado del resto de la aplicación
  Future<void> _abrirDocumento(BuildContext context, String urlString) async {
    try {
      final Uri url = Uri.parse(urlString);
      
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        throw Exception('El sistema operativo rechazó la apertura del enlace.');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fallo de telemetría al abrir PDF: $e'), backgroundColor: Colors.red)
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (urls.isEmpty) {
       return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Padding(
          padding: EdgeInsets.all(20),
          child: Center(
            child: Text(
              'Sin documentos comerciales cargados.', 
              style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)
            )
          ),
        ),
      );
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: urls.map((urlString) {
          return ListTile(
            leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
            title: const Text(
              'Ver Proforma PDF', 
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue, decoration: TextDecoration.underline)
            ),
            trailing: const Icon(Icons.open_in_new),
            // Disparo del motor local
            onTap: () => _abrirDocumento(context, urlString),
          );
        }).toList(),
      ),
    );
  }
}