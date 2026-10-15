"""Guarda una copia del directorio público de agencias de Shalom.

Requiere: pip install requests cryptography
Uso: python scripts/sync_shalom_agencies.py
"""

from __future__ import annotations

import base64
import json
import secrets
from datetime import datetime, timedelta, timezone
from pathlib import Path

import requests
from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes
from cryptography.hazmat.primitives.padding import PKCS7


ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "assets" / "data" / "shalom_agencies.json"
BASE = "https://shalom.com.pe"


def _text(value: object) -> str:
    return str(value).strip() if value is not None else ""


def _flag(value: object) -> bool:
    return _text(value).lower() in {"1", "true", "si", "sí"}


def _number(value: object) -> float | None:
    try:
        return float(_text(value))
    except ValueError:
        return None


def _fetch() -> list[dict]:
    key = secrets.token_bytes(32)
    headers = {
        "X-Requested-With": "XMLHttpRequest",
        "X-Session-Key": base64.b64encode(key).decode(),
        "Referer": f"{BASE}/agencias",
        "User-Agent": "Mozilla/5.0 (compatible; ExpresionesCatalog/1.0)",
    }
    with requests.Session() as session:
        response = session.get(f"{BASE}/api/local/session", headers=headers, timeout=30)
        response.raise_for_status()
        headers["X-Proxy-Token"] = response.json()["csrf"]
        response = session.post(
            f"{BASE}/api/v1/web/agencias/listar",
            headers=headers,
            json={},
            timeout=90,
        )
        response.raise_for_status()
        encrypted = response.json()

    if encrypted.get("encrypted") is not True:
        raise ValueError("Shalom cambió el formato de su respuesta.")
    raw = base64.b64decode(encrypted["data"])
    decryptor = Cipher(algorithms.AES(key), modes.CBC(raw[:16])).decryptor()
    padded = decryptor.update(raw[16:]) + decryptor.finalize()
    unpadder = PKCS7(128).unpadder()
    decoded = json.loads(unpadder.update(padded) + unpadder.finalize())
    if decoded.get("success") is not True or not isinstance(decoded.get("data"), list):
        raise ValueError("Shalom no devolvió una lista válida de agencias.")
    return decoded["data"]


def _clean(item: dict) -> dict:
    parts = [_text(part) for part in _text(item.get("nombre")).split("/")]
    district = parts[2] if len(parts) >= 3 else _text(item.get("zona"))
    name = _text(item.get("lugar_over") or item.get("lugar"))
    if not name:
        name = parts[3] if len(parts) >= 4 else _text(item.get("zona"))
    return {
        "id": _text(item.get("ter_id")),
        "name": _text(item.get("nombre")),
        "locationName": name,
        "zone": _text(item.get("zona")),
        "department": _text(item.get("departamento")),
        "province": _text(item.get("provincia")),
        "district": district,
        "address": _text(item.get("direccion")),
        "phone": _text(item.get("telefono")),
        "latitude": _number(item.get("latitud")),
        "longitude": _number(item.get("longitud")),
        "openingHours": _text(item.get("hora_atencion")),
        "sundayHours": _text(item.get("hora_domingo")),
        "web": _flag(item.get("web")),
        "isAgent": _flag(item.get("ter_estado_agente")),
        "isProPoint": _flag(item.get("ter_estado_pro")),
        "canReceive": _flag(item.get("destino")),
        "canSend": _flag(item.get("origen")),
    }


def main() -> None:
    agencies = [_clean(item) for item in _fetch()]
    ids = [item["id"] for item in agencies]
    public = [item for item in agencies if item["web"]]
    if len(agencies) < 300 or len(public) < 200 or len(set(ids)) != len(ids):
        raise ValueError("Directorio incompleto o con identificadores duplicados.")

    payload = {
        "source": f"{BASE}/agencias",
        "updatedAt": datetime.now(timezone(timedelta(hours=-5)))
        .date()
        .isoformat(),
        "total": len(agencies),
        "publicTotal": len(public),
        "agencies": agencies,
    }
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(
        json.dumps(payload, ensure_ascii=False, separators=(",", ":")) + "\n",
        encoding="utf-8",
    )
    print(f"Guardadas {len(agencies)} sedes ({len(public)} públicas) en {OUTPUT}")


if __name__ == "__main__":
    main()
