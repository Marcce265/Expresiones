/*
 * Datos mínimos para el emulador local de Cloud Firestore.
 *
 * Este script no usa credenciales ni el SDK Admin. Se niega a conectarse a un
 * host que no sea localhost para evitar escrituras remotas accidentales.
 */

'use strict';

const fs = require('fs');
const path = require('path');

const emulatorHost = process.env.FIRESTORE_EMULATOR_HOST;
const projectId = process.env.GCLOUD_PROJECT || 'expresiones-local';

if (!emulatorHost) {
  console.error('Falta FIRESTORE_EMULATOR_HOST (ejemplo: 127.0.0.1:8080).');
  process.exit(1);
}

if (!/^(127\.0\.0\.1|localhost):\d+$/.test(emulatorHost)) {
  console.error('Por seguridad, este script solo acepta un emulador en localhost.');
  process.exit(1);
}

if (typeof fetch !== 'function') {
  console.error('Se necesita Node.js 18 o posterior para usar fetch.');
  process.exit(1);
}

const databaseBase =
  `http://${emulatorHost}/v1/projects/${encodeURIComponent(projectId)}` +
  '/databases/(default)/documents';

function encodeValue(value) {
  if (value === null) return { nullValue: null };
  if (value instanceof Date) return { timestampValue: value.toISOString() };
  if (Array.isArray(value)) {
    return { arrayValue: { values: value.map(encodeValue) } };
  }

  switch (typeof value) {
    case 'boolean':
      return { booleanValue: value };
    case 'number':
      return Number.isInteger(value)
        ? { integerValue: String(value) }
        : { doubleValue: value };
    case 'string':
      return { stringValue: value };
    case 'object':
      return { mapValue: { fields: encodeFields(value) } };
    default:
      throw new TypeError(`Tipo no compatible con Firestore: ${typeof value}`);
  }
}

function encodeFields(data) {
  return Object.fromEntries(
    Object.entries(data).map(([key, value]) => [key, encodeValue(value)]),
  );
}

function encodeDocumentPath(documentPath) {
  return documentPath.split('/').map(encodeURIComponent).join('/');
}

async function putDocument(documentPath, data) {
  const response = await fetch(
    `${databaseBase}/${encodeDocumentPath(documentPath)}`,
    {
      method: 'PATCH',
      // `owner` es el token especial del emulador; no es una credencial real.
      headers: {
        authorization: 'Bearer owner',
        'content-type': 'application/json',
      },
      body: JSON.stringify({ fields: encodeFields(data) }),
    },
  );

  if (!response.ok) {
    throw new Error(
      `${documentPath}: ${response.status} ${await response.text()}`,
    );
  }

  console.log(`Creado/actualizado: ${documentPath}`);
}

const now = new Date();
const documents = {
  'categories/materiales': {
    name: 'Materiales',
    slug: 'materiales',
    description: 'Insumos para crear detalles que perduran.',
    imageUrl: '',
    isActive: true,
    sortOrder: 10,
    updatedAt: now,
  },
  'categories/ramos': {
    name: 'Ramos',
    slug: 'ramos',
    description: 'Rosas eternas y arreglos hechos a mano.',
    imageUrl: '',
    isActive: true,
    sortOrder: 20,
    updatedAt: now,
  },
  'categories/personalizados': {
    name: 'Personalizados',
    slug: 'personalizados',
    description: 'Regalos preparados para cada ocasión.',
    imageUrl: '',
    isActive: true,
    sortOrder: 30,
    updatedAt: now,
  },
  'settings/public': {
    businessName: 'Expresiones',
    locale: 'es_PE',
    currency: 'PEN',
    whatsappNumberE164: '51956744914',
    whatsappGreeting: 'Hola, Expresiones. Quisiera cotizar:',
    pickupCity: 'Huancayo',
    shippingProvider: 'Shalom',
    quoteDisclaimer:
      'Aún no es un pedido. Confirmaremos stock, total y envío por WhatsApp.',
    catalogVersion: 1,
    updatedAt: now,
  },
  'availability/public': {
    acceptingOrders: true,
    timezone: 'America/Lima',
    horizonStart: '',
    horizonEnd: '',
    days: [],
    message: 'La fecha final se confirma por WhatsApp.',
    updatedAt: now,
  },
};

// El JSON se genera desde el mismo catálogo que usa Flutter, por lo que los
// nombres de campos, variantes y precios siempre coinciden con la aplicación.
const catalogPath = path.join(__dirname, 'catalog_seed.json');
const catalogProducts = JSON.parse(fs.readFileSync(catalogPath, 'utf8'));
for (const product of catalogProducts) {
  const { id, ...data } = product;
  documents[`products/${id}`] = { ...data, updatedAt: now };
}

async function main() {
  for (const [documentPath, data] of Object.entries(documents)) {
    await putDocument(documentPath, data);
  }
  console.log(`Datos locales listos en el proyecto ${projectId}.`);
}

main().catch((error) => {
  console.error(error.message);
  process.exitCode = 1;
});
