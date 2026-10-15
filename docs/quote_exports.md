# Exportación de cotizaciones

La pantalla de revisión ofrece dos acciones adicionales:

- **Guardar PDF**: documento presentable para el cliente, con código de
  cotización, productos, importes, datos de coordinación y aviso de que aún no
  representa un pedido confirmado.
- **Guardar Excel**: archivo `.xlsx` editable con cantidades, precios unitarios,
  importes, subtotal y datos de entrega.

Los archivos se generan enteramente en el dispositivo o navegador mediante
`QuoteExportService`. El proceso no envía el nombre, teléfono ni cotización a
un servidor.

En la web el navegador inicia una descarga. En Android se guarda en la carpeta
compartida `Descargas/Expresiones`, sin pedir permisos en Android 10 o una
versión posterior. El nombre sigue el patrón:

```text
cotizacion_COT-YYMMDD-CODIGO.pdf
cotizacion_COT-YYMMDD-CODIGO.xlsx
```

La lógica vive en `lib/services/quote_export_service.dart` y los botones
reutilizables en `lib/widgets/quote_export_buttons.dart`.
