from PIL import Image, ImageChops
import os, shutil

BASE = r"D:\Expresiones"
LOGO_SRC = os.path.join(BASE, "assets", "images", "logo.png")
ICON_OUT  = os.path.join(BASE, "assets", "images", "logo.png")
SPLASH_OUT     = os.path.join(BASE, "android", "app", "src", "main", "res", "drawable", "splash_logo.png")
SPLASH_V21_OUT = os.path.join(BASE, "android", "app", "src", "main", "res", "drawable-v21", "splash_logo.png")

BG_COLOR = (245, 237, 232)  # crema

def trim_cream(img):
    """Recorta bordes crema/blancos del logo."""
    rgba = img.convert("RGBA")
    pixels = rgba.load()
    w, h = rgba.size
    
    def is_bg(r, g, b):
        return r > 220 and g > 205 and b > 195

    # Encontrar bounding box del contenido
    top, bottom, left, right = h, 0, w, 0
    for y in range(h):
        for x in range(w):
            r, g, b, a = pixels[x, y]
            if not is_bg(r, g, b) and a > 30:
                if y < top: top = y
                if y > bottom: bottom = y
                if x < left: left = x
                if x > right: right = x

    pad = 30
    top    = max(0, top - pad)
    bottom = min(h, bottom + pad)
    left   = max(0, left - pad)
    right  = min(w, right + pad)
    print(f"Contenido encontrado en: ({left},{top}) -> ({right},{bottom})")
    return img.crop((left, top, right, bottom))

def make_transparent(img):
    """Hace transparente el fondo crema/blanco."""
    rgba = img.convert("RGBA")
    data = rgba.getdata()
    new_data = []
    for r, g, b, a in data:
        if r > 220 and g > 205 and b > 195:
            new_data.append((r, g, b, 0))
        else:
            new_data.append((r, g, b, a))
    rgba.putdata(new_data)
    return rgba

def paste_centered(base, overlay, scale):
    max_dim = int(base.width * scale)
    ratio = min(max_dim / overlay.width, max_dim / overlay.height)
    nw = int(overlay.width * ratio)
    nh = int(overlay.height * ratio)
    resized = overlay.resize((nw, nh), Image.LANCZOS)
    x = (base.width - nw) // 2
    y = (base.height - nh) // 2
    base.paste(resized, (x, y), resized)
    return base

# Cargar
print("Cargando logo...")
original = Image.open(LOGO_SRC).convert("RGBA")
print(f"Tamano original: {original.size}")

# Recortar espacio crema
trimmed = trim_cream(original)
print(f"Tamano tras recorte: {trimmed.size}")

# --- ICONO LAUNCHER 1024x1024 con fondo crema ---
icon_base = Image.new("RGBA", (1024, 1024), (*BG_COLOR, 255))
icon = paste_centered(icon_base, trimmed, 0.88)
icon.convert("RGB").save(ICON_OUT, "PNG", optimize=True)
print(f"Icono launcher guardado: {ICON_OUT}")

# --- SPLASH: logo transparente grande 600x600 ---
transparent = make_transparent(trimmed)
splash_base = Image.new("RGBA", (600, 600), (0, 0, 0, 0))
splash = paste_centered(splash_base, transparent, 0.92)
splash.save(SPLASH_OUT, "PNG")
shutil.copy(SPLASH_OUT, SPLASH_V21_OUT)
print(f"Splash logo guardado: {SPLASH_OUT}")
print("Listo!")
