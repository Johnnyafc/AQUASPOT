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
// 📱 MÓDULO 1: ALARMA DE ARRANQUE (NUEVO TICKET -> SUPERVISOR)
// ============================================================================
export const notificarNuevoTicket = onDocumentCreated(
  "tickets/{ticketId}",
  async (event) => {
    const snap = event.data;
    if (!snap) return;

    const ticket = snap.data();
    
    // ⚙️ EXTRACCIÓN Y NORMALIZACIÓN: El "equipo" define el "segmento"
    const equipo = ticket.equipo || "indefinido";
    const segmentoDestino = equipo.toLowerCase().trim();

    await dispararAlarmaFiltroSegmento(
      ["supervisor"], // ⚙️ CALIBRADO A MINÚSCULAS EXACTAS
      segmentoDestino,
      "⚠️ Nuevo Requerimiento Ingresado",
      `Equipo: ${ticket.equipo} - Cliente: ${ticket.clienteId}`
    );
  }
);

// ============================================================================
// 📱 MÓDULO 2: ORQUESTADOR CENTRAL DE CAMBIOS DE ESTADO (ENRUTADOR)
// ============================================================================
export const enrutadorNotificacionesPush = onDocumentUpdated(
  "tickets/{ticketId}",
  async (event) => {
    const snap = event.data;
    if (!snap) return;

    const ticketAntes = snap.before.data();
    const ticketAhora = snap.after.data();
    const estadoNuevo = ticketAhora.estadoActual;

    // Filtro de ruido: Cortocircuito si el estado físico no cambió
    if (ticketAntes.estadoActual === estadoNuevo) return;

    const ticketId = event.params.ticketId;
    const cliente = ticketAhora.clienteId;
    
    // ⚙️ EXTRACCIÓN Y NORMALIZACIÓN: El "equipo" define el "segmento"
    const equipo = ticketAhora.equipo || "indefinido";
    const segmentoDestino = equipo.toLowerCase().trim(); 

    // ⚙️ MATRIZ DE CONMUTACIÓN LÓGICA (Routing Avanzado)
    switch (estadoNuevo) {
      
      case "recepcionFisica":
        await dispararAlarmaFiltroSegmento(
          ["supervisor"], // ⚙️ CALIBRADO A MINÚSCULAS
          segmentoDestino, 
          "📦 Equipo en Recepción Física", 
          `El equipo ${equipo} de ${cliente} ha ingresado a recepción.`
        );
        break;

      case "revisionGarantia":
        await dispararAlarmaFiltroSegmento(
          ["supervisor"], // ⚙️ CALIBRADO A MINÚSCULAS
          segmentoDestino, 
          "⚠️ Revisión de Garantía Solicitada", 
          `Ticket #${ticketId}: El equipo requiere evaluación de garantía.`
        );
        break;
        
      case "comercial":
        await dispararAlarmaFiltroSegmento(
          ["comercial"], 
          segmentoDestino, 
          "💲 Acción Comercial Requerida", 
          `Ticket #${ticketId} - Se requiere intervención del perfil comercial.`
        );
        break;

      case "cotizado":
        // Estación de tránsito silenciosa (Sin alarma)
        return;

      case "costos":
        // 🚀 DISPARO DUAL: Dos actuadores independientes para distintos departamentos
        await dispararAlarmaFiltroSegmento(
          ["costos"], 
          segmentoDestino, 
          "📊 Análisis de Proyecto Requerido", 
          `Ticket #${ticketId}: Es necesario generar el proyecto de costos.`
        );
        await dispararAlarmaFiltroSegmento(
          ["compras"], 
          segmentoDestino, 
          "🛒 Cotización de Requerimiento", 
          `Ticket #${ticketId}: Ya puede cotizar los repuestos requeridos.`
        );
        break;

      case "compras":
        await dispararAlarmaFiltroSegmento(
          ["compras"], 
          segmentoDestino, 
          "🛍️ Ejecutar Compra", 
          `Ticket #${ticketId}: Realice la compra y suba la Orden de Compra al sistema.`
        );
        break;

      case "bodega":
        // Estación de tránsito silenciosa (Sin alarma)
        return;

      case "procesoTrabajo":
        await dispararAlarmaFiltroSegmento(
          ["supervisor"], // ⚙️ CALIBRADO A MINÚSCULAS
          segmentoDestino, 
          "⚙️ Trabajo Liberado", 
          `Todo listo en bodega. Puede iniciar el trabajo en el ticket #${ticketId}.`
        );
        break;

      case "validacionFacturacion":
        await dispararAlarmaFiltroSegmento(
          ["comercial"], 
          segmentoDestino, 
          "🧾 Revisión de Facturas", 
          `Ticket #${ticketId}: Realice la revisión de facturas impagas del cliente.`
        );
        break;

      case "entrega":
      case "finalizado":
      case "anulado":
      default:
        // Estados inactivos / silenciosos
        return; 
    }
  }
);

// ============================================================================
// ⚙️ SUBRUTINA DE EJECUCIÓN (FILTRO LÓGICO Y BOMBA MULTICAST)
// ============================================================================
async function dispararAlarmaFiltroSegmento(
  rolesDestino: string[], 
  segmentoTicket: string, 
  titulo: string, 
  cuerpo: string
) {
  try {
    // 🔌 BYPASS MAESTRO: Forzamos la inclusión del rol administrador en todas las consultas.
    // Usamos Set para evitar duplicados en la matriz por si acaso.
    // OJO: Asumo que su rol se guarda como "admin" (minúsculas) o "ADMIN".
    const rolesConAdmin = [...new Set([...rolesDestino, "admin", "ADMIN"])];

    // 1. Recolección primaria: Traemos los roles requeridos + Administradores
    const querySnapshot = await admin.firestore()
      .collection("usuarios")
      .where("rol", "in", rolesConAdmin)
      .get();

    let tokensDestino: string[] = [];

    // 2. Filtro Secundario en RAM (Compuerta OR Exclusiva)
    querySnapshot.forEach((doc) => {
      const usuario = doc.data();
      const segmentoUsuario = usuario.segmento || "ninguno";
      
      // Normalizamos el rol para blindar el circuito contra errores de tipeo
      const rolUsuario = (usuario.rol || "indefinido").toLowerCase();

      // 🧠 Lógica de enclavamiento actualizada: 
      // ¿Es administrador (llave maestra global) O su segmento coincide?
      const tieneAccesoAlSegmento = (
        rolUsuario === "admin" || 
        segmentoUsuario === "general" || 
        segmentoUsuario === "ninguno" || 
        segmentoUsuario === segmentoTicket
      );

      if (tieneAccesoAlSegmento && usuario.fcmTokens && Array.isArray(usuario.fcmTokens)) {
        tokensDestino = tokensDestino.concat(usuario.fcmTokens);
      }
    });

    // 3. Disparo del cañón FCM con soporte híbrido (Móvil + WebPush)
    if (tokensDestino.length > 0) {
      const payload = {
        notification: {
          title: titulo,
          body: cuerpo,
        },
        webpush: {
          notification: {
            title: titulo,
            body: cuerpo,
            icon: '/icons/Icon-192.png',
            requireInteraction: true,
          },
        },
        android: {
          priority: 'high' as const,
          notification: {
            channelId: 'canal_alta_prioridad',
            sound: 'default',
          },
        },
        tokens: tokensDestino, 
      };

      const response = await admin.messaging().sendEachForMulticast(payload);
      logger.info(`✅ Alerta [${titulo}] enviada a ${tokensDestino.length} terminales. Fallos: ${response.failureCount}`);
      
      if (response.failureCount > 0) {
        response.responses.forEach((resp, idx) => {
          if (!resp.success) {
            logger.error(`❌ Token inválido en índice ${idx}:`, resp.error);
          }
        });
      }
    } else {
      logger.warn(`⚠️ No se encontraron tokens activos para Rol: ${rolesConAdmin} | Seg: ${segmentoTicket}`);
    }
  } catch (error) {
    logger.error("💥 Falla crítica en la subrutina Multicast FCM:", error);
  }
}

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
    
    // ⚠️ FILTRO DE RUIDO: Si el estado físico no cambió, abortamos.
    if (estadoNuevo === estadoAnterior) return;

    const emailCliente = docAfter.emailContacto;
    const nombreContacto = docAfter.nombreContacto || "Cliente";
    const ticketId = event.params.ticketId;

    if (!emailCliente) {
      logger.warn(`[Ticket ${ticketId}] Operación abortada: El equipo no tiene correo asociado.`);
      return;
    }

    // ⚙️ SENSOR DE UBICACIÓN GLOBAL
    // Lo sacamos al bus principal para que toda la máquina de estados sepa dónde estamos
    const lugarAtencion = (docAfter.lugarAtencion || "taller").toLowerCase();

    // =========================================================
    // 🔀 MÁQUINA DE ESTADOS (Enrutador Principal)
    // =========================================================

    try {
      // 🟢 ESTADO A: INGRESO / RECEPCIÓN
      if (estadoNuevo === "recepcionFisica") {
        
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
                
        // Rama 2: Operación en Taller
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
          html: _generarPlantillaRecepcion(nombreContacto, urlPdf, docAfter) 
        });
        return;
      }

      // 🔵 ESTADO B: FINALIZACIÓN DEL TRABAJO TÉCNICO (Compuertas Lógicas)
      
      // Condición 1 (CAMPO): Dispara al pasar de Trabajo a Facturación
      const esFinDeCampo = lugarAtencion === "campo" && 
                           estadoAnterior === "procesoTrabajo" && 
                           estadoNuevo === "validacionFacturacion";

      // Condición 2 (TALLER): Dispara al llegar al estado Finalizado
      const esFinDeTaller = lugarAtencion !== "campo" && 
                            estadoNuevo === "finalizado" && 
                            estadoAnterior !== "finalizado";

      // ⚡ DISPARADOR UNIFICADO
      if (esFinDeCampo || esFinDeTaller) {
        logger.info(`Despachando telemetría de FINALIZACIÓN para ticket ${ticketId} (Modo: ${lugarAtencion})`);
        
        // Ajuste dinámico del asunto del correo según el entorno
        const asuntoCorreo = lugarAtencion === "campo" 
            ? `✅ Trabajo Técnico Concluido - Ticket #${ticketId}` 
            : `✅ Equipo Listo para Retiro / Despacho - Ticket #${ticketId}`;

        await transporter.sendMail({
          from: '"Soporte Técnico" <ingenieria2@aquaspot.ec>',
          to: emailCliente,
          subject: asuntoCorreo,
          html: _generarPlantillaFinalizado(nombreContacto, ticketId, docAfter)
        });
        return;
      }

    } catch (error) {
      logger.error(`💥 Falla crítica en el actuador SMTP para el ticket ${ticketId}:`, error);
    }
  }
);

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


function _generarPlantillaRecepcion(nombre: string, urlPdf: string, datos: any): string {
  // ⚙️ Extracción segura de telemetría
  const equipo = datos.equipo || "No especificado";
  const serie = datos.numeroSerie || "N/A";
  const marca = datos.marca || "N/a"
  const motivo = datos.fallaReportada || "Inspección general";

  return `
    <div style="font-family: Arial, sans-serif; color: #333; max-width: 600px; margin: auto; border: 1px solid #ddd; border-radius: 8px;">
        <div style="background-color: #005A9C; padding: 20px; text-align: center;">
            <h2 style="color: white; margin: 0;">Confirmación de Ingreso</h2>
        </div>
        <div style="padding: 30px;">
            <p>Estimado/a <strong>${nombre}</strong>,</p>
            <p>Le notificamos de manera oficial que su equipo ha sido ingresado a nuestro taller para su inspección técnica.</p>
            
            <div style="background-color: #f9f9f9; padding: 15px; border-left: 4px solid #005A9C; margin: 20px 0;">
                <p style="margin: 5px 0;"><strong>Equipo:</strong> ${equipo}</p>
                <p style="margin: 5px 0;"><strong>Número de Serie:</strong> ${serie}</p>
                <p style="margin: 5px 0;"><strong>Marca:</strong> ${marca}</p>
                <p style="margin: 5px 0;"><strong>Motivo de Ingreso:</strong> ${motivo}</p>
            </div>

            <div style="text-align: center; margin: 40px 0;">
                <a href="${urlPdf}" style="background-color: #005A9C; color: white; padding: 14px 28px; text-decoration: none; border-radius: 6px; font-weight: bold;">
                    📄 Descargar Acta PDF
                </a>
            </div>
            
            <hr style="border: none; border-top: 1px solid #eee; margin: 30px 0;">
            <p style="font-size: 12px; color: #777; text-align: center;">Atentamente,<br>Departamento de Soporte Técnico</p>
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
