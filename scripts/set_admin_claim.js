/*
 * Grants or removes the Firebase Auth custom claim used by the admin portal.
 *
 * The script requires Application Default Credentials. Never place a service
 * account JSON file inside this repository.
 */

'use strict';

const { applicationDefault, initializeApp } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');

const email = process.argv[2]?.trim().toLowerCase();
const remove = process.argv.includes('--remove');
const projectId = process.env.FIREBASE_PROJECT_ID?.trim();

if (!email || !email.includes('@')) {
  console.error(
    'Uso: node set_admin_claim.js correo@dominio.com [--remove]',
  );
  process.exit(1);
}

if (!projectId) {
  console.error('Falta FIREBASE_PROJECT_ID.');
  process.exit(1);
}

if (!process.env.GOOGLE_APPLICATION_CREDENTIALS) {
  console.error(
    'Falta GOOGLE_APPLICATION_CREDENTIALS con la ruta a una cuenta de servicio.',
  );
  process.exit(1);
}

initializeApp({ credential: applicationDefault(), projectId });

async function main() {
  const auth = getAuth();
  const user = await auth.getUserByEmail(email);
  const claims = { ...(user.customClaims || {}) };
  if (remove) {
    delete claims.admin;
  } else {
    claims.admin = true;
  }
  await auth.setCustomUserClaims(user.uid, claims);
  console.log(
    remove
      ? `Permiso administrador retirado de ${email}.`
      : `Permiso administrador asignado a ${email}.`,
  );
  console.log('La cuenta debe cerrar sesión y volver a ingresar.');
}

main().catch((error) => {
  console.error(error.message);
  process.exitCode = 1;
});
