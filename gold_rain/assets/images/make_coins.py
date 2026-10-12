"""Generate 4-frame gold coin sprites for M2 (transparent PNG, 128px).

Frames = one coin rotating: front (0) -> tilt (1) -> edge (2) -> tilt (3).
Cycling 0->1->2->3->0 in the particle engine gives a continuous spin.
Every frame shares the same 128x128 canvas and centered position so the
animation doesn't jump.
"""

from PIL import Image, ImageDraw, ImageFont
import os

OUT_DIR = os.path.dirname(os.path.abspath(__file__))
SIZE = 128

# 金币配色（中心亮 -> 外圈暗）
CORE = (255, 228, 110)
MID = (255, 199, 26)
EDGE = (166, 124, 12)
RIM = (110, 74, 6)
SYMBOL = (122, 84, 8)


def lerp(a, b, k):
    return tuple(int(a[i] + (b[i] - a[i]) * k) for i in range(3))


def load_font(size):
    candidates = [
        r"C:\Windows\Fonts\arialbd.ttf",
        r"C:\Windows\Fonts\arial.ttf",
        r"C:\Windows\Fonts\msyhbd.ttc",
        r"C:\Windows\Fonts\msyh.ttc",
    ]
    for p in candidates:
        if os.path.exists(p):
            return ImageFont.truetype(p, size)
    return ImageFont.load_default()


def draw_front():
    """正面金币：径向渐变 + 外圈 rim + 内圈细边 + 高光/暗部 + ¥ 符号"""
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    cx = cy = SIZE / 2
    r = SIZE / 2 - 2

    # 径向渐变圆盘（80 层同心圆，中心最亮）
    steps = 80
    for i in range(steps, 0, -1):
        rr = r * i / steps
        t = i / steps
        d.ellipse([cx - rr, cy - rr, cx + rr, cy + rr],
                  fill=lerp(EDGE, CORE, t * t) + (255,))

    # 外圈 rim + 内圈细边（线宽随画布等比缩放）
    d.ellipse([cx - r, cy - r, cx + r, cy + r], outline=RIM + (255,),
              width=max(2, int(SIZE * 0.031)))
    r2 = r * 0.82
    d.ellipse([cx - r2, cy - r2, cx + r2, cy + r2], outline=EDGE + (255,),
              width=max(1, int(SIZE * 0.012)))

    # 左上高光弧 + 右下暗部弧（3D 立体感）
    box = [cx - r * 0.78, cy - r * 0.78, cx + r * 0.78, cy + r * 0.78]
    d.arc(box, 195, 335, fill=(255, 255, 255, 80), width=int(SIZE * 0.059))
    d.arc(box, 15, 165, fill=(70, 48, 0, 70), width=int(SIZE * 0.059))

    # ¥ 符号
    font = load_font(int(SIZE * 0.47))
    text = "¥"
    bbox = d.textbbox((0, 0), text, font=font)
    tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
    d.text((cx - tw / 2 - bbox[0], cy - th / 2 - bbox[1]),
           text, font=font, fill=SYMBOL + (255,))
    return img


def squash(img, factor):
    """水平压扁（模拟旋转中的金币透视），保持 256x256 居中"""
    w, h = img.size
    nw = max(1, int(w * factor))
    squashed = img.resize((nw, h), Image.LANCZOS)
    canvas = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    canvas.paste(squashed, ((w - nw) // 2, 0), squashed)
    return canvas


def edge_frame(base):
    """侧视帧：压到很薄，中间加一道竖向高光模拟金属边缘"""
    img = squash(base, 0.20)
    d = ImageDraw.Draw(img)
    d.line([SIZE / 2, SIZE * 0.07, SIZE / 2, SIZE * 0.93],
           fill=(255, 240, 180, 170), width=max(1, int(SIZE * 0.016)))
    return img


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    base = draw_front()
    frames = {
        "coin_0.png": base,
        "coin_1.png": squash(base, 0.78),
        "coin_2.png": edge_frame(base),
        "coin_3.png": squash(base, 0.78),
    }
    for name, img in frames.items():
        path = os.path.join(OUT_DIR, name)
        img.save(path, optimize=True)
        print("wrote", path, img.size)


if __name__ == "__main__":
    main()
