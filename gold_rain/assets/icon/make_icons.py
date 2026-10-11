"""Generate Android launcher icons from the AI-generated master image.

Steps:
1. Remove the bottom-right watermark by mirroring a clean patch from the left.
2. Flatten any alpha onto the dark background (legacy icons should be opaque).
3. Resize to each mipmap density and overwrite ic_launcher.png.
"""

from PIL import Image
import os

SRC = r"e:\0_CodeProject\12_GoldRainApp\gold_rain\assets\icon\A_mobile_app_launcher_icon__fl_2026-10-11T13-04-38.png"
OUT_MASTER = r"e:\0_CodeProject\12_GoldRainApp\gold_rain\assets\icon\app_icon.png"
RES = r"e:\0_CodeProject\12_GoldRainApp\gold_rain\android\app\src\main\res"

DENSITIES = {
    "mipmap-mdpi": 48,
    "mipmap-hdpi": 72,
    "mipmap-xhdpi": 96,
    "mipmap-xxhdpi": 144,
    "mipmap-xxxhdpi": 192,
}

img = Image.open(SRC).convert("RGBA")
print("source size:", img.size)

# --- 1. remove watermark (bottom-right) by mirroring the clean left patch ---
w, h = img.size
pw, ph = 240, 110  # patch covering the watermark area
src_patch = img.crop((0, h - ph, pw, h)).transpose(Image.FLIP_LEFT_RIGHT)
img.paste(src_patch, (w - pw, h - ph))
print("watermark patched")

# --- 2. flatten alpha onto dark background ---
bg = Image.new("RGBA", img.size, (13, 18, 30, 255))
img = Image.alpha_composite(bg, img).convert("RGB")

# report corner alpha before flatten (informational)
orig = Image.open(SRC).convert("RGBA")
print("corner alpha (before flatten):", orig.getpixel((2, 2))[3], orig.getpixel((w - 3, 2))[3])

img.save(OUT_MASTER, optimize=True)
print("master saved:", OUT_MASTER, img.size)

# --- 3. resize for each density ---
for folder, size in DENSITIES.items():
    out_dir = os.path.join(RES, folder)
    os.makedirs(out_dir, exist_ok=True)
    resized = img.resize((size, size), Image.LANCZOS)
    out_path = os.path.join(out_dir, "ic_launcher.png")
    resized.save(out_path, optimize=True)
    print("wrote", out_path, size)
