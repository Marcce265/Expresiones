"""Build the complete local catalog from the 179 Canva asset references.

The raw Canva files stay untouched. Pipe-cleaner cards use the cleaned PNGs,
while every other material uses the highest-resolution Canva source recovered.
"""

from __future__ import annotations

import json
from pathlib import Path
from satin_palette import SATIN_PALETTE


ROOT = Path(__file__).resolve().parents[1]
SEED_JSON = ROOT / "scripts" / "catalog_seed.json"
MANIFEST_JSON = ROOT / "assets" / "images" / "canva_raw" / "manifest.json"
HD_MANIFEST_JSON = ROOT / "assets" / "images" / "catalog_hd" / "manifest.json"
SEED_DART = ROOT / "lib" / "data" / "seed_catalog.dart"


def _price_tier(minimum: int, price: float, label: str) -> dict:
    return {"minQuantity": minimum, "unitPrice": price, "label": label}


def _variant(
    index: int,
    name: str,
    image_url: str,
    *,
    sku: str | None = None,
    color_hex: str | None = None,
    source_image: str | None = None,
) -> dict:
    item = {
        "id": f"catalogo-{index:03d}",
        "name": name,
        "sku": sku or f"CAT-{index:03d}",
        "imageUrl": image_url,
        "priceTiers": [],
        "stockStatus": "check_availability",
        "isActive": True,
        "attributes": {
            "catalogIndex": f"{index:03d}",
            "sourceImage": source_image or image_url,
        },
    }
    if color_hex:
        item["colorHex"] = color_hex
    return item


def _product(
    *,
    product_id: str,
    name: str,
    description: str,
    group: str,
    unit: str,
    price: float,
    order: int,
    variants: list[dict],
    tags: list[str],
    tiers: list[dict] | None = None,
    featured: bool = False,
    estimate: bool = False,
) -> dict:
    return {
        "id": product_id,
        "name": name,
        "category": "materials",
        "description": description,
        "unitLabel": unit,
        "basePrice": price,
        "startingAt": False,
        "priceIsEstimate": estimate,
        "priceTiers": tiers or [],
        "variants": variants,
        "stockStatus": "check_availability",
        "leadDays": 0,
        "productionPoints": 0,
        "isActive": True,
        "isFeatured": featured,
        "sortOrder": order,
        "tags": tags,
        "imageUrl": variants[0]["imageUrl"] if variants else None,
        "attributes": {
            "catalogGroup": group,
            "assetCount": str(len(variants)),
        },
    }


def _raw_path(index: int, by_index: dict[int, dict]) -> str:
    item = by_index[index]
    return item.get("displayPath") or f"assets/images/canva_raw/{item['file']}"


def _named_raw_variants(
    indices: list[int], names: list[str], by_index: dict[int, dict]
) -> list[dict]:
    if len(indices) != len(names):
        raise ValueError(f"Expected {len(indices)} names, got {len(names)}")
    return [
        _variant(index, name, _raw_path(index, by_index))
        for index, name in zip(indices, names, strict=True)
    ]


def build() -> tuple[list[dict], list[dict]]:
    previous = json.loads(SEED_JSON.read_text(encoding="utf-8"))
    if MANIFEST_JSON.exists():
        manifest = json.loads(MANIFEST_JSON.read_text(encoding="utf-8"))
        by_index = {int(item["index"]): item for item in manifest}
    else:
        # The optimized catalog intentionally removes the 179 raw exports.
        # Rebuild the index from the last generated seed so this script remains
        # reproducible after that cleanup.
        by_index: dict[int, dict] = {}
        for product in previous:
            for variant in product.get("variants", []):
                raw_index = variant.get("attributes", {}).get("catalogIndex")
                if raw_index is None:
                    continue
                index = int(raw_index)
                image_path = variant.get("imageUrl") or variant.get(
                    "attributes", {}
                ).get("sourceImage")
                if image_path:
                    by_index[index] = {
                        "index": index,
                        "file": Path(image_path).name,
                        "displayPath": image_path,
                    }

    hd_manifest = json.loads(HD_MANIFEST_JSON.read_text(encoding="utf-8"))
    for item in hd_manifest:
        index = int(item["index"])
        if index >= 18 and item.get("isHighResolution"):
            by_index.setdefault(
                index,
                {"index": index, "file": Path(item["imagePath"]).name},
            )["displayPath"] = item["imagePath"]

    previous_by_id = {item["id"]: item for item in previous}
    pipe = previous_by_id["limpiapipas-premium-8mm"]
    pipe_variants = [
        item for item in pipe["variants"] if item["id"] != "catalogo-celeste-extra"
    ][:34]
    if len(pipe_variants) != 34:
        raise RuntimeError("Expected the 34 cleaned pipe-cleaner colors")

    pipe_indices = [*range(1, 18), 25, 26, 27, *range(28, 43)]
    for item, index in zip(pipe_variants, pipe_indices[:34], strict=True):
        item["attributes"] = {
            "catalogIndex": f"{index:03d}",
            "sourceImage": _raw_path(index, by_index),
        }
    pipe["variants"] = pipe_variants
    pipe["imageUrl"] = pipe_variants[0]["imageUrl"]
    pipe["sortOrder"] = 10
    pipe["attributes"] = {
        **pipe.get("attributes", {}),
        "catalogGroup": "Limpiapipas",
        "assetCount": "34",
    }

    # One saleable color per palette number. Every variant has its own clean
    # optimized WebP product photo; the old mixed Canva ribbon photos are no
    # longer exposed.
    satin_variants = []
    for number, (color_name, color_hex) in enumerate(SATIN_PALETTE, start=1):
        photo = f"assets/images/satin_optimized/satin_{number:02d}.webp"
        item = {
            "id": f"satin-{number:02d}",
            "name": f"N.º {number:02d} · {color_name}",
            "sku": f"SAT-{number:02d}",
            "imageUrl": photo,
            "colorHex": color_hex,
            "priceTiers": [],
            "stockStatus": "check_availability",
            "isActive": True,
            "attributes": {
                "paletteNumber": f"{number:02d}",
                "imageSource": "generated_from_palette",
                "sourceImage": photo,
            },
        }
        satin_variants.append(item)

    satin = _product(
        product_id="cinta-satinada-100m",
        name="Cinta satinada 100 m",
        description="Cinta satinada de 100 m por rollo. Elige el número de la carta de colores; el precio mostrado corresponde a un rollo.",
        group="Cintas satinadas",
        unit="rollo",
        price=29,
        order=20,
        variants=satin_variants,
        tags=["cinta", "satén", "satinada", "rollo", "colores"],
        tiers=[
            _price_tier(3, 28, "Desde 3"),
            _price_tier(12, 27, "Desde 12"),
            _price_tier(36, 25, "Desde 36"),
        ],
        featured=True,
    )

    crown_specs = [
        ("coronitas-decorativas", "Coronita 3 cm · Dorado", 71,
         "Coronita decorativa dorada de 3 cm. Precio por unidad; descuentos por media docena, docena y 100 unidades.", False),
        ("corona-perlada-plateada", "Corona perlada · Plateado", 65,
         "Corona decorativa plateada con perlas. Se vende por unidad; confirma medidas y precio final por WhatsApp.", True),
        ("corona-dorada-perlada-5cm", "Corona perlada 5 cm · Dorado", 75,
         "Corona decorativa dorada con perlas de 5 cm. Se vende por unidad; confirma precio final por WhatsApp.", True),
        ("corona-dorada-perlada-7cm", "Corona perlada 7 cm · Dorado", 76,
         "Corona decorativa dorada con perlas de 7 cm. Se vende por unidad; confirma precio final por WhatsApp.", True),
    ]
    crowns = []
    for order, (product_id, name, index, description, estimate) in enumerate(crown_specs, start=30):
        crowns.append(_product(
            product_id=product_id,
            name=name,
            description=description,
            group="Accesorios",
            unit="unidad",
            price=4,
            order=order,
            variants=_named_raw_variants([index], [name], by_index),
            tags=["corona", "coronita", "perlas", "dorado", "plateado"],
            tiers=[
                _price_tier(6, 3, "Media docena"),
                _price_tier(12, 2.5, "Docena"),
                _price_tier(100, 2, "100 unidades"),
            ] if product_id == "coronitas-decorativas" else [],
            estimate=estimate,
        ))

    products = [pipe, satin, *crowns]

    specifications = [
        (
            "tul-con-perlas",
            "Tul con perlas",
            "Tul decorativo con borde perlado en varios colores.",
            "Envolturas",
            "unidad",
            8,
            40,
            list(range(77, 84)),
            ["Blanco", "Rosa bebé", "Negro", "Lila", "Melón", "Rojo", "Beige"],
            ["tul", "perlas", "envoltura"],
        ),
        (
            "tarjetero-acrilico",
            "Tarjetero acrílico",
            "Sujetadores transparentes de 23.3 cm para tarjetas y dedicatorias.",
            "Accesorios",
            "paquete",
            12,
            50,
            [84],
            ["Tarjetero acrílico 23.3 cm"],
            ["tarjetero", "acrílico", "dedicatoria", "23.3 cm"],
        ),
        (
            "alambre-floral",
            "Alambre floral",
            "Alambre verde militar de 40 cm para tallos y estructuras florales.",
            "Accesorios",
            "paquete",
            13,
            60,
            [85],
            ["Verde militar 40 cm"],
            ["alambre", "tallo", "estructura", "40 cm"],
        ),
        (
            "ganchos-para-foto",
            "Ganchos para foto",
            "Mini ganchos de madera de 2.5 cm; paquete de 100 unidades.",
            "Accesorios",
            "paquete",
            12,
            70,
            [86],
            ["100 ganchos de 2.5 cm"],
            ["gancho", "foto", "madera", "100 unidades"],
        ),
        (
            "papel-leche-cortado",
            "Papel leche cortado",
            "Papel leche de 30 × 30 cm para envolver ramos.",
            "Envolturas",
            "paquete",
            7,
            80,
            list(range(87, 96)),
            [
                "Blanco",
                "Rojo",
                "Rosa bebé",
                "Negro",
                "Perla",
                "Verde agua",
                "Fucsia",
                "Lila",
                "Amarillo bebé",
            ],
            ["papel leche", "envoltura", "ramo", "30 × 30 cm", "colores"],
        ),
        (
            "cinta-tornasol-4cm-7m",
            "Cinta tornasol 4 cm × 7 m",
            "Cinta tornasol de 4 cm de ancho y 7 m de largo.",
            "Cintas especiales",
            "rollo",
            11,
            90,
            list(range(96, 102)),
            [
                "Perla",
                "Melón",
                "Rosa bebé",
                "Blanco",
                "Amarillo tornasol",
                "Rojo coral",
            ],
            ["cinta", "tornasol", "4 cm", "7 m", "colores"],
        ),
        (
            "cinta-organza-tornasol",
            "Cinta organza tornasol",
            "Cinta de organza tornasol de 7 m para lazos y detalles.",
            "Cintas especiales",
            "rollo",
            8,
            100,
            list(range(102, 105)),
            ["Turquesa", "Celeste", "Lila"],
            ["cinta", "organza", "tornasol", "7 m"],
        ),
        (
            "cinta-organza-con-perlas",
            "Cinta organza con perlas",
            "Cinta de organza con borde perlado de 7 m.",
            "Cintas especiales",
            "rollo",
            11,
            110,
            list(range(105, 111)),
            ["Vino", "Rosa bebé", "Blanco", "Celeste", "Negro", "Morado"],
            ["cinta", "organza", "perlas", "7 m"],
        ),
        (
            "cinta-tornasol-7m",
            "Cinta tornasol 7 m",
            "Cinta tornasol para envolturas y lazos.",
            "Cintas especiales",
            "rollo",
            11,
            120,
            list(range(111, 116)),
            ["Blanco", "Rosa bebé", "Lila", "Rojo", "Melón"],
            ["cinta", "tornasol", "7 m", "colores"],
        ),
        (
            "cinta-corazones-dorados",
            "Cinta con corazones dorados",
            "Cinta decorativa con estampado metálico de corazones.",
            "Cintas especiales",
            "rollo",
            11,
            130,
            list(range(116, 122)),
            ["Rosa", "Negro", "Blanco", "Marfil", "Vino", "Rojo"],
            ["cinta", "corazones", "dorado", "estampada"],
        ),
        (
            "cinta-estampada-lujo",
            "Cinta estampada de lujo",
            "Cinta decorativa con estampado dorado para regalos.",
            "Cintas especiales",
            "rollo",
            11,
            140,
            list(range(122, 125)),
            ["Rosa", "Negro", "Blanco"],
            ["cinta", "lujo", "dorado", "estampada"],
        ),
        (
            "cinta-eternal-love",
            "Cinta Eternal Love",
            "Cinta con mensaje y corazones para regalos románticos.",
            "Cintas especiales",
            "rollo",
            11,
            150,
            list(range(125, 128)),
            ["Rosa bebé", "Negro", "Vino"],
            ["cinta", "Eternal Love", "amor", "corazones"],
        ),
        (
            "perlas-decorativas",
            "Perlas decorativas",
            "Perlas para centros de flores y detalles artesanales.",
            "Accesorios",
            "paquete",
            2.5,
            150,
            list(range(128, 131)),
            ["Dorado", "Blanco", "Perla"],
            ["perlas", "decoración", "colores"],
        ),
        (
            "cinta-doble-contacto",
            "Cinta doble contacto",
            "Cinta adhesiva para el armado de flores y envolturas.",
            "Herramientas",
            "rollo",
            4.5,
            160,
            [131],
            ["Cinta doble contacto"],
            ["cinta", "adhesivo", "doble contacto"],
        ),
        (
            "floratape",
            "Floratape",
            "Cinta floral para tallos y uniones.",
            "Accesorios",
            "rollo",
            2.5,
            170,
            list(range(132, 135)),
            ["Verde militar", "Verde lechuga", "Verde olivo"],
            ["floratape", "cinta floral", "verde"],
        ),
        (
            "tiza-difuminador",
            "Tiza difuminador",
            "Pasteles para sombrear y dar profundidad a los pétalos.",
            "Herramientas",
            "set",
            25,
            180,
            [135],
            ["Set de tizas pastel"],
            ["tiza", "pastel", "difuminador"],
        ),
        (
            "diamantes-de-alfiler",
            "Diamantes de alfiler",
            "Alfileres con cristal para decorar flores y arreglos.",
            "Accesorios",
            "paquete",
            9.5,
            190,
            [136],
            ["Alfiler de cristal transparente"],
            ["diamante", "alfiler", "cristal"],
        ),
        (
            "brochetas",
            "Brochetas",
            "Varillas de madera para sostener accesorios y dedicatorias.",
            "Accesorios",
            "paquete",
            4,
            200,
            list(range(137, 140)),
            ["Paquete múltiple 01", "Paquete múltiple 02", "Paquete individual"],
            ["brocheta", "varilla", "madera"],
        ),
        (
            "luz-hada",
            "Luz hada",
            "Guirnaldas LED para iluminar arreglos y cajas.",
            "Accesorios",
            "unidad",
            10,
            210,
            list(range(140, 147)),
            [
                "Amarillo",
                "Blanco",
                "Azul",
                "Rosada",
                "Multicolor",
                "Diamante",
                "Roja",
            ],
            ["luz", "hada", "LED", "diamante"],
        ),
        (
            "mariposas-decorativas",
            "Mariposas decorativas",
            "Mariposas 3D para ramos, cajas y regalos.",
            "Accesorios",
            "paquete",
            5,
            230,
            list(range(147, 155)),
            [
                "Dorada con morado",
                "Fucsia con dorado",
                "Rosa dorado",
                "Dorado clásico",
                "Tornasol",
                "Dorado compacto",
                "Amarillo tornasol",
                "Verde con dorado",
            ],
            ["mariposa", "3D", "decoración", "dorado"],
        ),
        (
            "pistola-de-silicona",
            "Pistola de silicona",
            "Pistola térmica para el armado de manualidades.",
            "Herramientas",
            "unidad",
            25,
            240,
            [155],
            ["Pistola de silicona rosada"],
            ["pistola", "silicona", "herramienta"],
        ),
        (
            "barras-de-silicona",
            "Barras de silicona",
            "Barras adhesivas de repuesto para pistola térmica.",
            "Herramientas",
            "paquete",
            1,
            250,
            [156],
            ["Paquete de barras PMC"],
            ["barra", "silicona", "adhesivo"],
        ),
        (
            "frases-en-vinil",
            "Frases en vinil",
            "Diseños de frases adhesivas para personalizar regalos.",
            "Frases",
            "plancha",
            6,
            260,
            list(range(157, 178)),
            [
                "Quinceañera y 15 años",
                "Frases para mamá",
                "Amor y noviazgo",
                "Novia, reina y princesa",
                "Flores por Bonita",
                "Feliz cumpleaños mamita",
                "Cumpleaños amor y princesa",
                "Para la más bella",
                "Felicitaciones y graduación",
                "Nunca dejes de sonreír",
                "Graduación y logros",
                "Amor y novia",
                "Cumpleaños y aniversario",
                "Cumpleaños general",
                "Flores amarillas",
                "Mensaje de primavera",
                "Mensaje de amor con flores",
                "Para la flor más hermosa",
                "Cumpleaños familiar",
                "Día de la mujer",
                "Para la mejor mujer del mundo",
            ],
            ["vinil", "frase", "dedicatoria", "personalización"],
        ),
        (
            "maquina-cortadora",
            "Máquina cortadora",
            "Máquina automática para cortar cintas y materiales.",
            "Herramientas",
            "unidad",
            410,
            270,
            [178],
            ["Máquina cortadora automática"],
            ["máquina", "cortadora", "herramienta"],
        ),
        (
            "cautin",
            "Cautín",
            "Herramienta térmica para sellar y trabajar cintas.",
            "Herramientas",
            "unidad",
            25,
            280,
            [179],
            ["Cautín 30 W"],
            ["cautín", "sellado", "herramienta"],
        ),
    ]

    for (
        product_id,
        name,
        description,
        group,
        unit,
        price,
        order,
        indices,
        names,
        tags,
    ) in specifications:
        products.append(
            _product(
                product_id=product_id,
                name=name,
                description=description,
                group=group,
                unit=unit,
                price=price,
                order=order,
                variants=_named_raw_variants(indices, names, by_index),
                tags=tags,
                estimate=product_id in {
                    "brochetas",
                    "luz-hada",
                    "barras-de-silicona",
                    "cinta-tornasol-4cm-7m",
                },
            )
        )

    tier_overrides = {
        "tul-con-perlas": [
            _price_tier(6, 7, "Media docena"),
            _price_tier(12, 6, "Docena"),
            _price_tier(100, 5, "Desde 100"),
        ],
        "tarjetero-acrilico": [
            _price_tier(3, 10, "Desde 3"),
            _price_tier(12, 8, "Docena"),
        ],
        "papel-leche-cortado": [_price_tier(3, 6.5, "Desde 3")],
        "cinta-organza-tornasol": [
            _price_tier(6, 7.5, "Media docena"),
            _price_tier(12, 7, "Docena"),
        ],
        "cinta-organza-con-perlas": [_price_tier(12, 9, "Docena")],
        "cinta-tornasol-7m": [_price_tier(6, 9, "Media docena")],
        "cinta-corazones-dorados": [_price_tier(6, 9, "Media docena")],
        "cinta-estampada-lujo": [_price_tier(6, 9, "Media docena")],
        "cinta-eternal-love": [_price_tier(6, 9, "Media docena")],
        "cinta-doble-contacto": [_price_tier(12, 4, "Docena")],
        "floratape": [_price_tier(12, 2, "Docena")],
        "mariposas-decorativas": [_price_tier(12, 4.5, "Docena")],
        "pistola-de-silicona": [_price_tier(12, 20, "Docena")],
        "frases-en-vinil": [
            _price_tier(3, 5.5, "Desde 3"),
            _price_tier(12, 5, "Docena"),
            _price_tier(100, 4.5, "Desde 100"),
        ],
    }
    for product in products:
        if product["id"] in tier_overrides:
            product["priceTiers"] = tier_overrides[product["id"]]

    # The printed catalog lists alambre floral as three presentations rather
    # than a volume discount for one package: 50 units, 100 units and 1 kg.
    alambre = next(product for product in products if product["id"] == "alambre-floral")
    alambre_image = alambre["variants"][0]["imageUrl"]
    alambre["unitLabel"] = "presentación"
    alambre["variants"] = [
        {
            "id": "medio-ciento",
            "name": "Medio ciento (50 varillas de 40 cm)",
            "sku": "ALF-050",
            "imageUrl": alambre_image,
            "priceOverride": 13,
            "priceTiers": [],
            "stockStatus": "check_availability",
            "isActive": True,
            "attributes": {"contenido": "50 varillas", "largo": "40 cm"},
        },
        {
            "id": "ciento",
            "name": "Ciento (100 varillas de 40 cm)",
            "sku": "ALF-100",
            "imageUrl": alambre_image,
            "priceOverride": 26,
            "priceTiers": [],
            "stockStatus": "check_availability",
            "isActive": True,
            "attributes": {"contenido": "100 varillas", "largo": "40 cm"},
        },
        {
            "id": "kilo",
            "name": "Paquete de 1 kg",
            "sku": "ALF-1KG",
            "imageUrl": alambre_image,
            "priceOverride": 35,
            "priceTiers": [],
            "stockStatus": "check_availability",
            "isActive": True,
            "attributes": {"contenido": "1 kg", "largo": "40 cm"},
        },
    ]
    alambre["attributes"].update(
        {
            "priceSource": "Catálogo Canva · página 14",
            "priceVerifiedAt": "2026-10-15",
        }
    )

    ganchos = next(product for product in products if product["id"] == "ganchos-para-foto")
    ganchos["attributes"].update(
        {
            "priceSource": "Catálogo Canva · página 15",
            "priceVerifiedAt": "2026-10-15",
        }
    )

    # Ramos y regalos quedan preparados para una etapa posterior, pero el
    # catálogo público actual es exclusivamente de materiales.
    tail = [item for item in previous if item["category"] != "materials"]
    for product in tail:
        product["isActive"] = False
        product["isFeatured"] = False
    all_products = products + tail
    for product in products:
        variant_ids = [variant["id"] for variant in product["variants"]]
        if len(variant_ids) != len(set(variant_ids)):
            raise RuntimeError(f"Duplicate variants in {product['id']}")
    if len(satin_variants) != 80:
        raise RuntimeError("The numbered satin palette must contain 80 colors")
    return all_products, products


def write_outputs() -> None:
    products, material_products = build()
    json_text = json.dumps(products, ensure_ascii=False, indent=2) + "\n"
    SEED_JSON.write_text(json_text, encoding="utf-8")

    compact_json = json.dumps(products, ensure_ascii=False, separators=(",", ":"))
    dart_text = f'''import 'dart:convert';

import '../models/catalog_models.dart';

/// Local fallback catalog with deduplicated Canva products and 80 ribbon colors.
///
/// Pipe-cleaner entries point to cleaned PNGs. Every satin color points to its
/// own high-resolution three-roll product photo.
final List<CatalogProduct> seedCatalogProducts = List.unmodifiable(
  (jsonDecode(_seedCatalogJson) as List<dynamic>)
      .whereType<Map<String, dynamic>>()
      .map(CatalogProduct.fromMap),
);

const String _seedCatalogJson = r\'\'\'{compact_json}\'\'\';
'''
    SEED_DART.write_text(dart_text, encoding="utf-8")

    print(
        f"Wrote {len(products)} product families, "
        f"{sum(len(p['variants']) for p in material_products)} material variants"
    )


if __name__ == "__main__":
    write_outputs()
