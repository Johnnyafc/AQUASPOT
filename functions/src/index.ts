import { onDocumentCreated, onDocumentUpdated } from "firebase-functions/v2/firestore";
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

export const notificarRecepcion = onDocumentUpdated(
  "tickets/{ticketId}",
  async (event) => {
    const snap = event.data;
    if (!snap) {
      console.error("Fallo: Evento sin datos.");
      return;
    }

    const ticketAntes = snap.before.data();
    const ticketAhora = snap.after.data();

    // Válvula lógica: Solo disparamos cuando el estado cambia a "evaluacionTecnica"
    if (ticketAntes.estadoActual !== "evaluacionTecnica" && ticketAhora.estadoActual === "evaluacionTecnica") {
      
      const receptores = await admin.firestore()
        .collection("usuarios")
        .where("rol", "==", "recepcion") // Asegúrate que este sea el string exacto en tu BD
        .get();

      const mensajes: Promise<any>[] = [];

      receptores.forEach((doc) => {
        const data = doc.data();
        if (data.fcmToken) {
          const mensaje = {
            token: data.fcmToken,
            notification: {
              title: "📸 Registro Fotográfico Requerido",
              body: `El equipo ${ticketAhora.equipo} de ${ticketAhora.clienteId} ha sido aprobado. Proceder con fotos.`,
            },
          };
          mensajes.push(admin.messaging().send(mensaje));
        }
      });

      if (mensajes.length > 0) {
        await Promise.all(mensajes);
        console.log(`Éxito: ${mensajes.length} notificaciones de recepción encoladas.`);
      }
    }
  }
);

