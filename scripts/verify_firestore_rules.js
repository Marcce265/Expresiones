/* Minimal security smoke test for the local Firestore emulator. */

'use strict';

const host = process.env.FIRESTORE_EMULATOR_HOST;
const projectId = process.env.GCLOUD_PROJECT || 'expresiones-local';

if (!host || !/^(127\.0\.0\.1|localhost):\d+$/.test(host)) {
  console.error('Ejecuta este script únicamente dentro del emulador Firestore.');
  process.exit(1);
}

const databaseName = `projects/${projectId}/databases/(default)`;
const root = `http://${host}/v1/${databaseName}`;
const documents = `${root}/documents`;
const runId = `${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;

function value(input) {
  if (typeof input === 'string') return { stringValue: input };
  if (typeof input === 'number') return { integerValue: String(input) };
  if (typeof input === 'boolean') return { booleanValue: input };
  if (input && typeof input === 'object') {
    return { mapValue: { fields: fields(input) } };
  }
  throw new TypeError(`Valor no soportado: ${input}`);
}

function fields(data) {
  return Object.fromEntries(
    Object.entries(data).map(([key, entry]) => [key, value(entry)]),
  );
}

async function createEvent(id, data) {
  return fetch(`${documents}:commit`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({
      writes: [
        {
          update: {
            name: `${databaseName}/documents/analytics_events/${id}`,
            fields: fields(data),
          },
          updateTransforms: [
            { fieldPath: 'occurredAt', setToServerValue: 'REQUEST_TIME' },
          ],
        },
      ],
    }),
  });
}

async function expect(responsePromise, allowed, label) {
  const response = await responsePromise;
  if (!allowed.includes(response.status)) {
    throw new Error(
      `${label}: HTTP ${response.status}; ${await response.text()}`,
    );
  }
}

async function main() {
  const validEvents = [
    {
      eventType: 'zero_result_search',
      day: '2026-10-15',
      schemaVersion: 1,
      searchTerm: 'cinta lavanda',
    },
    {
      eventType: 'product_view',
      day: '2026-10-15',
      schemaVersion: 1,
      productId: 'cinta-satinada-100m',
      variantId: 'satin-08',
    },
    {
      eventType: 'product_added',
      day: '2026-10-15',
      schemaVersion: 1,
      productId: 'cinta-satinada-100m',
      quantityBucket: '12-49',
    },
    {
      eventType: 'quote_abandoned',
      day: '2026-10-15',
      schemaVersion: 1,
      itemCountBucket: '4-6',
      valueBucket: '250-499',
      abandonmentHoursBucket: '24-71',
    },
    {
      eventType: 'quote_sent',
      day: '2026-10-15',
      schemaVersion: 1,
      itemCountBucket: '2-3',
      valueBucket: '50-99',
    },
  ];

  for (const [index, event] of validEvents.entries()) {
    await expect(
      createEvent(`valid-${index}-${runId}`, event),
      [200],
      `evento válido ${event.eventType}`,
    );
  }

  await expect(
    fetch(`${documents}/analytics_events/valid-1-${runId}`),
    [403],
    'lectura pública de telemetría',
  );

  for (const [index, searchTerm] of [
    'maria@gmail.com',
    '999 999 999',
    'av. giraldez 123',
  ].entries()) {
    await expect(
      createEvent(`private-${index}-${runId}`, {
        eventType: 'zero_result_search',
        day: '2026-10-15',
        schemaVersion: 1,
        searchTerm,
      }),
      [403],
      `búsqueda privada ${index + 1}`,
    );
  }

  await expect(
    createEvent(`bucket-${runId}`, {
      eventType: 'product_added',
      day: '2026-10-15',
      schemaVersion: 1,
      productId: 'cinta-satinada-100m',
      quantityBucket: '1000000',
    }),
    [403],
    'rango de cantidad no permitido',
  );

  await expect(
    createEvent(`phone-id-${runId}`, {
      eventType: 'product_view',
      day: '2026-10-15',
      schemaVersion: 1,
      productId: '999999999',
    }),
    [403],
    'teléfono usado como identificador',
  );

  await expect(
    fetch(`${documents}/analytics_events/valid-1-${runId}`, {
      method: 'DELETE',
    }),
    [403],
    'borrado público de telemetría',
  );

  console.log('Reglas verificadas: escritura anónima acotada y lecturas privadas.');
}

main().catch((error) => {
  console.error(error.message);
  process.exitCode = 1;
});
