import { onDocumentCreated } from "firebase-functions/v2/firestore";
import * as admin from "firebase-admin";

admin.initializeApp();

export const notificarSupervisor = onDocumentCreated(
  "tickets/{ticketId}",
  async (event) => {
    const snap = event.data;
    if (!snap) {
      console.error("Fallo: Evento sin datos.");
      return;
    }

    const ticket = snap.data();
    const supervisores = await admin.firestore()
      .collection("usuarios")
      .where("rol", "==", "SUPERVISOR")
      .get();

    const mensajes: Promise<any>[] = [];

    supervisores.forEach((doc) => {
      const data = doc.data();
      if (data.fcmToken) {
        const mensaje = {
          token: data.fcmToken,
          notification: {
            title: "⚠️ Nuevo Requerimiento",
            body: `Equipo: ${ticket.equipo} - Cliente: ${ticket.clienteId}`,
          },
        };
        mensajes.push(admin.messaging().send(mensaje));
      }
    });

    if (mensajes.length > 0) {
      await Promise.all(mensajes);
      console.log(`Éxito: ${mensajes.length} notificaciones encoladas.`);
    }
  }
);