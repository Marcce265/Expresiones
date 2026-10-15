# Optimización de imágenes

La aplicación distribuye copias WebP de alta calidad y conserva los PNG
originales como archivos maestros para futuras ediciones.

| Grupo | Archivos | Carpeta distribuida |
|---|---:|---|
| Cintas satinadas | 80 | `assets/images/satin_optimized/` |
| Limpiapipas | 34 | `assets/images/limpiapipas_optimized/` |

La conversión actual mantiene las dimensiones de las imágenes y conserva sin
cambios el canal transparente. Los 114 originales ocupan 256.90 MB y sus copias
distribuibles 37.47 MB, una reducción de 85.41 %.

`pubspec.yaml` excluye las fuentes PNG, `canva_raw` y `materials_enhanced` del
paquete final. Esos archivos pueden permanecer en el espacio de trabajo sin
aumentar el APK, el AAB o la web.

Para volver a generar las copias:

```powershell
python scripts/optimize_assets.py --quality 92
```

El informe detallado se escribe en `docs/asset_optimization_report.json`.
