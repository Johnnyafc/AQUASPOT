// lib/core/services/notification_service.dart

import 'dart:async'; 
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart'; 

// 1. GATILLO DE BACKGROUND (Subrutina aislada)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('Alarma interceptada en segundo plano: ${message.messageId}');
}

class NotificationService {
  // ✅ EL DISYUNTOR: Corta el flujo de memoria al cambiar de usuario
  static StreamSubscription<String>? _tokenSubscription;

  // 2. INICIALIZACIÓN Y PERMISOS
  static Future<void> inicializar() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    NotificationSettings settings = await messaging.requestPermission(
      alert: true, badge: true, sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('Receptor FCM energizado.');
    } else {
      debugPrint('ADVERTENCIA: Balizas bloqueadas por el usuario.');
    }

    // ESCÁNER EN PRIMER PLANO (HMI Abierta)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('Alarma recibida en HMI: ${message.notification?.title}');
      // El paquete de datos llegó. La visualización depende de tu UI.
    });
  }

  // 3. ENCLAVAMIENTO (Login)
  static Future<void> registrarToken(String uid) async {
    try {
      FirebaseMessaging messaging = FirebaseMessaging.instance;

      String? token = await messaging.getToken();
      if (token != null) {
        await _guardarTokenEnFirestore(uid, token);
      }

      // ✅ PURGA DE MEMORIA: Desconecta sensores fantasmas
      await _tokenSubscription?.cancel();

      // Enclavamiento exclusivo
      _tokenSubscription = messaging.onTokenRefresh.listen((nuevoToken) {
        debugPrint('Rotación detectada: Actualizando Token FCM...');
        _guardarTokenEnFirestore(uid, nuevoToken);
      });
      
      _tokenSubscription?.onError((err) => debugPrint('Falla rotación: $err'));

    } catch (e) {
      debugPrint('Falla en el enclavamiento del Token FCM: $e');
    }
  }

  // 4. DESENCLAVAMIENTO (Logout)
  static Future<void> eliminarToken(String uid) async {
    try {
      // ✅ DESCONEXIÓN DEL SENSOR EN RAM
      await _tokenSubscription?.cancel();
      _tokenSubscription = null;

      await FirebaseFirestore.instance.collection('usuarios').doc(uid).update({
        'fcmToken': FieldValue.delete(),
      });
      
      await FirebaseMessaging.instance.deleteToken(); 
      debugPrint('Circuito cerrado: RAM purgada.');
    } catch (e) {
      debugPrint('Error al limpiar la bornera de tokens: $e');
    }
  }

  static Future<void> _guardarTokenEnFirestore(String uid, String token) async {
    await FirebaseFirestore.instance.collection('usuarios').doc(uid).update({
      'fcmToken': token,
    });
  }
}