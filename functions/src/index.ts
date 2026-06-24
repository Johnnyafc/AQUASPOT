import { onDocumentCreated, onDocumentUpdated } from "firebase-functions/v2/firestore";
import * as admin from "firebase-admin";
import * as nodemailer from "nodemailer";
import * as logger from "firebase-functions/logger";

admin.initializeApp();

// ============================================================================
// ⚙️ MOTOR SMTP CORPORATIVO (Inicializado fuera para reusar la conexión TCP)
// ============================================================================
const transporter = nodemailer.createTransport({
  host: 'smtp.zoho.com', // El host para cuentas corporativas de Zoho
  port: 465,
  secure: true, 
  auth: {
    user: "ingenieria2@aquaspot.ec", 
    pass: "ugVJMxCLNejS"
  }
});

// ============================================================================
// 📱 MÓDULO 1: ALARMA A SUPERVISORES (PUSH)
// ============================================================================
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

// ============================================================================
// 📱 MÓDULO 2: NOTIFICACIÓN A TÉCNICOS (PUSH)
// ============================================================================
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
        .where("rol", "==", "recepcion") 
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

// ============================================================================
// ✉️ MÓDULO 3: ACTA DE RECEPCIÓN AL CLIENTE (EMAIL SMTP)
// ============================================================================
export const enviarCorreoActaCliente = onDocumentUpdated(
  "tickets/{ticketId}",
  async (event) => {
    const snap = event.data;
    if (!snap) return;

    const docBefore = snap.before.data();
    const docAfter = snap.after.data();

    const estadoAnterior = docBefore.estadoActual;
    const estadoNuevo = docAfter.estadoActual;
    const urlPdf = docAfter.pdfActaUrl;
    const emailCliente = docAfter.emailContacto;
    const nombreContacto = docAfter.nombreContacto || "Cliente";

    // Compuerta Lógica: Solo disparamos cuando el equipo ingresa físicamente al laboratorio
    if (estadoNuevo === "recepcionFisica" && estadoAnterior !== "recepcionFisica") {
      
      if (!urlPdf || !emailCliente) {
        logger.warn(`[Ticket ${event.params.ticketId}] Operación abortada: Falta PDF o correo del cliente.`);
        return;
      }

      logger.info(`Iniciando telemetría SMTP para ticket ${event.params.ticketId} hacia ${emailCliente}`);

      const mailOptions = {
        from: '"Soporte Técnico Aquaspot" <ingenieria2@aquaspot.ec>', // ⚠️ DEBE COINCIDIR CON EL CORREO EN AUTH
        to: emailCliente,
        subject: `Acuse de Recepción Técnica - Ticket #${event.params.ticketId}`,
        html: `
          <div style="font-family: Arial, sans-serif; color: #333; max-width: 600px; margin: auto; border: 1px solid #ddd; border-radius: 8px;">
              <div style="background-color: #008080; padding: 20px; text-align: center;">
                  <h2 style="color: white; margin: 0;">Confirmación de Ingreso</h2>
              </div>
              <div style="padding: 30px;">
                  <p>Estimado/a <strong>${nombreContacto}</strong>,</p>
                  <p>Le notificamos de manera oficial que su equipo ha sido ingresado a nuestro laboratorio para su inspección.</p>
                  <p>Puede descargar su acta de recepción (con registro fotográfico) en el siguiente enlace seguro:</p>
                  <div style="text-align: center; margin: 40px 0;">
                      <a href="${urlPdf}" style="background-color: #008080; color: white; padding: 14px 28px; text-decoration: none; border-radius: 6px; font-weight: bold;">
                          📄 Descargar Acta PDF
                      </a>
                  </div>
                  <hr style="border: none; border-top: 1px solid #eee; margin: 30px 0;">
                  <p style="font-size: 12px; color: #777; text-align: center;">Atentamente,<br>Ingeniería Aquaspot</p>
              </div>
          </div>
        `,
      };

      try {
        await transporter.sendMail(mailOptions);
        logger.info(`✅ Acta del ticket ${event.params.ticketId} despachada exitosamente al cliente.`);
      } catch (error) {
        logger.error("💥 Falla crítica en el actuador de correo SMTP:", error);
      }
    }
  }
);