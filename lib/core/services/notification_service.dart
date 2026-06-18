// lib/core/services/notification_service.dart

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart'; // Para debugPrint

class NotificationService {
  // 1. Rutina de Inicialización y Permisos (Llamar al arrancar la app)
  static Future<void> inicializar() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;

    // Pedimos permiso al Sistema Operativo (Obligatorio en Android 13+ y iOS)
    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('Receptor FCM energizado: Permisos concedidos.');
    } else {
      debugPrint('ADVERTENCIA: El usuario bloqueó las balizas de notificación.');
    }

    // Escáner de primer plano (Cuando el supervisor tiene la app abierta)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('Alarma recibida en primer plano: ${message.notification?.title}');
      // Nota técnica: Por defecto FCM no muestra el "Heads-up" (burbuja) si la app está abierta.
      // Aquí más adelante podemos conectar un SnackBar global o un LocalNotification.
    });
  }

  // 2. Enclavamiento del dispositivo (Llamar tras Login exitoso)
  static Future<void> registrarToken(String uid) async {
    try {
      String? token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await FirebaseFirestore.instance.collection('usuarios').doc(uid).update({
          'fcmToken': token,
        });
        debugPrint('Token FCM registrado con éxito para el usuario: $uid');
      }
    } catch (e) {
      debugPrint('Falla en el registro del Token FCM: $e');
    }
  }
}