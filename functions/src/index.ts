import { onDocumentCreated, onDocumentUpdated } from "firebase-functions/v2/firestore";
import * as admin from "firebase-admin";
import * as nodemailer from "nodemailer";
import * as logger from "firebase-functions/logger";
import { onDocumentWritten } from "firebase-functions/v2/firestore"

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
export const orquestadorNotificacionesTicket = onDocumentWritten(
  "tickets/{ticketId}",
  async (event) => {
    const snap = event.data;
    
    // 1. HARD INTERLOCK: Cortamos circuito si no hay datos o es un Delete
    if (!snap || !snap.after.exists) return;

    const docAfter = snap.after.data() as any;
    const docBefore = snap.before.exists ? snap.before.data() as any : null;

    const estadoNuevo = docAfter.estadoActual;
    const estadoAnterior = docBefore ? docBefore.estadoActual : null;
    
    // ⚠️ FILTRO DE RUIDO: Si el estado no cambió (ej. solo editaron un texto), abortamos.
    if (estadoNuevo === estadoAnterior) return;

    const emailCliente = docAfter.emailContacto;
    const nombreContacto = docAfter.nombreContacto || "Cliente";
    const ticketId = event.params.ticketId;

    if (!emailCliente) {
      logger.warn(`[Ticket ${ticketId}] Operación abortada: El equipo no tiene correo asociado.`);
      return;
    }

    // =========================================================
    // 🔀 MÁQUINA DE ESTADOS (Enrutador Principal)
    // =========================================================

    try {
      // 🟢 ESTADO A: INGRESO / RECEPCIÓN (Bifurcado por Lugar de Atención)
      if (estadoNuevo === "recepcionFisica") {
        const lugarAtencion = docAfter.lugarAtencion;
           logger.info(`Despachando telemetría de RECEPCIÓN EN CAMPO para ticket ${lugarAtencion}`);
        // Rama 1: Operación en Campo
        if (lugarAtencion === "campo") {
          logger.info(`Despachando telemetría de RECEPCIÓN EN CAMPO para ticket ${ticketId}`);
          await transporter.sendMail({
            from: '"Soporte Técnico" <ingenieria2@aquaspot.ec>',
            to: emailCliente,
            subject: `📅 Requerimiento de Visita en Campo - Ticket #${ticketId}`,
            html: _generarPlantillaRecepcionCampo(nombreContacto, ticketId, docAfter)
          });
          return;
        } 
                // Rama 2: Operación en Taller / Laboratorio (Lógica Original)
        const urlPdf = docAfter.pdfActaUrl;
        
        if (!urlPdf) {
          logger.warn(`[Ticket ${ticketId}] Sin PDF de acta. Cortando transmisión para recepción en taller.`);
          return;
        }

        logger.info(`Despachando telemetría de RECEPCIÓN EN TALLER para ticket ${ticketId}`);
        await transporter.sendMail({
          from: '"Soporte Técnico" <ingenieria2@aquaspot.ec>',
          to: emailCliente,
          subject: `Acuse de Recepción Técnica - Ticket #${ticketId}`,
          html: _generarPlantillaRecepcion(nombreContacto, urlPdf)
        });
        return;
      }

      // 🔵 ESTADO B: TRABAJO FINALIZADO (Transición desde procesoTrabajo)
      if (estadoNuevo === "finalizado" && estadoAnterior === "validacionFacturacion") {
        logger.info(`Despachando telemetría de FINALIZACIÓN para ticket ${ticketId}`);
        await transporter.sendMail({
          from: '"Soporte Técnico" <ingenieria2@aquaspot.ec>',
          to: emailCliente,
          subject: `✅ Equipo Listo para Retiro - Ticket #${ticketId}`,
          html: _generarPlantillaFinalizado(nombreContacto, ticketId, docAfter)
        });
        return;
      }

    } catch (error) {
      logger.error(`💥 Falla crítica en el actuador SMTP para el ticket ${ticketId}:`, error);
    }
  }
);

// =========================================================
// ⚙️ SUBMÓDULOS DE RENDERIZADO HTML (HMI)
// =========================================================


function _generarPlantillaRecepcionCampo(nombre: string, ticketId: string, datos: any): string {
  const equipo = datos.equipo || "No especificado";
  const problema = datos.fallaReportada || "Inspección general";
  const sede = datos.sede || "Ubicación pendiente";

  return `
    <div style="font-family: Arial, sans-serif; color: #333; max-width: 600px; margin: auto; border: 1px solid #ddd; border-radius: 8px;">
        <div style="background-color: #E67E22; padding: 20px; text-align: center;">
            <h2 style="color: white; margin: 0;">🚜 Requerimiento de Visita Técnica</h2>
        </div>
        <div style="padding: 30px;">
            <p>Estimado/a <strong>${nombre}</strong>,</p>
            <p>Hemos recibido correctamente su solicitud de asistencia técnica en campo. Se ha generado el ticket de servicio <strong>#${ticketId}</strong>.</p>
            
            <div style="background-color: #f9f9f9; padding: 15px; border-left: 4px solid #E67E22; margin: 20px 0;">
                <p style="margin: 5px 0;"><strong>Sede / Ubicación:</strong> ${sede}</p>
                <p style="margin: 5px 0;"><strong>Equipo:</strong> ${equipo}</p>
                <p style="margin: 5px 0;"><strong>Motivo de Visita:</strong> ${problema}</p>
            </div>

            <p>Nuestro equipo de ingeniería se pondrá en contacto a la brevedad para coordinar la fecha y hora exacta de la movilización de nuestros técnicos a sus instalaciones.</p>
            
            <hr style="border: none; border-top: 1px solid #eee; margin: 30px 0;">
            <p style="font-size: 12px; color: #777; text-align: center;">Atentamente,<br>Departamento de Operaciones en Campo</p>
        </div>
    </div>
  `;
}


function _generarPlantillaRecepcion(nombre: string, urlPdf: string): string {
  return `
    <div style="font-family: Arial, sans-serif; color: #333; max-width: 600px; margin: auto; border: 1px solid #ddd; border-radius: 8px;">
        <div style="background-color: #005A9C; padding: 20px; text-align: center;">
            <h2 style="color: white; margin: 0;">Confirmación de Ingreso</h2>
        </div>
        <div style="padding: 30px;">
            <p>Estimado/a <strong>${nombre}</strong>,</p>
            <p>Le notificamos de manera oficial que su equipo ha sido ingresado a nuestro laboratorio para su inspección.</p>
            <div style="text-align: center; margin: 40px 0;">
                <a href="${urlPdf}" style="background-color: #005A9C; color: white; padding: 14px 28px; text-decoration: none; border-radius: 6px; font-weight: bold;">
                    📄 Descargar Acta PDF
                </a>
            </div>
        </div>
    </div>
  `;
}

function _generarPlantillaFinalizado(nombre: string, ticketId: string, datos: any): string {
  // Extracción segura para evitar "undefined" en la vista del cliente
  const equipo = datos.equipo || "No especificado";
  const marca = datos.marca || "No especificada";
  const serie = datos.numeroSerie || "N/A";
  const falla = datos.fallaReportada || "N/A";
  const lugar = datos.lugarAtencion?.toUpperCase() || "TALLER";

  return `
    <div style="font-family: Arial, sans-serif; color: #333; max-width: 600px; margin: auto; border: 1px solid #ddd; border-radius: 8px;">
        <div style="background-color: #28a745; padding: 20px; text-align: center;">
            <h2 style="color: white; margin: 0;">🛠️ Su equipo está listo</h2>
        </div>
        <div style="padding: 30px;">
            <p>Estimado/a <strong>${nombre}</strong>,</p>
            <p>Nos complace informarle que los trabajos de mantenimiento para el ticket <strong>#${ticketId}</strong> han concluido exitosamente.</p>
            
            <h3 style="border-bottom: 2px solid #28a745; padding-bottom: 5px; margin-top: 30px;">Resumen Técnico</h3>
            <table style="width: 100%; border-collapse: collapse; margin-bottom: 20px;">
                <tr>
                    <td style="padding: 10px; border-bottom: 1px solid #eee; width: 35%;"><strong>Equipo:</strong></td>
                    <td style="padding: 10px; border-bottom: 1px solid #eee;">${equipo}</td>
                </tr>
                <tr>
                    <td style="padding: 10px; border-bottom: 1px solid #eee;"><strong>Marca:</strong></td>
                    <td style="padding: 10px; border-bottom: 1px solid #eee;">${marca}</td>
                </tr>
                <tr>
                    <td style="padding: 10px; border-bottom: 1px solid #eee;"><strong>Número de Serie:</strong></td>
                    <td style="padding: 10px; border-bottom: 1px solid #eee;">${serie}</td>
                </tr>
                <tr>
                    <td style="padding: 10px; border-bottom: 1px solid #eee;"><strong>Falla Reportada:</strong></td>
                    <td style="padding: 10px; border-bottom: 1px solid #eee;">${falla}</td>
                </tr>
            </table>

            <p style="font-size: 15px; text-align: center; margin-top: 30px;">
                Su equipo se encuentra en <strong>${lugar}</strong> y está listo para ser despachado o retirado.
            </p>
            
            <hr style="border: none; border-top: 1px solid #eee; margin: 30px 0;">
            <p style="font-size: 12px; color: #777; text-align: center;">Atentamente,<br>Departamento de Ingeniería</p>
        </div>
    </div>
  `;
}
