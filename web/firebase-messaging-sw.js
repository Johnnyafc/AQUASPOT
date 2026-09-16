importScripts('https://www.gstatic.com/firebasejs/10.7.1/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.7.1/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: "AIzaSyC9vJzVDh8Rh5E0gxu4zEVIdWenLtGvML8",
  authDomain: "aquaspot-postventa.firebaseapp.com",
  projectId: "aquaspot-postventa",
  storageBucket: "aquaspot-postventa.firebasestorage.app",
  messagingSenderId: "700527118972",
  appId: "1:700527118972:web:a74145c9e26fa54021d7f9"
});

const messaging = firebase.messaging();

// ⚡ 1. RUTINAS DE PURGA DE CACHÉ (Mata al Service Worker Zombie)
self.addEventListener('install', (event) => {
  console.log('🔄 [SW] Instalando nueva versión del Service Worker. Forzando skipWaiting...');
  self.skipWaiting(); // Obliga al navegador a instalar esta versión INMEDIATAMENTE
});

self.addEventListener('activate', (event) => {
  console.log('✅ [SW] Nueva versión activada. Tomando el control de los clientes...');
  event.waitUntil(clients.claim()); // Secuestra el control de todas las pestañas abiertas
});

// ⚙️ 2. INTERCEPTOR DE SEGUNDO PLANO
messaging.onBackgroundMessage((payload) => {
  console.log('📡 [SW] Paquete recibido en background:', payload);

  try {
    // 🛡️ DEMULTIPLEXOR
    const titulo = payload.notification?.title || payload.data?.title || 'Alarma de Planta';
    const cuerpo = payload.notification?.body || payload.data?.body || 'Nuevo evento recibido';
    const icono = '/icons/Icon-192.png';

    console.log(`🔍 [SW] Procesando datos: Título=${titulo}, Cuerpo=${cuerpo}`);

    const opciones = {
      body: cuerpo,
      icon: icono,
      badge: icono, // El icono pequeño en la barra de estado
      data: { url: '/' } 
    };

    // 🚀 DISPARO DE NOTIFICACIÓN NATIVA CON ENCLAVAMIENTO DE HILO (RETURN CRÍTICO)
    // El 'return' obliga al navegador a mantener el hilo energizado hasta que la promesa se cumpla
    return self.registration.showNotification(titulo, opciones);

  } catch (error) {
    console.error('💥 [SW] Error catastrófico en onBackgroundMessage:', error);
  }
});

console.log('🔌 [SW] Service Worker energizado, purgado y escuchando señales...');