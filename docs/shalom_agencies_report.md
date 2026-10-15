# Directorio de agencias Shalom

Fuente: [buscador público de agencias de Shalom](https://shalom.com.pe/agencias).
Consulta: 14 de octubre de 2026, hora de Perú.

La copia local en `assets/data/shalom_agencies.json` contiene **560 registros** que devolvió el directorio. De ellos, **508** están marcados para aparecer en la web pública y son los que muestra la aplicación. **499** de esos locales figuran como destinos de envíos y se pueden seleccionar; los otros 9 aparecen identificados como locales que no reciben envíos. Hay locales en los 25 departamentos, incluidos 5 Puntos PRO públicos.

Cada registro conserva identificador, nombre, departamento, provincia, distrito, dirección, teléfono, coordenadas y horarios. El distrito se obtiene del tercer segmento del nombre que entrega Shalom porque la respuesta no incluye un campo de distrito en texto. El listado se carga desde el paquete de Flutter, funciona sin conexión y no genera lecturas de Firestore.

Para actualizarlo:

```powershell
python -m pip install requests cryptography
python scripts/sync_shalom_agencies.py
```

El script comprueba cantidad e identificadores antes de reemplazar la copia. Shalom no publica este servicio como API abierta; su sitio usa una sesión y una respuesta cifrada. Si cambia el formato, el script fallará sin reemplazar el archivo anterior. Conviene revisar el directorio [oficial](https://shalom.com.pe/agencias) antes de confirmar cada envío.
