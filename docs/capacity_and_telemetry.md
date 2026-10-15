# Capacidad de producción y telemetría comercial

## Capacidad real

El documento público `availability/public` contiene únicamente cifras
agregadas. No debe guardar nombres, teléfonos, códigos de cotización ni datos
de entrega.

```json
{
  "timezone": "America/Lima",
  "horizonDays": 120,
  "weeklyCapacityPoints": {
    "1": 24,
    "2": 24,
    "3": 24,
    "4": 24,
    "5": 24,
    "6": 12,
    "7": 0
  },
  "reservedPointsByDate": {
    "2026-10-16": 18
  },
  "overridesByDate": {
    "2026-10-31": {
      "isClosed": true,
      "reason": "Inventario"
    },
    "2026-11-02": {
      "capacityPoints": 12,
      "isClosed": false
    }
  }
}
```

`ProductionCapacityService` resta las reservas confirmadas a la capacidad de
cada día, respeta cierres y reparte pedidos grandes entre varios días. También
puede verificar si una fecha solicitada todavía es posible.

El valor inicial supone que un punto equivale aproximadamente a 30 minutos del
tiempo conjunto del taller. Antes de prometer fechas automáticamente se deben
medir varios pedidos reales y ajustar tanto estos límites como los puntos de
cada producto.

## Telemetría privada por diseño

`CommerceTelemetryService` registra solo:

- búsquedas sin resultados que pasan el filtro de privacidad;
- identificador técnico del producto visto;
- identificador técnico y rango de cantidad del producto agregado;
- rangos de cantidad y monto de cotizaciones abandonadas;
- aperturas correctas de WhatsApp para enviar la cotización.

No existe un campo libre de metadatos. No se guardan nombre, teléfono, nota,
dirección, agencia, texto de personalización, identificador de instalación ni
identificador de sesión. Las cantidades y montos se convierten en rangos.

Las búsquedas que parecen contener correo, teléfono, dirección, DNI, RUC o URL
se descartan. Los eventos se encolan localmente y el envío remoto es opcional.

## Puntos de integración

1. Crear `CommerceTelemetryService` después de inicializar Firebase.
2. En Inicio y Catálogo, llamar `recordZeroResultSearch(query)` únicamente
   cuando una búsqueda confirmada o con pausa no tenga resultados.
3. Al abrir un producto, llamar `recordProductView`.
4. Al agregarlo, llamar `recordProductAdded` con el nuevo total del carrito.
5. Al cambiar o quitar líneas, llamar `markQuoteActivity`. Con cero elementos
   se descarta el seguimiento de abandono.
6. Cuando WhatsApp se abre correctamente, llamar `recordQuoteSent`.
7. Al volver del segundo plano, llamar `detectAbandonedQuote`.
8. Sustituir la fecha aproximada actual por el resultado de
   `ProductionCapacityService.earliestPlan` y validar la fecha elegida con
   `planByDate`.

## Reglas de Firestore

El administrador puede leer `analytics_events` mediante Admin SDK o un usuario
con el custom claim `admin: true`. El cliente público solo puede crear eventos
que cumplen el esquema exacto de su tipo. Las reglas restringen identificadores,
términos de búsqueda y rangos permitidos; además exigen una marca de tiempo del
servidor. El público no puede leer, modificar ni borrar los eventos.

La validación local de estas fronteras se ejecuta con:

```powershell
$env:JAVA_HOME = 'C:\Program Files\Android\Android Studio\jbr'
$env:Path = "$env:JAVA_HOME\bin;$env:Path"
firebase emulators:exec 'node scripts/verify_firestore_rules.js' `
  --only firestore --project expresiones-local
```

En producción se debe activar Firebase App Check para reducir escrituras
automatizadas ajenas a la aplicación. La recolección remota se habilita solo
cuando el aviso de privacidad esté publicado.
