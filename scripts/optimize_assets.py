"""Genera los assets WebP que se distribuyen con Android y web.

Los PNG originales se conservan como archivos maestros. La aplicación usa las
copias WebP de alta calidad para reducir el tamaño de descarga sin redimensionar
ni eliminar transparencias.
"""

from __future__ import annotations

import argparse
import json
from dataclasses import asdict, dataclass
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
SATIN_SOURCE = ROOT / "assets" / "images" / "satin_palette"
SATIN_OUTPUT = ROOT / "assets" / "images" / "satin_optimized"
PIPE_OUTPUT = ROOT / "assets" / "images" / "limpiapipas_optimized"
REPORT_PATH = ROOT / "docs" / "asset_optimization_report.json"


@dataclass(frozen=True)
class Result:
    source: str
    output: str
    width: int
    height: int
    source_bytes: int
    output_bytes: int


def _save_webp(source: Path, output: Path, quality: int) -> Result:
    output.parent.mkdir(parents=True, exist_ok=True)
    with Image.open(source) as image:
        # WebP conserva el canal alfa de los limpiapipas de forma exacta.
        image.save(output, "WEBP", quality=quality, method=6, exact=True)
        width, height = image.size
    return Result(
        source=source.relative_to(ROOT).as_posix(),
        output=output.relative_to(ROOT).as_posix(),
        width=width,
        height=height,
        source_bytes=source.stat().st_size,
        output_bytes=output.stat().st_size,
    )


def optimize(quality: int = 92) -> list[Result]:
    results: list[Result] = []

    satin_sources = sorted(SATIN_SOURCE.glob("satin_*.png"))
    if len(satin_sources) != 80:
        raise RuntimeError(
            f"Se esperaban 80 cintas PNG y se encontraron {len(satin_sources)}"
        )
    for source in satin_sources:
        results.append(
            _save_webp(source, SATIN_OUTPUT / f"{source.stem}.webp", quality)
        )

    pipe_sources = sorted(
        (ROOT / "assets" / "images").glob("limpiapipas_*_clean.png")
    )
    if len(pipe_sources) != 34:
        raise RuntimeError(
            f"Se esperaban 34 limpiapipas PNG y se encontraron {len(pipe_sources)}"
        )
    for source in pipe_sources:
        results.append(
            _save_webp(source, PIPE_OUTPUT / f"{source.stem}.webp", quality)
        )

    REPORT_PATH.parent.mkdir(parents=True, exist_ok=True)
    source_bytes = sum(item.source_bytes for item in results)
    output_bytes = sum(item.output_bytes for item in results)
    REPORT_PATH.write_text(
        json.dumps(
            {
                "quality": quality,
                "files": len(results),
                "sourceBytes": source_bytes,
                "outputBytes": output_bytes,
                "savedBytes": source_bytes - output_bytes,
                "reductionPercent": round((1 - output_bytes / source_bytes) * 100, 2),
                "items": [asdict(item) for item in results],
            },
            ensure_ascii=False,
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )
    return results


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--quality", type=int, default=92)
    args = parser.parse_args()
    if not 1 <= args.quality <= 100:
        parser.error("--quality debe estar entre 1 y 100")
    results = optimize(args.quality)
    source_bytes = sum(item.source_bytes for item in results)
    output_bytes = sum(item.output_bytes for item in results)
    print(f"Optimizados: {len(results)} archivos")
    print(f"Origen: {source_bytes / 1024 / 1024:.2f} MB")
    print(f"WebP: {output_bytes / 1024 / 1024:.2f} MB")
    print(f"Reducción: {(1 - output_bytes / source_bytes) * 100:.2f}%")


if __name__ == "__main__":
    main()
