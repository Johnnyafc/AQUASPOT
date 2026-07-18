import { onDocumentCreated, onDocumentUpdated } from "firebase-functions/v2/firestore";
import * as admin from "firebase-admin";
import * as nodemailer from "nodemailer";
import * as logger from "firebase-functions/logger";
import { onDocumentWritten } from "firebase-functions/v2/firestore"
import * as xlsx from "xlsx";
import { onObjectFinalized } from "firebase-functions/v2/storage";

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
export const enviarCorreoActaCliente = onDocumentWritten(
  "tickets/{ticketId}",
  async (event) => {
    const snap = event.data;
    
    // 1. HARD INTERLOCK: Si no hay snapshot o el documento fue eliminado (Delete), cortamos el circuito
    if (!snap || !snap.after.exists) return;

    const docAfter = snap.after.data() as any;
    // 2. Extracción segura: Evaluamos si existía un estado previo
    const docBefore = snap.before.exists ? snap.before.data() as any : null;

    const estadoNuevo = docAfter.estadoActual;
    const estadoAnterior = docBefore ? docBefore.estadoActual : null;
    const urlPdf = docAfter.pdfActaUrl;
    const emailCliente = docAfter.emailContacto;
    const nombreContacto = docAfter.nombreContacto || "Cliente";

    // =========================================================
    // 🔀 COMPUERTA LÓGICA OR (Detección de Origen)
    // =========================================================
    
    // Condición A: El ticket nace desde la app en campo ya completo
    const esCreacionDirecta = !docBefore && estadoNuevo === "recepcionFisica";
    
    // Condición B: El ticket transiciona en el taller (pasó de 'creado' a 'recepcionFisica')
    const esTransicionTaller = docBefore && estadoNuevo === "recepcionFisica" && estadoAnterior !== "recepcionFisica";

    // 3. ACTUADOR PRINCIPAL
    if (esCreacionDirecta || esTransicionTaller) {
      
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



// ============================================================================
// ⚙️ MÓDULO: PROCESAMIENTO DOCUMENTAL COMERCIAL (EXCEL PARSER)
// ============================================================================
export const procesarExcelRepuestos = onObjectFinalized(
  {
    memory: "512MiB",
    timeoutSeconds: 60 // Al descargar directo del bucket nativo, es mucho más rápido
  },
  async (event) => {
    const filePath = event.data.name; // Ej: "tickets/REQ-00001/comercial/proforma_excel_123.xlsx"
    const contentType = event.data.contentType;
    const fileBucket = event.data.bucket;

    // 1. CORTAFUEGOS (HARD INTERLOCK): Rechazo de intrusos
    // Si no está en la carpeta 'comercial' o no es un Excel, cortamos el circuito en 5 milisegundos.
    if (!filePath || !filePath.includes("/comercial/")) return;

    if (!filePath.endsWith(".xlsx") && contentType !== "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet") {
        logger.info(`[Filtro] Archivo ignorado. No es el formato esperado (Probablemente un PDF): ${filePath}`);
        return; 
    }

    // 2. PARSEO DE RUTA: Extracción del Ticket ID
    // Dividimos la ruta "tickets/REQ-00001/comercial/..." por los slashes
    const pathSegments = filePath.split('/');
    const ticketId = pathSegments[1]; 

    if (!ticketId) {
        logger.error(`Error arquitectónico: No se pudo extraer el Ticket ID de la ruta: ${filePath}`);
        return;
    }

    logger.info(`[Ticket ${ticketId}] Excel detectado en Storage. Iniciando extracción a RAM...`);

    try {
        // 3. DESCARGA NATIVA (Memoria a Memoria)
        // Descargamos el archivo usando el Admin SDK sin exponer URLs públicas
        const bucket = admin.storage().bucket(fileBucket);
        const [fileBuffer] = await bucket.file(filePath).download();

        // 4. MOTOR DE PARSEO ESTÁNDAR
        const workbook = xlsx.read(fileBuffer, { type: "buffer" });
        const firstSheetName = workbook.SheetNames[0];
        const worksheet = workbook.Sheets[firstSheetName];
        const rawData = xlsx.utils.sheet_to_json(worksheet, { defval: null });

        // 5. CONTRATO COMERCIAL (Filtro de Integridad)
        const repuestosValidos = rawData.filter((row: any) => {
            const tieneCodigo = row["CODIGO"] !== null && String(row["CODIGO"]).trim() !== "";
            const tieneCantidad = row["CANTIDAD"] !== null && Number(row["CANTIDAD"]) > 0;
            return tieneCodigo && tieneCantidad;
        });

        if (repuestosValidos.length === 0) {
            logger.warn(`[Ticket ${ticketId}] Operación abortada: La matriz de Excel está vacía o corrupta.`);
            await admin.firestore().collection("tickets").doc(ticketId).update({
                estadoProcesamientoExcel: "ERROR_FORMATO"
            });
            return;
        }

        // 6. INYECCIÓN ATÓMICA EN BASE DE DATOS
        await admin.firestore().collection("tickets").doc(ticketId).update({
            itemsCompra: admin.firestore.FieldValue.arrayUnion(...repuestosValidos),
            estadoProcesamientoExcel: "COMPLETADO",
            fechaProcesamientoExcel: admin.firestore.FieldValue.serverTimestamp()
        });

        logger.info(`✅ [Ticket ${ticketId}] ${repuestosValidos.length} repuestos insertados exitosamente desde Storage.`);

    } catch (error) {
        logger.error(`💥 [Ticket ${ticketId}] Fallo catastrófico en la rutina de procesamiento:`, error);
        await admin.firestore().collection("tickets").doc(ticketId).update({
            estadoProcesamientoExcel: "ERROR_SISTEMA"
        });
    }
  }
);