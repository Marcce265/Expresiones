# Archivos heredados de Firebase

Firestore nunca llegó a configurarse como base de producción de Expresiones.
Por eso no existe información remota que exportar: el catálogo inicial se carga
desde `scripts/catalog_seed.json` hacia Supabase.

Los siguientes archivos se conservan por ahora como referencia de la etapa
anterior y para que la historia del proyecto siga siendo auditable:

- `firebase.json`;
- `firebase_config.example.json`;
- `firestore.rules` y `firestore.indexes.json`;
- `scripts/seed_firestore.js`;
- `scripts/import_catalog_firestore.js`;
- `scripts/verify_firestore_rules.js`; y
- `scripts/set_admin_claim.js`.

No forman parte del build, de la publicación ni de la administración actual.
No ejecutes `firebase deploy` para este proyecto. Las instrucciones vigentes
están en `docs/SUPABASE.md`, `docs/admin_portal.md` y `docs/web_release.md`.

Cuando la migración esté validada en producción y exista una copia versionada
estable, estos archivos podrán retirarse en un cambio independiente y fácil de
revertir.
