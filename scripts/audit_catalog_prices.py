"""Validate catalog prices and write a human-readable review report."""

from __future__ import annotations

import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SEED = ROOT / "scripts" / "catalog_seed.json"
REPORT = ROOT / "docs" / "price_audit.md"


def money(value: float) -> str:
    return f"S/ {value:.2f}"


def main() -> None:
    products = json.loads(SEED.read_text(encoding="utf-8"))
    errors: list[str] = []
    pending: list[dict] = []
    verified: list[dict] = []

    for product in products:
        base = float(product.get("basePrice", 0))
        if base <= 0:
            errors.append(f"{product['id']}: precio base inválido ({base})")

        tiers = sorted(
            product.get("priceTiers", []), key=lambda item: item["minQuantity"]
        )
        last_quantity = 0
        last_price = base
        for tier in tiers:
            quantity = int(tier["minQuantity"])
            price = float(tier["unitPrice"])
            if quantity <= last_quantity:
                errors.append(f"{product['id']}: tramos de cantidad desordenados")
            if price <= 0:
                errors.append(f"{product['id']}: tramo con precio inválido")
            if price > last_price:
                errors.append(
                    f"{product['id']}: el precio por volumen sube en {quantity} unidades"
                )
            last_quantity, last_price = quantity, price

        for variant in product.get("variants", []):
            override = variant.get("priceOverride")
            if override is not None and float(override) <= 0:
                errors.append(
                    f"{product['id']}/{variant['id']}: precio de variante inválido"
                )

        (pending if product.get("priceIsEstimate") else verified).append(product)

    material_pending = [p for p in pending if p.get("category") == "materials"]
    hidden_pending = [p for p in pending if p.get("category") != "materials"]

    lines = [
        "# Auditoría de precios del catálogo",
        "",
        "Generada desde `scripts/catalog_seed.json`.",
        "",
        "## Resultado",
        "",
        f"- Familias revisadas: **{len(products)}**.",
        f"- Familias con precio validado: **{len(verified)}**.",
        f"- Materiales visibles pendientes de confirmación: **{len(material_pending)}**.",
        f"- Familias futuras ocultas pendientes de confirmación: **{len(hidden_pending)}**.",
        f"- Errores matemáticos detectados: **{len(errors)}**.",
        "",
        "Los precios marcados como pendientes no deben considerarse definitivos hasta que "
        "Expresiones los confirme en el panel administrativo.",
        "",
        "## Materiales pendientes",
        "",
        "| Producto | Precio provisional | Presentación | Motivo |",
        "| --- | ---: | --- | --- |",
    ]
    for product in material_pending:
        lines.append(
            "| {name} | {price} | {unit} | No aparece un precio legible o inequívoco "
            "en la referencia disponible |".format(
                name=product["name"],
                price=money(float(product["basePrice"])),
                unit=product.get("unitLabel", "unidad"),
            )
        )

    lines.extend(
        [
            "",
            "## Productos futuros pendientes",
            "",
            "Estos productos permanecen ocultos del catálogo público:",
            "",
        ]
    )
    for product in hidden_pending:
        lines.append(f"- {product['name']}: {money(float(product['basePrice']))}.")

    lines.extend(["", "## Validaciones automáticas", ""])
    if errors:
        lines.extend(f"- {error}" for error in errors)
    else:
        lines.append(
            "- Todos los precios son positivos y los tramos por volumen mantienen "
            "cantidades ascendentes y precios unitarios no crecientes."
        )

    REPORT.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"Wrote {REPORT}")
    print(
        f"verified={len(verified)} material_pending={len(material_pending)} "
        f"hidden_pending={len(hidden_pending)} errors={len(errors)}"
    )
    if errors:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
