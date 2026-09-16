import 'dart:async'; 
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart'; 
import 'package:flutter/material.dart';

// ⚠️ IMPORTACIÓN DEL RELÉ GLOBAL (Ajuste los '../' si su archivo no está en core/services)
import '../../main.dart'; 

// ============================================================================
// 1. GATILLO DE BACKGROUND (Subrutina aislada)
// ============================================================================
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('Alarma interceptada en segundo plano: ${message.messageId}');
}

class NotificationService {
  // ✅ EL DISYUNTOR: Corta el flujo de memoria al cambiar de usuario
  static StreamSubscription<String>? _tokenSubscription;
  static final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  // Llave pública de encriptación para receptores Web
  static const String _vapidKeyWeb = 'BDmcPY-ZlGl7QLw5velHRfNFXdVdip3ekBFFxkXla3cIiYQWXpa7QPrbvRzAq6qvZamBIJY-OXvMNYrqnjcWGC0';

  // 🚀 FASE 1: Enlace en frío (Llamado en el main.dart para no bloquear)
  static void inicializarBackgroundHandler() {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }

  // 🚀 FASE 2: Inicialización pesada (Debe llamarse DESPUÉS de que el usuario haga login)
  static Future<void> inicializar() async {
    debugPrint('🔌 [FCM INIT] Iniciando secuencia de energización del receptor FCM...');
    FirebaseMessaging messaging = FirebaseMessaging.instance;

    try {
      NotificationSettings settings = await messaging.requestPermission(
        alert: true, badge: true, sound: true,
      );

      debugPrint('📋 [FCM INIT] Estado de permisos: ${settings.authorizationStatus}');
      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        debugPrint('✅ [FCM INIT] Receptor FCM energizado correctamente.');
      }
    } catch (e) {
      debugPrint('💥 [FCM INIT] Cortocircuito al solicitar permisos: $e');
    }

    // ⚙️ FILTRO DE ENTORNO: Inicialización de canales locales solo para Móvil
    if (!kIsWeb) {
      const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const DarwinInitializationSettings iosSettings = DarwinInitializationSettings();
      
      const InitializationSettings initSettings = InitializationSettings(
        android: androidSettings, 
        iOS: iosSettings,
      );

      await _localNotifications.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          debugPrint('🔔 [FCM ACTUADOR] Notificación seleccionada: ${response.payload}');
        },
      );
    } else {
      debugPrint('🌐 [FCM INIT] Entorno Web detectado: Omitiendo flutter_local_notifications.');
    }

    // ============================================================================
    // 📡 ESCÁNER EN PRIMER PLANO (CON ACTUADOR VISUAL)
    // ============================================================================
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('🔔 [FCM FOREGROUND] Alarma recibida en primer plano: ${message.notification?.title}');
      
      if (message.notification != null) {
        if (!kIsWeb) {
          // 📱 MÓVIL: Sirena nativa
          _mostrarNotificacionNativa(
            message.notification!.title ?? 'Alerta del Sistema',
            message.notification!.body ?? '',
          );
        } else {
          // 🌐 WEB: Disparo de la baliza visual a través del relé global
          actuadorVisualGlobal.currentState?.showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.white),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${message.notification!.title}: ${message.notification!.body}',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFFE67E22), // Naranja industrial
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 6),
              action: SnackBarAction(
                label: 'CERRAR',
                textColor: Colors.white,
                onPressed: () {
                  actuadorVisualGlobal.currentState?.hideCurrentSnackBar();
                },
              ),
            ),
          );
        }
      }
    });
  }

  static Future<void> _mostrarNotificacionNativa(String title, String body) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'canal_alta_prioridad', // ID del canal (debe coincidir en Android)
      'Alertas del Sistema',
      importance: Importance.max,
      priority: Priority.high,
    );

    const NotificationDetails platformDetails = NotificationDetails(android: androidDetails);

    await _localNotifications.show(
      id: DateTime.now().millisecondsSinceEpoch, 
      title: title,
      body: body,
      notificationDetails: platformDetails, 
    );
  }
  
  // ============================================================================
  // 3. ENCLAVAMIENTO (Login / Arranque)
  // ============================================================================
  static Future<void> registrarToken(String uid) async {
    debugPrint('⚡ [FCM REGISTRO] Iniciando enclavamiento de token para UID: $uid');
    try {
      FirebaseMessaging messaging = FirebaseMessaging.instance;

      // ⚙️ SOPORTE HÍBRIDO
      String? token;
      if (kIsWeb) {
        debugPrint('🌐 [FCM REGISTRO] Entorno WEB. Solicitando token VAPID...');
        token = await messaging.getToken(vapidKey: _vapidKeyWeb);
      } else {
        debugPrint('📱 [FCM REGISTRO] Entorno MÓVIL. Solicitando token nativo...');
        token = await messaging.getToken();
      }

      debugPrint('🔍 [FCM REGISTRO] Token obtenido -> $token');

      if (token != null) {
        debugPrint('💾 [FCM REGISTRO] Token válido. Guardando en Firestore...');
        await _guardarTokenEnFirestore(uid, token);
      } else {
        debugPrint('❌ [FCM REGISTRO] ERROR: El token es NULL.');
      }

      // ✅ PURGA DE MEMORIA
      await _tokenSubscription?.cancel();
      
      // Enclavamiento exclusivo de rotación
      _tokenSubscription = messaging.onTokenRefresh.listen((nuevoToken) {
        debugPrint('🔄 [FCM ROTACIÓN] Nuevo token: $nuevoToken');
        _guardarTokenEnFirestore(uid, nuevoToken);
      });
      
      _tokenSubscription?.onError((err) => debugPrint('💥 [FCM ROTACIÓN] Falla: $err'));

    } catch (e, stackTrace) {
      debugPrint('💥 [FCM REGISTRO] EXCEPCIÓN en registrarToken: $e');
      debugPrint('📜 [FCM REGISTRO] Stacktrace: $stackTrace');
    }
  }

  // ============================================================================
  // 4. DESENCLAVAMIENTO (Logout / Parada de Máquina)
  // ============================================================================
  static Future<void> eliminarToken(String uid) async {
    debugPrint('🔌 [FCM DESENCLAVAMIENTO] Iniciando purga para UID: $uid');
    try {
      await _tokenSubscription?.cancel();
      _tokenSubscription = null;

      String? tokenActual = kIsWeb 
          ? await FirebaseMessaging.instance.getToken(vapidKey: _vapidKeyWeb)
          : await FirebaseMessaging.instance.getToken();

      if (tokenActual != null) {
        await FirebaseFirestore.instance.collection('usuarios').doc(uid).update({
          'fcmTokens': FieldValue.arrayRemove([tokenActual]), 
        });
        debugPrint('🔌 [FCM DESENCLAVAMIENTO] Token removido de Firestore.');
      }
      
      await FirebaseMessaging.instance.deleteToken(); 
      debugPrint('✅ [FCM DESENCLAVAMIENTO] Dispositivo desenclavado y RAM purgada.');
    } catch (e) {
      debugPrint('💥 [FCM DESENCLAVAMIENTO] Error: $e');
    }
  }

  // ============================================================================
  // ⚙️ SUBRUTINA DE ESCRITURA EN BORNERA MÚLTIPLE
  // ============================================================================
  static Future<void> _guardarTokenEnFirestore(String uid, String token) async {
    try {
      await FirebaseFirestore.instance.collection('usuarios').doc(uid).set({
        // 🔌 ARRAY UNION: Agrega el token sin borrar los de los otros equipos
        'fcmTokens': FieldValue.arrayUnion([token]), 
      }, SetOptions(merge: true)); 
      debugPrint('✅ [FIRESTORE] Token FCM guardado con éxito en UID: $uid');
    } catch (e) {
      debugPrint('💥 [FIRESTORE] ERROR CRÍTICO al escribir token: $e');
      rethrow; 
    }
  }
}