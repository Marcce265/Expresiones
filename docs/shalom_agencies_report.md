# Directorio de agencias Shalom

Fuente: [buscador público de agencias de Shalom](https://shalom.com.pe/agencias).
Consulta: 16 de noviembre de 2026, hora de Perú.

La copia local en `assets/data/shalom_agencies.json` contiene **569 registros** que devolvió el directorio. De ellos, **510** están marcados para aparecer en la web pública. **499** figuran como destinos de envíos y se pueden seleccionar; los demás permanecen fuera del selector cuando no reciben envíos. Las 499 agencias seleccionables tienen coordenadas válidas entregadas por Shalom.

Cada registro conserva identificador, nombre, departamento, provincia, distrito, dirección, teléfono, coordenadas y horarios. El distrito se obtiene del tercer segmento del nombre que entrega Shalom porque la respuesta no incluye un campo de distrito en texto. El listado se carga desde el paquete de Flutter, funciona sin conexión y no genera lecturas de Firestore.

Para actualizarlo:

```powershell
python -m pip install requests cryptography
python scripts/sync_shalom_agencies.py
```

El script comprueba cantidad, identificadores y coordenadas antes de reemplazar la copia. Shalom no publica este servicio como API abierta; su sitio usa una sesión y una respuesta cifrada. Si cambia el formato, el script fallará sin reemplazar el archivo anterior. Conviene revisar el directorio [oficial](https://shalom.com.pe/agencias) antes de confirmar cada envío.
