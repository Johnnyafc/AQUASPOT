import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

admin.initializeApp();

export const notificarSupervisor = functions.firestore
    .document('tickets/{ticketId}')
    // Retiramos los tipos explícitos aquí, TypeScript los infiere automáticamente
    .onCreate(async (snap, context) => {
        const ticket = snap.data();
        
        const supervisores = await admin.firestore()
            .collection('usuarios')
            .where('rol', '==', 'SUPERVISOR')
            .get();

        // Mantenemos el tipado estricto solo en el colector de promesas
        const mensajes: Promise<any>[] = [];

        supervisores.forEach(doc => {
            const data = doc.data();
            if (data.fcmToken) {
                const mensaje = {
                    token: data.fcmToken,
                    notification: {
                        title: '⚠️ Nuevo Requerimiento Urgente',
                        body: `Equipo: ${ticket.equipo} - Cliente: ${ticket.clienteId}`
                    }
                };
                mensajes.push(admin.messaging().send(mensaje));
            }
        });

        return Promise.all(mensajes);
    });