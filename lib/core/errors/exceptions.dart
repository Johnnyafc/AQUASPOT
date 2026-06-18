// lib/core/errors/exceptions.dart

class ServerException implements Exception {
  final String message;
  
  ServerException(this.message);

  @override
  String toString() => message; // ✅ Esto garantiza que veas el mensaje, no el nombre de la clase
}