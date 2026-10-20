# Capacidad de producción y telemetría comercial

## Capacidad real

La fila pública `availability` con `id = 'public'` contiene únicamente cifras
agregadas en su campo `data` de Supabase. No debe guardar nombres, teléfonos,
códigos de cotización ni datos de entrega.

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

## Telemetría prevista para la fase 9

La recolección remota está desactivada en el MVP. No se compila la web con
`ENABLE_TELEMETRY=true`, no existe una tabla pública de eventos y el panel no
muestra analítica. La política de privacidad publicada describe este estado.

Si la fase 9 se aprueba, `CommerceTelemetryService` podrá registrar solo:

- búsquedas sin resultados que pasan el filtro de privacidad;
- identificador técnico del producto visto;
- identificador técnico y rango de cantidad del producto agregado;
- rangos de cantidad y monto de cotizaciones abandonadas;
- aperturas correctas de WhatsApp para enviar la cotización.

No existe un campo libre de metadatos. No se guardan nombre, teléfono, nota,
dirección, agencia, texto de personalización, identificador de instalación ni
identificador de sesión. Las cantidades y montos se convierten en rangos.

Las búsquedas que parecen contener correo, teléfono, dirección, DNI, RUC o URL
se descartarían. Antes de activar un envío remoto se debe definir retención,
RLS, aviso al usuario, actualización de la política de privacidad y una nueva
revisión de la declaración de datos del APK.

## Puntos de integración futuros

1. Crear `CommerceTelemetryService` después de inicializar Supabase.
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

## Seguridad en Supabase

La fila de capacidad puede leerse públicamente porque solo contiene cifras
agregadas. Las políticas RLS permiten modificarla únicamente a cuentas presentes
en `admins` cuya sesión haya alcanzado `aal2` mediante TOTP.

La configuración y las pruebas de seguridad están descritas en:

- [`SUPABASE.md`](SUPABASE.md)
- [`admin_portal.md`](admin_portal.md)

Una fase futura de analítica debe crear una migración y políticas específicas;
no se debe reutilizar una tabla sin restricciones ni aceptar metadatos libres
desde el cliente.
