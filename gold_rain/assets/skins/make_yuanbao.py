"""Generate 4-frame gold yuanbao (元宝) sprites for the "元宝" skin (128px, transparent).

Frames follow the same spin convention as make_coins.py:
front (0) -> tilt (1) -> edge (2) -> tilt (3), so the particle engine
can reuse the same animation logic.

Yuanbao silhouette = three overlapping ellipses (body + top hump + two
upturned tips), gold gradient with highlight/shadow and a ¥ symbol.
"""

from PIL import Image, ImageDraw, ImageFont
import os

OUT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "yuanbao")
SIZE = 128

# 元宝配色（中心亮 -> 外圈暗，金黄系）
CORE = (255, 231, 112)
MID = (255, 203, 46)
EDGE = (176, 128, 18)
RIM = (120, 82, 10)
SYMBOL = (130, 88, 10)


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


def _ellipse_gradient(d, box, steps=34):
    """同心椭圆径向渐变（EDGE 外 -> CORE 内），返回 (外框, 中心半径) 供高光用"""
    x0, y0, x1, y1 = box
    w, h = x1 - x0, y1 - y0
    for i in range(steps, 0, -1):
        k = i / steps
        inset_x = w * (1 - k) / 2
        inset_y = h * (1 - k) / 2
        d.ellipse([x0 + inset_x, y0 + inset_y, x1 - inset_x, y1 - inset_y],
                  fill=lerp(EDGE, CORE, k * k) + (255,))
    return box


def draw_yuanbao_front():
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    cx = cy = SIZE / 2

    # 三个椭圆叠出元宝轮廓：船身 + 上鼓包 + 左右翘尖
    body = [cx - 56, cy - 16, cx + 56, cy + 42]      # 船身（下缘圆润）
    hump = [cx - 30, cy - 46, cx + 30, cy - 2]       # 顶部鼓包
    tip_l = [cx - 60, cy - 44, cx - 33, cy - 18]     # 左翘尖
    tip_r = [cx + 33, cy - 44, cx + 60, cy - 18]     # 右翘尖

    _ellipse_gradient(d, body)
    _ellipse_gradient(d, hump)
    _ellipse_gradient(d, tip_l, steps=22)
    _ellipse_gradient(d, tip_r, steps=22)

    # 轮廓 rim（描出元宝外沿）
    for box in (body, hump, tip_l, tip_r):
        x0, y0, x1, y1 = box
        d.ellipse([x0, y0, x1, y1], outline=RIM + (255,),
                  width=max(1, int(SIZE * 0.02)))

    # 顶部高光弧（鼓包 + 翘尖上方）+ 船底暗弧
    d.arc([cx - 44, cy - 50, cx + 44, cy - 2], 200, 340,
          fill=(255, 255, 255, 90), width=int(SIZE * 0.045))
    d.arc([cx - 52, cy - 10, cx + 52, cy + 44], 15, 165,
          fill=(70, 48, 0, 80), width=int(SIZE * 0.045))

    # ¥ 符号（印在船身中央）
    font = load_font(int(SIZE * 0.42))
    text = "¥"
    bbox = d.textbbox((0, 0), text, font=font)
    tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
    d.text((cx - tw / 2 - bbox[0], cy + 12 - th / 2 - bbox[1]),
           text, font=font, fill=SYMBOL + (255,))
    return img


def squash(img, factor):
    """水平压扁（模拟旋转透视），居中保持 128x128"""
    w, h = img.size
    nw = max(1, int(w * factor))
    squashed = img.resize((nw, h), Image.LANCZOS)
    canvas = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    canvas.paste(squashed, ((w - nw) // 2, 0), squashed)
    return canvas


def edge_frame(base):
    """侧视帧：压薄 + 竖向高光模拟金属边缘"""
    img = squash(base, 0.20)
    d = ImageDraw.Draw(img)
    d.line([SIZE / 2, SIZE * 0.10, SIZE / 2, SIZE * 0.90],
           fill=(255, 240, 180, 170), width=max(1, int(SIZE * 0.016)))
    return img


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    base = draw_yuanbao_front()
    frames = {
        "0.png": base,
        "1.png": squash(base, 0.78),
        "2.png": edge_frame(base),
        "3.png": squash(base, 0.78),
    }
    for name, img in frames.items():
        path = os.path.join(OUT_DIR, name)
        img.save(path, optimize=True)
        print("wrote", path, img.size)


if __name__ == "__main__":
    main()
