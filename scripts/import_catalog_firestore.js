/*
 * Imports scripts/catalog_seed.json into a real Firestore project.
 *
 * Safe by default: without --apply it only validates and reports the plan.
 * A production write also requires an exact project confirmation through
 * ALLOW_PRODUCTION_CATALOG_WRITE=<project-id>.
 */

'use strict';

const fs = require('fs');
const path = require('path');
const { applicationDefault, initializeApp } = require('firebase-admin/app');
const { FieldValue, getFirestore } = require('firebase-admin/firestore');

const apply = process.argv.includes('--apply');
const projectId = process.env.FIREBASE_PROJECT_ID?.trim();
const confirmation = process.env.ALLOW_PRODUCTION_CATALOG_WRITE?.trim();

if (!projectId) {
  console.error('Falta FIREBASE_PROJECT_ID.');
  process.exit(1);
}

const catalogPath = path.join(__dirname, 'catalog_seed.json');
const products = JSON.parse(fs.readFileSync(catalogPath, 'utf8'));

if (!Array.isArray(products) || products.length === 0) {
  console.error('catalog_seed.json no contiene una lista de productos.');
  process.exit(1);
}

const ids = new Set();
for (const product of products) {
  if (!product.id || typeof product.id !== 'string') {
    throw new Error('Cada producto necesita un id de texto.');
  }
  if (ids.has(product.id)) throw new Error(`ID repetido: ${product.id}`);
  ids.add(product.id);
  if (typeof product.name !== 'string' || product.name.trim() === '') {
    throw new Error(`Producto sin nombre: ${product.id}`);
  }
  if (typeof product.basePrice !== 'number' || product.basePrice < 0) {
    throw new Error(`Precio inválido: ${product.id}`);
  }
}

console.log(
  `${products.length} productos validados para el proyecto ${projectId}.`,
);

if (!apply) {
  console.log('Simulación completada. Usa --apply para escribir en Firestore.');
  process.exit(0);
}

if (!process.env.GOOGLE_APPLICATION_CREDENTIALS) {
  console.error(
    'Falta GOOGLE_APPLICATION_CREDENTIALS con la ruta a una cuenta de servicio.',
  );
  process.exit(1);
}

if (confirmation !== projectId) {
  console.error(
    'Escritura rechazada. Define ALLOW_PRODUCTION_CATALOG_WRITE con el ID exacto del proyecto.',
  );
  process.exit(1);
}

initializeApp({ credential: applicationDefault(), projectId });

async function main() {
  const firestore = getFirestore();
  let batch = firestore.batch();
  let operations = 0;

  for (const product of products) {
    const { id, ...data } = product;
    batch.set(
      firestore.collection('products').doc(id),
      {
        ...data,
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
    operations += 1;
    if (operations % 400 === 0) {
      await batch.commit();
      batch = firestore.batch();
    }
  }

  if (operations % 400 !== 0) await batch.commit();
  console.log(`${operations} productos cargados correctamente.`);
}

main().catch((error) => {
  console.error(error.message);
  process.exitCode = 1;
});
